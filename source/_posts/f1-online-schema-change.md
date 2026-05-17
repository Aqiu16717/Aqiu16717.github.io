---
title: Google F1 的 Online Schema Change 设计与实现
description: \'在分布式数据库里改表结构，是一件比单机数据库复杂得多的事情。Google F1 的论文 Online, Asynchronous Schema Change in F1 给出了一个经典的解法：如何在不停机、不阻塞读写的前提下，完成分布式环境下的 schema 变更。这套机制后来被 Spanner、CockroachDB 等系统广泛借鉴。\'
updated: 2026-05-09 13:44:05
date: 2026-05-09 14:00:00
tags:
  - F1
  - Google
  - Spanner
  - Schema Change
  - 分布式数据库
  - 数据库
categories:
  - 数据库
lang: zh-CN
---

在分布式数据库里改表结构，是一件比单机数据库复杂得多的事情。Google F1 的论文 *Online, Asynchronous Schema Change in F1* 给出了一个经典的解法：如何在不停机、不阻塞读写的前提下，完成分布式环境下的 schema 变更。这套机制后来被 Spanner、CockroachDB 等系统广泛借鉴。

<!-- more -->

## 1. 背景：F1 是谁

F1 是 Google 开发的**分布式关系型数据库**，构建在 Spanner 之上：

- **Spanner** 负责分布式存储、事务、TrueTime 时钟同步
- **F1** 负责 SQL 解析、查询优化、schema 管理、二级索引维护

F1 集群由大量 F1 服务器（无状态 SQL 层）和底层的 Spanner 存储节点组成。用户通过 F1 服务器执行 SQL，F1 服务器再把请求翻译成对 Spanner 的读写操作。

这意味着：**同一张表，可能被成百上千个 F1 服务器同时访问**。改 schema 时，不可能像单机 MySQL 那样简单地给表加一把排他锁就改定义——那会导致整个集群的服务不可用。

## 2. 核心挑战

### 2.1 不能停服务

F1 内部有大量实时广告业务，schema 变更必须保证：
- 变更期间**读写请求继续服务**
- 不同 F1 服务器在变更过程中的短暂不一致是允许的，但不能破坏数据正确性

### 2.2 多版本 Schema 共存

分布式系统中没有全局锁能让所有 F1 服务器同时切到新 schema。实际情况是：

```
时间线 ──────────────────────────────────────►

F1 Server A:  Schema v1 ────────► Schema v2
F1 Server B:  Schema v1 ────────────► Schema v2
F1 Server C:  Schema v1 ───────────────► Schema v2
Master:       Schema v1 ───────────────► Schema v2
```

在过渡期，**v1 和 v2 的 schema 会在集群中同时存在**。系统必须保证：
- 用 v1 写的数据，v2 能正确读取
- 用 v2 写的数据，v1 也能正确处理（或至少不破坏数据）

### 2.3 没有全局时钟，但有 TrueTime

F1 依赖 Spanner 的 TrueTime API 获取时间区间 `[earliest, latest]`。这让它能判断事件发生的先后顺序，但无法获得精确的单点时刻。 schema 变更协议必须基于这种**不确定时间**来设计。

## 3. Schema Lease：版本安全的根基

F1 解决多版本共存问题的核心机制是 **Schema Lease（模式租约）**。

### 3.1 每个 F1 服务器持有 lease

每个 F1 服务器在启动时会从 F1 master 获取当前 schema，并附带一个 **lease**：

```
┌─────────────────────────────────────────┐
│  F1 Master (Schema 管理中枢)             │
│  ┌──────────────────────────────────┐   │
│  │  Schema Version: v1              │   │
│  │  Lease Expiration: T + 10min     │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
              │
              │ 获取 lease
              ▼
┌─────────────────────────────────────────┐
│  F1 Server A                            │
│  Schema: v1 (lease valid until T+10min) │
└─────────────────────────────────────────┘
```

F1 服务器在 lease 有效期内，**保证只使用这个版本的 schema** 处理请求。即使 master 已经发布了新 schema，持有旧 lease 的服务器也不会感知到变化。

### 3.2 Lease 的续约与过期

- **正常续约**：F1 服务器定期向 master 请求续约，master 返回相同的 schema 版本但延长 lease 时间
- **lease 过期**：如果服务器崩溃或网络分区，lease 会在固定时间后自然过期。master 不主动通知，而是等时间到
- **lease 时长**：通常设为几分钟（如 10 分钟），这是一个**可用性与变更延迟的权衡**——lease 越长，故障恢复越慢；lease 越短，续约开销越大

### 3.3 Lease 保证什么

Lease 机制提供了两个关键保证：

1. **F1 服务器不会使用过期 schema**：lease 到期后，服务器必须重新向 master 获取 schema。如果 master 已经发布了新版本，服务器就会拿到 v2。

2. **Master 知道旧 schema 的截止日期**：当 master 发布新 schema 时，它知道**最坏情况下**，所有旧 lease 都会在 `max_lease_duration` 之后过期。因此 master 只需等待这个固定时长，就能确信集群中没有服务器还在使用旧 schema。

## 4. Online Schema Change 的流程

F1 的 schema 变更采用**异步、多阶段**的方式推进。以最常见的"添加一列"为例：

### 4.1 阶段一：在 Master 上注册新 Schema

DBA 发起 `ALTER TABLE users ADD COLUMN age INT DEFAULT 0`。

F1 master 收到请求后：
1. 校验变更合法性
2. 把新 schema **标记为即将生效**，但暂时不对外提供服务
3. 把变更记录写入 Spanner（作为持久化日志）

此时，所有 F1 服务器仍然使用旧 schema。

### 4.2 阶段二：写入新 Schema，开始双版本共存

Master 正式把新 schema 设为当前版本，并开始对外提供 lease。

- 新启动或续约的 F1 服务器会拿到 **v2 schema**
- 仍然持有旧 lease 的 F1 服务器继续使用 **v1 schema**

**关键问题**：v1 服务器不知道新列 `age` 的存在，v2 服务器要求写 `age`。怎么保证兼容性？

F1 的解法：**新列在 v1 的视角下是 "absent"（不存在）的**。v1 服务器读取数据时，不会尝试读取 `age` 列；v1 服务器写入数据时，也不会写 `age` 列（底层 Spanner 会自动填充默认值）。

对于 v2 服务器：
- 读操作：正常读取 `age`，如果底层存储没有（因为是 v1 写的），返回默认值 0
- 写操作：必须写入 `age` 值

### 4.3 阶段三：等待旧 Lease 全部过期

Master 记录新 schema 的发布时间 `T_new`。它需要等待至少 `max_lease_duration` 时间，确保所有在 `T_new` 之前获取的 lease 都已经过期。

```
Master: 发布 v2 在 T=0
        等待 10min (max lease duration)
        在 T=10min 确认：所有服务器都已拿到 v2
```

这个阶段是**纯等待**，不需要与任何 F1 服务器交互。

### 4.4 阶段四：清理旧 Schema

当 master 确认没有旧 lease 存在后：
1. 删除旧 schema 版本
2. 如果变更是添加列，此时可以安全地把新列从 "absent in v1" 的状态转为正式列
3. 如果变更是删除列，此时可以安全地从存储层回收被删列的数据

对于**删除列**操作，F1 不会立即物理删除数据。它会先把列标记为 "absent"，等所有服务器都切换到不包含该列的新 schema 后，再异步清理底层存储。

## 5. 不同操作的细节处理

### 5.1 添加列（ADD COLUMN）

| 阶段 | v1 服务器行为 | v2 服务器行为 | 底层数据 |
|---|---|---|---|
| 双版本期 | 读写都不涉及新列 | 读不到时返回默认值；写必须带新列值 | v1 写的行：新列不存在（Spanner 补默认值） |
| 旧 lease 过期后 | 无（全部 v2） | 正常读写 | 所有行都有新列值 |

F1 利用 Spanner 的能力：即使 schema 要求某列存在，如果底层存储中某行缺少该列，Spanner 可以自动返回默认值。这避免了全表回填（backfill）的阻塞操作。

### 5.2 删除列（DROP COLUMN）

删除列更危险，因为旧服务器可能还在读写该列。

F1 的处理：
1. 先发布一个**中间版本 schema**：列仍然存在，但标记为 "pending drop"
2. 等所有服务器都拿到中间版本（旧 lease 过期）
3. 再发布最终版本 schema：列彻底消失
4. 异步后台任务清理底层存储中的旧列数据

这实际上是一个**两阶段的 schema 变更**。

### 5.3 添加索引（ADD INDEX）

加索引是 schema 变更中最复杂的操作之一，因为它涉及大量数据回填。

F1 的加索引流程：
1. **写 schema 变更**：新索引标记为 "write only" —— 新写入的数据必须同时写索引，但索引还不用于查询
2. **全表回填**：启动后台任务，扫描全表，为已有数据构建索引条目。这个过程可能持续数小时
3. **回填完成后**：把索引标记为 "public" —— 可以用于查询了
4. **等待旧 lease 过期**：确保没有服务器还在使用 "无索引" 的旧 schema
5. **清理**：删除 "write only" 状态的中间信息

关键点：**回填期间，写操作必须同时维护新索引**。F1 通过 Spanner 的事务保证这一点。

### 5.4 删除索引（DROP INDEX）

相对简单：
1. 发布新 schema：索引标记为 "absent"
2. 等旧 lease 过期，确认没有服务器使用该索引
3. 异步删除底层索引数据

## 6. 故障处理

### 6.1 F1 服务器崩溃

崩溃的服务器持有的 lease 会在固定时间后过期。新启动的服务器会向 master 获取最新 schema。不需要任何恢复协议。

### 6.2 F1 Master 崩溃

Master 本身也是高可用的（通常基于 Paxos/Raft 选主）。新 master 上任后，从 Spanner 读取 schema 状态，继续推进未完成的变更。

### 6.3 网络分区

如果某个 F1 服务器与 master 分区隔离：
- 如果 lease 未过期：服务器继续用本地缓存的 schema 服务，但无法续约
- 如果 lease 过期：服务器**拒绝服务**，直到重新连上 master 获取新 schema

这种设计避免了脑裂：分区隔离的服务器不会用旧 schema 无限期地写数据。

## 7. 与 MySQL Online DDL 的对比

| 维度 | Google F1 | MySQL InnoDB |
|---|---|---|
| **架构** | 分布式，无状态 SQL 层 + 共享存储 | 单机或主从复制 |
| **Schema 版本管理** | 多版本同时存在，lease 驱动 | 单版本，MDL + 锁升降级 |
| **变更阻塞** | 完全不阻塞读写 | 大部分操作不阻塞，但某些阶段短暂阻塞 |
| **默认值填充** | 存储层自动返回默认值，无需 backfill | 需要 backfill（除非 online DDL + inplace） |
| **加索引** | 后台异步回填 + write-only 阶段 | Online DDL 的 inplace 创建，或 pt-osc 工具 |
| **故障恢复** | lease 自然过期，无需额外协调 | 依赖事务回滚或手动恢复 |
| **时间依赖** | 依赖 TrueTime 区间 | 依赖本地系统时钟 |

F1 的方案更适合**大规模分布式环境**，因为它把协调的复杂度降到了最低——不需要通知所有节点，只需要等 lease 自然过期。代价是 schema 变更的**延迟更高**（至少要等一个 lease 周期）。

MySQL 的 Online DDL 更适合**单机或小规模集群**，它通过精细的 MDL 锁和存储引擎层的协调，可以在秒级完成 schema 切换，但对分布式多节点的协调能力有限。

## 8. 总结

F1 的 Online Schema Change 核心设计可以概括为三句话：

> **1. Lease 机制替代全局广播**：不用通知所有服务器，而是让旧 schema 自然过期。
>
> **2. 多版本共存是常态**：v1 和 v2 同时在集群中运行是设计的一部分，不是异常。
>
> **3. 存储层兜底兼容性**：利用 Spanner 自动返回默认值的能力，避免全表阻塞回填。

这套机制后来被 CockroachDB 的 **Online Schema Changes** 直接借鉴（CockroachDB 的论文标题甚至和 F1 类似）。理解 F1 的设计，对理解现代分布式数据库的 schema 管理有重要的参考价值。

---

## 参考

- [Online, Asynchronous Schema Change in F1](https://research.google/pubs/41376/) — Google Research, 2013
- [F1: A Distributed SQL Database That Scales](https://research.google/pubs/41344/) — Google Research, 2013
- [Spanner: Becoming a SQL System](https://research.google/pubs/46103/) — SIGMOD 2017
- [CockroachDB: Online Schema Changes](https://www.cockroachlabs.com/blog/how-online-schema-changes-are-possible-in-cockroachdb/) — CockroachDB Blog
