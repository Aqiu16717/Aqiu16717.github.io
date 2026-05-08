---
title: MySQL MDL 为什么要区分 shared_read 与 shared_write？
date: 2026-05-08 16:00:00
tags:
  - MySQL
  - InnoDB
  - MDL
  - 锁
  - 数据库
categories:
  - 数据库
lang: zh-CN
---

MySQL 的 MDL（Metadata Lock）里有两个看起来很像的锁类型：`SHARED_READ`（SR）和 `SHARED_WRITE`（SW）。它们都不会修改表结构，本质上都是"对元数据只读"。那为什么要根据业务语句是读数据还是写数据，把元数据锁拆成两种？

要理解这个设计的必要性，得从"如果不拆分会怎样"开始想。

<!-- more -->

## 1. 两种锁分别对应什么语句

先明确映射关系，避免后面混淆：

| MDL 类型 | 典型语句 | 语义 |
|---|---|---|
| **SHARED_READ (SR)** | `SELECT` | 我读数据，但不改表结构 |
| **SHARED_WRITE (SW)** | `INSERT` / `UPDATE` / `DELETE` / `SELECT ... FOR UPDATE` | 我写数据，但也不改表结构 |
| **SHARED_READ_ONLY (SRO)** | `LOCK TABLES t READ` / `FLUSH TABLES WITH READ LOCK` | 我要把表设成只读模式 |

SR 和 SW 的共性：**都不修改元数据**，因此它们互相兼容——多个会话可以同时 `SELECT` 和 `INSERT` 同一张表，这在并发上完全没有冲突。

## 2. 反证：如果 SR 和 SW 不拆分

假设 MySQL 只有一个统一的 `SHARED` 锁来表示"我要访问这张表的数据（但不改结构）"。那么面临第一个问题：

> `LOCK TABLES t READ` 该怎么实现？

`LOCK TABLES ... READ` 的语义是：**允许别人读数据，禁止别人写数据**。它获取的是 SRO 锁。如果 DML 只分一种 SHARED 锁，SRO 与 SHARED 要么兼容、要么不兼容：

- **若 SRO 与 SHARED 兼容**：`LOCK TABLES t READ` 后，`INSERT` 依然能执行——锁失效了。
- **若 SRO 与 SHARED 不兼容**：`LOCK TABLES t READ` 后，`SELECT` 也被阻塞——过度了。

无论怎么选，都无法表达"允许读、禁止写"这个精确语义。这就是拆分 SR 和 SW 的**最直接动机**。

## 3. 兼容性矩阵：拆分后的效果

把 SR 和 SW 分开后，MDL 的兼容性矩阵才能支持精细的并发控制（只保留与本题相关的类型）：

| 请求者 \ 持有者 | **SR** (SELECT) | **SW** (DML 写) | **SRO** (LOCK TABLES READ) | **X** (DDL) |
|---|---|---|---|---|
| **SR** | ✅ 兼容 | ✅ 兼容 | ✅ 兼容 | ❌ 阻塞 |
| **SW** | ✅ 兼容 | ✅ 兼容 | ❌ **阻塞** | ❌ 阻塞 |
| **SRO** | ✅ 兼容 | ❌ **阻塞** | ✅ 兼容 | ❌ 阻塞 |
| **X** | ❌ 阻塞 | ❌ 阻塞 | ❌ 阻塞 | ❌ 阻塞 |

关键差异只有一格：**SW 与 SRO 不兼容，但 SR 与 SRO 兼容**。正是这一格，让以下三个场景成为可能。

## 4. 场景一：LOCK TABLES READ

```sql
-- 会话 A
LOCK TABLES orders READ;

-- 会话 B
SELECT * FROM orders WHERE id = 1;   -- ✅ 成功，SR 与 SRO 兼容

-- 会话 C
INSERT INTO orders VALUES (...);      -- ❌ 阻塞，SW 与 SRO 冲突
```

业务上这很合理：我把表设成只读副本模式，你可以查，但不能写。如果 SR 和 SW 合并成一个锁，这个语义就崩塌了。

## 5. 场景二：FLUSH TABLES WITH READ LOCK (FTWRL)

这是备份工具（如 mysqldump `--master-data`）的标准起手式：

```sql
FLUSH TABLES WITH READ LOCK;  -- 获取全局 SRO 锁
```

FTWRL 的目标是：**在整个实例层面建立一个一致性的逻辑时间点，允许读，禁止写**。拆分后的效果：

- `SELECT` 继续执行（SR 与 SRO 兼容）
- `INSERT/UPDATE/DELETE` 被阻塞（SW 与 SRO 冲突）
- `ALTER TABLE` 被阻塞（X 与 SRO 冲突）

如果没有 SR/SW 拆分，FTWRL 要么挡不住写入，要么把只读查询也挡住——备份工具就没办法做了。

## 6. 场景三：Online DDL 的中间阶段

MySQL 5.6+ 的 Online DDL 允许在修改表结构时，尽量不影响并发 DML。其 MDL 锁的获取通常经历一个升降级的过程：

```
SU（准备阶段，允许并发 SR + SW）
  ↓
S / SNW（执行阶段，视算法而定）
  ↓
X（提交阶段，短暂阻塞所有操作）
```

其中 `SNW`（SHARED_NO_WRITE）与 SR 兼容、与 SW 不兼容。这意味着：

> Online DDL 的某些中间阶段允许你 `SELECT`，但不允许你 `INSERT/UPDATE/DELETE`。

这通常发生在需要读取全表数据并构建新结构，但不想让新写入引入更多版本链复杂度的时刻。如果 SR 和 SW 没有拆分，Online DDL 就失去了一个重要的并发优化档位，只能粗暴地在"完全允许 DML"和"完全禁止 DML"之间二选一。

## 7. 源码中的对应关系

在 MySQL 源码（`sql/mdl.h`）中，这个兼容性是通过 `MDL_lock::m_compatible` 位图矩阵硬编码的：

```cpp
// 简化示意
// SR 与 SRO 兼容
// SW 与 SRO 不兼容
```

实际获取锁的调用在 `sql_parse.cc` 和 `sql_base.cc` 中：

- `SELECT` → `mdl_request.init(MDL_key::TABLE, db, name, MDL_SHARED_READ, MDL_TRANSACTION)`
- `INSERT/UPDATE/DELETE` → `mdl_request.init(..., MDL_SHARED_WRITE, ...)`
- `LOCK TABLES ... READ` → `mdl_request.init(..., MDL_SHARED_READ_ONLY, ...)`

## 8. 常见误区

### 误区 1：SR/SW 保护的是数据还是元数据？

**元数据**。SR 和 SW 都是 MDL（Metadata Lock），它们保护的是表结构，不是行数据。行数据的并发由 InnoDB 的行锁（Record Lock / Gap Lock / Next-Key Lock）处理。

MDL 解决的是"能不能解析这条 SQL 用到的表结构"，InnoDB 行锁解决的是"能不能修改这行数据"。

### 误区 2：SR 和 SW 之间有冲突吗？

**没有**。SR 与 SW 完全兼容，可以大量并发。它们的分歧只出现在与更高级别锁（SRO、SNW、X）的交互中。

### 误区 3：不加区分地用 SHARED 锁不行吗？

对于简单场景（比如只有一个 `SHARED` 和一个 `EXCLUSIVE`）确实够用。但 MySQL 要支持的语义太多了：`LOCK TABLES`、`Online DDL`、`FTWRL`、`HANDLER`、存储过程、触发器、外键检查……没有细粒度的 MDL 档位，这些功能会互相踩踏。

## 9. 一句话总结

> **SR 与 SW 的分裂，不是为了限制它们彼此，而是为了在引入更强的锁（如 SRO、SNW）时，能够精确地表达"允许读数据、禁止写数据"的语义。**

没有这个拆分，`LOCK TABLES READ`、`FLUSH TABLES WITH READ LOCK`、Online DDL 的中间阶段，统统无法实现。这是元数据锁从"能用"走向"好用"的关键一步。

---

## 参考

- [MySQL 8.0 Reference Manual / Metadata Locking](https://dev.mysql.com/doc/refman/8.0/en/metadata-locking.html)
- [MySQL Source: sql/mdl.h](https://github.com/mysql/mysql-server/blob/8.0/sql/mdl.h)
- [MySQL Source: sql/mdl.cc](https://github.com/mysql/mysql-server/blob/8.0/sql/mdl.cc) - `MDL_lock::can_grant_lock` 兼容性判断
- [MySQL Internals Manual: Online DDL](https://dev.mysql.com/doc/internals/en/online-ddl.html)
