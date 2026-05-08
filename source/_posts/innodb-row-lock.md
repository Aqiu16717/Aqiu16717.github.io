---
title: InnoDB 行锁详解
date: 2026-05-08 18:00:00
tags:
  - MySQL
  - InnoDB
  - 行锁
  - 事务
  - 数据库
categories:
  - 数据库
lang: zh-CN
---

InnoDB 的行锁是 MySQL 并发控制的根基，但它有一个反直觉的特点：**行锁并不直接锁在数据行上，而是锁在索引的记录和间隙上**。理解这一点，是搞懂 InnoDB 并发行为的前提。

<!-- more -->

## 1. 行锁锁的是索引，不是数据

InnoDB 的数据通过聚簇索引组织，所有行数据都挂在主键索引的叶子节点上。因此：

> **InnoDB 的行锁，本质上是对索引记录加的锁。**

即使你的 SQL 看起来在操作一行数据，InnoDB 也会先找到对应的索引记录，然后在**索引**上加锁。这也是为什么"查询没有走索引"时，行锁可能退化为表锁——没有索引记录可以锁，只能锁整个表。

---

## 2. 两种基本行锁：S 与 X

| 锁类型 | 名称 | 允许其他事务 | 阻塞其他事务 |
|---|---|---|---|
| **S** | Shared Lock（共享锁 / 读锁） | 再获取 S 锁 | 获取 X 锁 |
| **X** | Exclusive Lock（排他锁 / 写锁） | 无 | 获取 S 或 X 锁 |

获取方式：

```sql
-- S 锁：当前读中的 SELECT ... LOCK IN SHARE MODE
SELECT * FROM users WHERE id = 1 LOCK IN SHARE MODE;

-- X 锁：UPDATE / DELETE / INSERT，或 SELECT ... FOR UPDATE
UPDATE users SET age = 30 WHERE id = 1;
SELECT * FROM users WHERE id = 1 FOR UPDATE;
```

---

## 3. 行锁的三种算法

InnoDB 并不只有"锁住这一行"这一种行为。根据隔离级别和场景，它会使用三种不同的锁定算法：

### 3.1 Record Lock（记录锁）

锁定**索引中的单条记录本身**。

```
+----+-------+-----+
| id | name  | age |
+----+-------+-----+
|  1 | Alice |  30 |  ← 锁住这条索引记录
|  2 | Bob   |  25 |
|  3 | Carol |  28 |
+----+-------+-----+
```

```sql
UPDATE users SET age = 31 WHERE id = 1;  -- 对 id=1 加 X Record Lock
```

Record Lock 只在**唯一索引**（主键或唯一二级索引）上做精确匹配时生效。

### 3.2 Gap Lock（间隙锁）

锁定**两条索引记录之间的空隙**，防止其他事务在这个间隙中插入新记录。

```
索引 id 的排序：  1        2        3
                 │        │        │
                 ↓        ↓        ↓
               (-∞,1]  (1,2]   (2,3]   (3,+∞)
               
-- 对 id=2 加 Gap Lock 时，锁住的是 (1,2) 或 (2,3) 之间的间隙
```

Gap Lock 的特点是：**锁定的是一个范围，而不是具体的记录**。因此：
- 多个事务可以在同一个间隙上同时持有 Gap Lock（互相兼容）
- Gap Lock 只阻止**插入**，不阻止**修改已有记录**

### 3.3 Next-Key Lock（临键锁）

**Record Lock + Gap Lock 的组合**。这是 InnoDB 在 **REPEATABLE READ** 隔离级别下的**默认行锁算法**。

它锁定的是**一条记录 + 这条记录之前的间隙**（左开右闭区间）：

```
对 id=2 的 Next-Key Lock 锁定范围：(1, 2]

即：id=1 到 id=2 之间的间隙 + id=2 这条记录本身
```

```sql
-- RR 隔离级别下
SELECT * FROM users WHERE id >= 2 AND id < 4 FOR UPDATE;

-- 实际锁定的范围（假设表中只有 id=1,2,3,5）：
-- (1, 2]  +  (2, 3]  +  (3, 5]
```

| 算法 | 锁定对象 | 隔离级别 | 场景 |
|---|---|---|---|
| Record Lock | 单条索引记录 | RC / RR | 唯一索引精确匹配 |
| Gap Lock | 记录之间的间隙 | RR | 防止幻读 |
| Next-Key Lock | 记录 + 前间隙 | RR（默认） | 范围查询、非唯一索引 |

> **READ COMMITTED 下，Gap Lock 通常不生效**，除非外键检查或唯一键冲突检测需要。

---

## 4. 意向锁：IS 与 IX

行锁是细粒度的，但 InnoDB 也支持表级锁（如 `LOCK TABLES`）。为了协调两者，InnoDB 引入了**意向锁（Intention Lock）**：

| 锁类型 | 含义 | 触发场景 |
|---|---|---|
| **IS** | Intention Shared | 事务打算对表中某些行加 S 锁 |
| **IX** | Intention Exclusive | 事务打算对表中某些行加 X 锁 |

IX/IS 是**表级锁**，它们不会阻塞其他事务的行级操作，但会阻塞全表锁：

| 请求者 \ 持有者 | IS | IX | S（表锁） | X（表锁） |
|---|---|---|---|---|
| IS | ✅ | ✅ | ✅ | ❌ |
| IX | ✅ | ✅ | ❌ | ❌ |
| S（表锁） | ✅ | ❌ | ✅ | ❌ |
| X（表锁） | ❌ | ❌ | ❌ | ❌ |

规则很简单：**全表锁（S/X）与意向锁（IX/IS）互斥时，全表锁必须等待行锁释放。**

```sql
-- 事务 A
BEGIN;
UPDATE users SET age = 30 WHERE id = 1;  -- 自动获取表的 IX + 行的 X

-- 事务 B（并发）
LOCK TABLES users WRITE;  -- 获取表的 X 锁，被 IX 阻塞，等待...
```

---

## 5. 插入意向锁（Insert Intention Gap Lock）

插入操作比较特殊。`INSERT` 在真正插入前，会先对目标位置加一个**插入意向锁（Insert Intention Lock）**。

这是一种特殊的 Gap Lock，表示"我打算在这个间隙插入数据"。它的关键特性：

- **多个不冲突的插入意向锁可以共存**（如往不同位置插入）
- **插入意向锁与 Gap Lock 冲突**（如果别的事务已锁住这个间隙，插入必须等待）

```sql
-- 事务 A
BEGIN;
SELECT * FROM users WHERE id BETWEEN 2 AND 5 FOR UPDATE;
-- 锁定了 (1,2], (2,3], (3,5] 三个 Next-Key Lock

-- 事务 B
BEGIN;
INSERT INTO users (id, name) VALUES (4, 'Dave');
-- id=4 落在 (3,5] 间隙中，插入意向锁与 A 的 Gap Lock 冲突，阻塞等待
```

---

## 6. MVCC 与行锁：读为什么不阻塞读？

InnoDB 的默认读操作（普通 `SELECT`）**不加任何行锁**。它通过 MVCC 读取事务开始时的快照版本：

```sql
-- 事务 A
BEGIN;
UPDATE users SET age = 30 WHERE id = 1;  -- 对 id=1 加 X 锁

-- 事务 B（并发）
SELECT age FROM users WHERE id = 1;  -- 不加锁，读快照，直接返回旧值
```

这种读称为**一致性非锁定读（Consistent Nonlocking Read）**。

如果你需要读到最新提交的数据（或阻塞等待），就要用**锁定读（Locking Read）**：

```sql
SELECT * FROM users WHERE id = 1 FOR UPDATE;      -- 加 X 锁
SELECT * FROM users WHERE id = 1 LOCK IN SHARE MODE;  -- 加 S 锁
```

| 读类型 | SQL | 是否加锁 | 读到什么 |
|---|---|---|---|
| 快照读 | `SELECT` | 不加锁 | 事务快照中的版本 |
| 当前读（X） | `SELECT ... FOR UPDATE` | 加 X 锁 | 最新已提交版本 |
| 当前读（S） | `SELECT ... LOCK IN SHARE MODE` | 加 S 锁 | 最新已提交版本 |

---

## 7. 一个死锁案例

```sql
-- 表结构
CREATE TABLE accounts (id INT PRIMARY KEY, balance INT);
INSERT INTO accounts VALUES (1, 100), (2, 200);

-- 事务 A
BEGIN;
UPDATE accounts SET balance = balance - 10 WHERE id = 1;  -- 锁住 id=1

-- 事务 B
BEGIN;
UPDATE accounts SET balance = balance - 10 WHERE id = 2;  -- 锁住 id=2

-- 事务 A 继续
UPDATE accounts SET balance = balance + 10 WHERE id = 2;  -- 等待 B 释放 id=2 ❌

-- 事务 B 继续
UPDATE accounts SET balance = balance + 10 WHERE id = 1;  -- 等待 A 释放 id=1 ❌

-- 死锁！InnoDB 会自动检测并回滚其中一个事务（通常是修改行数较少的那个）
```

### 如何避免这类死锁

1. **固定的访问顺序**：所有事务都按 `id` 升序加锁
2. **缩短事务长度**：减少持有锁的时间窗口
3. **批量操作时一次性获取所有需要的锁**：而非逐行获取

---

## 8. 查看和排查锁

### 8.1 当前锁信息

```sql
-- MySQL 8.0
SELECT * FROM performance_schema.data_locks 
WHERE OBJECT_NAME = 'users';

-- 锁等待关系
SELECT * FROM performance_schema.data_lock_waits;
```

### 8.2 关键字段解读

| 字段 | 含义 |
|---|---|
| `LOCK_TYPE` | TABLE / RECORD |
| `LOCK_MODE` | S, X, IS, IX, GAP, NEXT-KEY |
| `LOCK_STATUS` | GRANTED / WAITING |
| `LOCK_DATA` | 锁定的索引值 |

### 8.3 常见 lock_mode 含义

| 值 | 含义 |
|---|---|
| `X` | X Record Lock |
| `S` | S Record Lock |
| `X,GAP` | X Gap Lock |
| `S,GAP` | S Gap Lock |
| `X,REC_NOT_GAP` | 纯 Record Lock（不含 Gap） |
| `S,REC_NOT_GAP` | 纯 S Record Lock |
| `X,GAP,INSERT_INTENTION` | 插入意向锁 |

---

## 9. 参数调优

| 参数 | 默认值 | 作用 |
|---|---|---|
| `innodb_lock_wait_timeout` | 50 秒 | 行锁等待超时时间，超时后报错 |
| `innodb_deadlock_detect` | ON | 是否开启死锁检测。高并发写入场景（如秒杀）可关闭，靠超时回滚 |
| `innodb_locks_unsafe_for_binlog` | OFF | 已废弃，用隔离级别控制 Gap Lock |

> **注意**：`innodb_deadlock_detect = OFF` 在高并发热点行更新场景（如库存扣减）能显著提升性能，代价是死锁时只能等 `innodb_lock_wait_timeout` 超时。

---

## 10. 总结

| 概念 | 一句话解释 |
|---|---|
| **行锁锁索引** | 没有索引记录，就无处加锁，可能退化为表锁 |
| **Record Lock** | 锁住单条索引记录 |
| **Gap Lock** | 锁住记录之间的间隙，阻止插入 |
| **Next-Key Lock** | 记录 + 前间隙，RR 隔离级别的默认算法 |
| **意向锁** | 表级标记，协调行锁与表锁的关系 |
| **插入意向锁** | 插入前对间隙加的标记，与 Gap Lock 互斥 |
| **MVCC** | 普通 SELECT 不加锁，读历史快照 |
| **当前读** | `FOR UPDATE` / `LOCK IN SHARE MODE`，加锁读最新值 |

InnoDB 的行锁设计精妙之处在于：**用索引上的锁，同时解决了并发控制和幻读问题**。Next-Key Lock 让 RR 隔离级别下不需要串行化，就能避免幻读——这是 InnoDB 区别于许多其他存储引擎的核心竞争力。

---

## 参考

- [MySQL 8.0 Reference Manual / InnoDB Locking](https://dev.mysql.com/doc/refman/8.0/en/innodb-locking.html)
- [MySQL 8.0 Reference Manual / Phantom Rows](https://dev.mysql.com/doc/refman/8.0/en/innodb-next-key-locking.html)
- [MySQL 8.0 / data_locks Table](https://dev.mysql.com/doc/refman/8.0/en/performance-schema-data-locks-table.html)
- [InnoDB 事务锁源码分析](https://dev.mysql.com/doc/dev/mysql-server/latest/classlock__rec__t.html)
