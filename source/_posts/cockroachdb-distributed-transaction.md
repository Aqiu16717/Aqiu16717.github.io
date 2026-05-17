---
title: CockroachDB 分布式事务实现原理
date: 2026-05-11 12:48:00
tags:
  - CockroachDB
  - 分布式事务
  - 2PC
  - MVCC
  - 分布式系统
categories:
  - 分布式系统
lang: zh-CN
---

CockroachDB（蟑螂数据库）是一个面向云的分布式 SQL 数据库，其核心设计目标是在全球分布式环境下提供强一致性（Serializable 隔离级别）的事务支持。本文深入解析 CockroachDB 分布式事务的实现原理。

<!-- more -->

## 1. 架构概览

CockroachDB 采用**无共享（Shared-Nothing）**架构，数据按 Range（默认 512MB）进行分片，每个 Range 通过 Raft 共识算法在多个节点间复制。

```
┌─────────────────────────────────────────┐
│              SQL Layer                  │
│    (Parser / Planner / Executor)        │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│           Transaction Layer             │
│   (并发控制 / 冲突检测 / 时间戳管理)      │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│         Distribution Layer              │
│      (Range 路由 / 副本定位)             │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│           Replication Layer             │
│         (Raft 共识 / 复制)              │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│            Storage Layer                │
│      (RocksDB / Pebble / MVCC)          │
└─────────────────────────────────────────┘
```

## 2. 核心机制：MVCC + HLC

### 2.1 混合逻辑时钟（HLC）

CockroachDB 不使用传统的集中式时间戳服务，而是采用**混合逻辑时钟（Hybrid Logical Clock）**：

```
HLC = (Physical Time, Logical Counter)
```

- **Physical Time**：物理时钟（Wall Time），通常从 NTP 或原子钟获取
- **Logical Counter**：逻辑计数器，处理物理时钟相同但存在因果关系的操作

HLC 既保留了物理时间的直观性，又能通过逻辑部分捕捉事件的因果关系（Happens-Before）。

### 2.2 MVCC 存储模型

CockroachDB 底层存储引擎（Pebble）采用 MVCC 机制，每个 KV 对都带有一个**时间戳**：

```
Key@Timestamp -> Value
```

例如，同一行数据在不同时间点的多个版本：

```
/user/123/name@T100 -> "Alice"
/user/123/name@T95  -> "Bob"
/user/123/age@T100  -> 30
/user/123/age@T90   -> 25
```

读取时只需指定时间戳，就能获取该时间点的数据快照，从而实现**无锁读取**。

## 3. 事务模型

### 3.1 写意向（Write Intent）

CockroachDB 事务写入时，并不直接覆盖旧值，而是先写入一种特殊的记录——**写意向（Write Intent）**：

```
Key@ProposedTimestamp -> Value + Transaction Record Pointer
```

写意向包含：
- 意向数据本身
- 指向**事务记录（Transaction Record）**的指针

事务记录存储在事务协调节点上，记录事务状态（PENDING、COMMITTED、ABORTED）。

### 3.2 事务状态推进

```
┌─────────┐    执行写操作    ┌─────────┐
│  START  │ ──────────────> │ PENDING │
└─────────┘                 └────┬────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │ Commit           │                  │
              ▼                  │ Abort            │
        ┌──────────┐             │                  │
        │ COMMITTED│ <───────────┘                  │
        └────┬─────┘                                │
             │                                       │
             │ Resolve Intents                       │
             ▼                                       │
        ┌─────────┐                                  │
        │  DONE   │                            ┌──────────┐
        └─────────┘                            │ ABORTED  │
                                               └──────────┘
```

## 4. 并发控制：Serializable 的保障

### 4.1 读写冲突处理

CockroachDB 默认提供 **Serializable** 隔离级别，这是 SQL 标准中最强的隔离级别。其核心冲突处理规则：

| 场景 | 处理方式 |
|------|---------|
| 读遇到写意向（未提交） | 检查事务记录，若已提交则读取；若未提交则视情况等待或推进时间戳 |
| 写遇到写意向 | 等待或中止其中一个事务 |
| 写遇到旧读时间戳 | 推进读取时间戳（Read Timestamp Push），可能触发事务重启 |

### 4.2 读时间戳推进（Read Timestamp Push）

当一个事务 T1（时间戳 T10）读取某 Key 时，发现已有一个提交的事务 T2（时间戳 T15）写入了新版本。此时 T1 不能读取旧版本，否则就破坏了 Serializable：

**解决方案**：将 T1 的读取时间戳推进到 T15 之后。

但这可能导致 T1 之前读取的数据不一致，因此 T1 必须**重启（Restart）**，以新的时间戳重新执行。

### 4.3 写偏斜（Write Skew）的防护

CockroachDB 采用**串行化图检测（Serializable Graph Testing）**来防止写偏斜：

- 事务在提交时检查是否存在读写冲突构成的环
- 若发现潜在写偏斜，强制其中一个事务重试

```sql
-- 经典写偏斜示例：值班医生问题
-- 事务 T1: 检查医生数 > 1，然后请病假
-- 事务 T2: 检查医生数 > 1，然后请病假
-- 结果：两个事务都成功，但值班医生数为 0

-- CockroachDB 会检测这种冲突并阻止
```

## 5. Parallel Commit：优化后的两阶段提交

### 5.1 传统 2PC 的问题

传统两阶段提交延迟高：
1. Prepare 阶段：协调者向所有参与者发送 Prepare
2. 参与者写本地日志并回复
3. Commit 阶段：协调者收到全部 OK 后发送 Commit
4. 参与者正式提交

**网络往返次数多**，跨地域场景下延迟可达数百毫秒。

### 5.2 Parallel Commit 设计

CockroachDB 提出 **Parallel Commit** 协议，核心思想：**在写意向阶段就同时启动事务记录的写入**，使得 Prepare 和 Commit 阶段可以重叠：

```
Traditional 2PC:                    Parallel Commit:

Client                              Client
  │ Write(K1, K2)                     │ Write(K1, K2)
  ▼                                   ▼
Coord ──Prepare──> P1, P2          Coord ──Write Intents──> P1, P2
  │ <────Yes─────                    │   (Intents 包含 txn record 指针)
  │                                   │
  │ ──Commit────> P1, P2            Coord ──Finalize Txn──> Txn Record
  │ <────ACK─────                    │   (异步清理 Intents)
  │                                   │
  ▼ Done                             ▼ Done
                                      (无需等待所有参与者确认)
```

**关键点**：
- 写意向和事务记录写入**并行发起**
- 客户端在事务记录写入完成后即可收到成功响应
- 意向记录的清理（Resolve Intents）**异步进行**

### 5.3 事务记录的 STAGING 状态

Parallel Commit 引入了一个新的中间状态 **STAGING**：

```
PENDING ──> STAGING ──> COMMITTED/ABORTED
```

- **STAGING**：所有写意向已写入，但尚未确认是否全部成功
- 其他事务遇到 STAGING 状态的写意向时，会**异步协助检查**所有意向是否已写入
- 若全部写入成功，则帮助推进到 COMMITTED 状态

这种设计使得事务提交不再是协调者的"独奏"，而是整个系统的"协作"。

## 6. 事务流水线（Transaction Pipelining）

CockroachDB 进一步优化了跨 Range 事务：

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Range A   │     │   Range B   │     │   Range C   │
│  (Leader)   │     │  (Leader)   │     │  (Leader)   │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       │ Write Intent(K1)  │ Write Intent(K2)  │ Write Intent(K3)
       │                   │                   │
       ▼                   ▼                   ▼
    [异步复制]           [异步复制]           [异步复制]
```

- 事务协调者**串行**向各 Range Leader 发送写请求
- 每个 Range 内部通过 Raft **异步**复制到副本
- 协调者**无需等待 Raft 复制完成**，只需等待 Leader 确认收到即可继续
- 最终提交时，利用 Raft 的多数派保证持久性

## 7. 事务重启与退避

### 7.1 可重试错误（Retryable Errors）

当时间戳推进或冲突发生时，CockroachDB 会返回**可重试错误**（如 `TransactionRetryWithProtoRefreshError`）：

```go
// 客户端处理模式
for {
    tx, _ := db.Begin()
    _, err := tx.Exec("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
    if err != nil {
        tx.Rollback()
        if isRetryable(err) {
            continue  // 重试
        }
        return err
    }
    err = tx.Commit()
    if err == nil {
        break
    }
    if isRetryable(err) {
        continue  // 重试
    }
    return err
}
```

### 7.2 SAVEPOINT 重试

CockroachDB 支持使用 `SAVEPOINT cockroach_restart` 进行更高效的重试：

```sql
BEGIN;
SAVEPOINT cockroach_restart;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
RELEASE SAVEPOINT cockroach_restart;
COMMIT;
```

客户端驱动（如 `lib/pq`、`pgx`）通常会自动处理这种重试逻辑。

## 8. 与 Spanner 的对比

| 特性 | CockroachDB | Spanner |
|------|-------------|---------|
| 时钟同步 | HLC（依赖 NTP） | TrueTime（原子钟+GPS） |
| 默认隔离级别 | Serializable | External Consistency（等价 Serializable） |
| 提交协议 | Parallel Commit | 2PC + Paxos Group |
| 读特性 | 无锁读（MVCC） | 快照读（Snapshot Read） |
| 外部一致性 |  Bounded Staleness |  TrueTime 保证全局线性一致 |

CockroachDB 的设计哲学是：**在不依赖特殊硬件（原子钟）的前提下，通过软件算法达到近似 Spanner 的一致性保证**。

## 9. 总结

CockroachDB 的分布式事务实现是多项技术的精妙组合：

1. **HLC + MVCC**：用时间戳代替锁，实现高效的无锁读取
2. **Write Intent**：将事务状态嵌入数据本身，实现去中心化的冲突检测
3. **Parallel Commit**：重构 2PC，将延迟从多个 RTT 降低到接近 1 个 RTT
4. **Serializable Graph Testing**：在运行时检测并阻止写偏斜等异常

这套机制使得 CockroachDB 能够在全球分布式环境下，提供与传统单机数据库等价的 Serializable 隔离保证，同时保持水平扩展能力。

## 参考

- [CockroachDB Architecture Docs](https://www.cockroachlabs.com/docs/stable/architecture/overview.html)
- [Parallel Commit: A Distributed Transaction Protocol](https://www.cockroachlabs.com/blog/parallel-commits/)
- [Serializable, Lockless, Distributed: Isolation in CockroachDB](https://www.cockroachlabs.com/blog/serializable-lockless-distributed-isolation-cockroachdb/)
- [Spanner: Google’s Globally-Distributed Database](https://research.google/pubs/pub39966/)
- [Logical Physical Clocks and Consistent Snapshots in Globally Distributed Databases](https://cse.buffalo.edu/~demirbas/publications/hlc.pdf)
