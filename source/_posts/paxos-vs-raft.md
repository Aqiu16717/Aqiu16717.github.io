---
title: Paxos vs Raft：共识算法的两面
date: 2026-05-08 14:00:00
tags:
  - Paxos
  - Raft
  - 共识算法
  - 分布式一致性
  - 分布式系统
categories:
  - 分布式系统
lang: zh-CN
---

分布式系统的核心难题之一是**共识（Consensus）**：如何让一群可能故障的节点对某个值达成一致。Paxos 和 Raft 是这个问题最著名的两个解法。它们解决的是同一个问题，但走了截然不同的路径。

<!-- more -->

## 1. 共识问题到底是什么

想象一个银行系统，有 5 台服务器共同维护账户余额。客户端发起转账请求，系统必须保证：

- 所有正常工作的服务器最终看到相同的操作序列
- 已经确认的操作不会丢失或回滚
- 即使部分服务器宕机，服务依然可用

这就是共识算法要解决的问题。Paxos 和 Raft 都满足两个核心安全属性：

- **安全性（Safety）**：不会做出错误的决定（不会有两个不同的值被提交）
- **活性（Liveness）**：在大多数节点正常工作时，最终能做出决定

> 两者都只处理非拜占庭故障（节点可以宕机、断网，但不会恶意撒谎）。

---

## 2. Paxos：简洁的数学之美

### 2.1 起源

Paxos 由 Leslie Lamport 于 1990 年提出。据说 Lamport 用了一个虚构的希腊岛屿 Paxos 上的立法会议来比喻这个算法——以至于论文初稿被拒，因为审稿人觉得"这篇论文虽然有趣，但跟计算机系统没什么关系"。

### 2.2 核心设计

Paxos 的精髓异常简洁，只有两个阶段：

**Phase 1（Prepare & Promise）**
- Proposer 选择一个提案编号 `n`，向多数派 Acceptor 发送 `Prepare(n)`
- Acceptor 承诺：不再接受比 `n` 更小的提案，并返回自己已经接受的最高编号提案

**Phase 2（Accept & Accepted）**
- Proposer 从多数派的响应中选出值 `v`（如果已有接受的值就用它，否则用自己想提的值）
- 向多数派发送 `Accept(n, v)`
- Acceptor 接受这个提案（如果没有收到更高编号的 Prepare）

### 2.3 Multi-Paxos：从单值到日志

Basic Paxos 只能对一个值达成共识。实际系统中需要连续决定一系列值（即复制日志），于是有了 Multi-Paxos：

- 选出一个**稳定的 Leader** 来避免每轮都跑两阶段
- Leader 直接对日志的每个槽位执行 Phase 2
-  Leader 不变时，跳过 Phase 1，性能接近一次网络 RTT

但这里有个微妙之处：**Paxos 的论文没有明确说明怎么选 Leader**。工程实现中，各系统（如 Chubby、ZooKeeper 的 Zab）都有自己的 Leader 选举机制，这让 Paxos 的"标准实现"变得模糊。

---

## 3. Raft：为可理解性而生

### 3.1 设计动机

Raft 由 Diego Ongaro 和 John Ousterhout 在 2014 年提出。他们的出发点很直接：

> "Paxos 太难了，连专家都经常搞错。我们需要一个同样正确但容易理解和实现的算法。"

Raft 的设计哲学是**将问题拆分**，而不是像 Paxos 那样提供一个统一但抽象的方案。

### 3.2 三个子问题

Raft 将共识问题明确拆成三个相对独立的子问题：

| 子问题 | 职责 | 对应 Paxos 中的概念 |
|---|---|---|
| **领导者选举** | 集群中只有一个 Leader 处理写请求 | Multi-Paxos 中的 Leader，但 Raft 明确定义了选举机制 |
| **日志复制** | Leader 将日志条目复制到多数派 Follower | Multi-Paxos 的 Phase 2 |
| **安全性** | 保证已提交的日志不会被覆盖 | Paxos 的核心保证 |

### 3.3 强 Leader 设计

Raft 是一个**强 Leader** 算法：

- 所有写请求必须经过 Leader
- Leader 决定日志的顺序
- Follower 被动接收，不主动发起写
- Leader 通过心跳维持权威，Follower 超时未收到心跳则发起选举

这让 Raft 的行为非常直观：平时像主从复制，故障时自动切换。

---

## 4. 核心差异对比

### 4.1 设计哲学

| 维度 | Paxos | Raft |
|---|---|---|
| **核心抽象** | 对单值达成共识 | 管理复制日志 |
| **Leader 角色** | 可选优化（Multi-Paxos 引入） | 核心设计，不可或缺 |
| **问题拆分** | 统一处理，阶段耦合 | 明确拆分为选举、复制、安全 |
| **日志顺序** | 隐式，各槽位独立协商 | 显式，Leader 强制定义全局顺序 |

Paxos 像是一个数学定理：精练、通用，但需要你自行推导如何应用到实际系统。Raft 像是一个工程手册：步骤清晰，照着做就行。

### 4.2 角色定义

**Paxos 的角色：**
- **Proposer**：提出提案
- **Acceptor**：投票决定是否接受
- **Learner**：学习已决定的值

一个节点可以同时扮演多个角色。角色的分离让 Paxos 理论上很灵活，但也增加了理解的复杂度。

**Raft 的角色：**
- **Leader**：处理所有客户端请求，复制日志
- **Follower**：被动接收 Leader 的日志和心跳
- **Candidate**：选举期间的临时状态

Raft 的状态机转换非常清晰：Follower → Candidate → Leader，且任何时刻只有一个 Leader（ per term）。

### 4.3 日志不一致的处理

这是两者工程实现差异最大的地方。

**Paxos** 对每个槽位独立运行共识。这意味着：
- 不同槽位可以由不同 Leader 提出
- 可能出现"空洞"（某些槽位尚未决定）
- 日志不一定连续，需要额外的机制填补空缺

**Raft** 强制日志连续性：
- Leader 的日志必须连续
- Follower 的日志如果不一致，Leader 会**强制覆盖**（找到分歧点，删除 Follower 后续日志，同步自己的）
- 这简化了实现，但也意味着 Leader 必须拥有最完整的日志才能当选（通过选举限制保证）

### 4.4 可理解性与实现难度

| 维度 | Paxos | Raft |
|---|---|---|
| **论文易读性** | 公认的晦涩，存在多种"解释性论文" | 刻意为易理解性设计，有配套可视化教程 |
| **正确性证明** | 简洁优雅，基于严格的数学推导 | 相对复杂，需要分别证明三个子问题的正确性 |
| **工程实现** | 缺少标准实现，各系统差异大 | 实现路径清晰，社区有大量参考实现 |
| **调试难度** | 高（状态空间大，行为不直观） | 相对较低（Leader/Follower 行为明确） |

Raft 的论文中有过一个著名实验：让大学生分别学习 Paxos 和 Raft，然后回答问题和实现算法。Raft 组的理解程度和实现正确率显著高于 Paxos 组。

---

## 5. 性能对比

在性能上，两者没有本质差距。共识算法的瓶颈通常是网络 RTT 和磁盘持久化，而非算法本身。

### 5.1 正常情况

- **Paxos（Multi-Paxos）**：Leader 稳定时，一次写需要 1 个 RTT（Leader → Follower → Leader）
- **Raft**：Leader 收到请求后，并发发送 AppendEntries，多数派确认后即可提交，同样是 1 个 RTT

### 5.2 Leader 切换

- **Paxos**：如果实现中没有明确的 Leader 租约，可能出现多 Proposer 竞争，导致活锁（Livelock）
- **Raft**：选举超时引入随机化，快速收敛到新 Leader，避免长期竞争

### 5.3 读请求

- **朴素实现**：两者都需要走日志流程，性能差
- **Paxos**：可以通过 Lease 机制优化读
- **Raft**：有 Read Index、Lease Read、Follower Read 等多种成熟优化方案

> 实际系统中，Paxos 和 Raft 的性能差异更多取决于实现质量（如批量处理、流水线、零拷贝等），而非算法选择。

---

## 6. 成员变更

分布式系统经常需要增减节点，这是共识算法在工程中最棘手的部分之一。

**Paxos**：
- 论文没有涉及成员变更
- 各系统自行实现（如动态调整 Quorum 大小）
- 缺乏统一的标准方案

**Raft**：
- 论文专门讨论了成员变更
- 提出了**联合共识（Joint Consensus）**的两阶段方案
- 先切换到新旧配置共同生效的过渡状态，再完全切换到新配置
- 保证了变更过程中不会选出两个 Leader

Raft 在成员变更上的明确设计，是它工程友好性的又一个例证。

---

## 7. 谁在用

**Paxos 的著名实现：**
- **Google Chubby**：分布式锁服务，Google 内部大量依赖
- **Google Spanner**：全球分布式数据库
- **ZooKeeper（Zab）**：虽然 Zab 不是严格意义上的 Paxos，但思想相近
- **XtraDB Cluster / Galera**：MySQL 的高可用方案

**Raft 的著名实现：**
- **etcd**：Kubernetes 的核心存储，最知名的 Raft 实现
- **Consul**：HashiCorp 的服务发现和配置工具
- **TiKV**：TiDB 的分布式 KV 存储引擎
- **CockroachDB**：分布式 SQL 数据库
- **LogCabin、Braft** 等

一个有趣的趋势：**新系统更倾向于选择 Raft**。不是因为 Paxos 不够优秀，而是因为 Raft 降低了团队理解和维护共识模块的门槛。

---

## 8. 如何选择

| 场景 | 推荐 | 理由 |
|---|---|---|
| 需要从头实现共识模块 | **Raft** | 实现路径清晰，社区资源丰富 |
| 已有 Paxos 基础设施或团队有深厚 Paxos 经验 | **Paxos** | 无需重复造轮子 |
| 极端追求理论简洁性 | **Paxos** | 核心逻辑更精简，数学上更优雅 |
| 系统需要频繁变更集群成员 | **Raft** | 成员变更方案成熟且文档完善 |
| 教学或学习分布式共识 | **Raft** | 有可视化工具（raft.github.io），学习曲线平缓 |

---

## 9. 总结

Paxos 和 Raft 是同一枚硬币的两面：

- **Paxos** 是数学家写的算法。它告诉你"什么是对的"，但不告诉你"怎么做"。它的核心只有 Prepare 和 Accept 两个阶段，优雅到让人惊叹，却也抽象到让人困惑。Paxos 像是一个最小化的共识内核——正确、通用，但工程化时需要大量的外围设计和经验积累。

- **Raft** 是工程师写的算法。它从工程实践出发，用强 Leader、状态机复制、明确的角色定义，把分布式共识变成了一套可以按部就班实现的手册。Raft 牺牲了 Paxos 的某些灵活性（比如多 Leader 并发提案），换来了可理解性和可维护性。

两者的安全性保证是等价的——在大多数节点正常工作时，都能保证线性一致性。它们的差异不在"能不能做对"，而在"容不容易做对"。

> "There is only one consensus protocol, and it's called Paxos." —— Mike Burrows, Chubby 作者
>
> 这句话的另一面是：虽然理论上都是 Paxos，但工程上能跑通的，往往是那些"不像 Paxos 的 Paxos 实现"——比如 Raft。

如果你正在设计一个新的分布式系统，我的建议是：**从 Raft 开始**。当你真正深入理解了共识问题的本质后，再回头看 Paxos，会发现 Lamport 的简洁之美——但那时候，你可能已经不想换回去了。

---

## 参考

- [Paxos Made Simple](https://lamport.azurewebsites.net/pubs/paxos-simple.pdf) - Leslie Lamport
- [In Search of an Understandable Consensus Algorithm](https://raft.github.io/raft.pdf) - Diego Ongaro, John Ousterhout
- [Raft 共识算法（及 etcd/raft 源码解析）](https://arthurchiao.art/blog/raft-paper-zh/) - Arthur Chiao
- [Paxos vs Raft: Have we reached consensus on distributed consensus?](https://arxiv.org/abs/2004.05074) - Heidi Howard et al.
- [raft.github.io](https://raft.github.io/) - Raft 官方可视化教程
