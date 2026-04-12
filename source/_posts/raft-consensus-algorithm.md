---
title: Raft 共识算法详解
date: 2025-03-28 02:25:00
tags:
  - Raft
  - 共识算法
  - 分布式一致性
  - 分布式系统
categories:
  - 分布式系统
lang: zh-CN
---

Raft 是一种用于管理复制日志的共识算法（consensus algorithm）。本文详细解析 Raft 算法的核心概念与实现机制。

## 1. 摘要

Raft 是一种用于管理复制日志的共识算法。

## 2. 复制状态机

![复制状态机架构](/images/posts/raft/figure1.png)

> 共识算法通常出现在复制状态机的背景下。保持复制日志的一致性是共识算法的职责。

**架构分层：**

- **客户端（Client）**：指令发起方，不直接与状态机交互，而是统一发给集群的共识模块；客户端无需感知集群内部的状况，只需向集群发起请求，最终得到一个一致的响应结果。

- **共识模块（Consensus Module）**：部署在集群的每一个服务器节点上，相互之间通信协作；接受客户端的指令，将其转发给本地的复制日志；与其他节点的共识模块协商，保证所有节点的复制日志中，都按相同的顺序存储了相同的客户端指令。

- **复制日志（Replicated Log）**：部署在每个服务器节点上，存储的内容是客户端发给状态机的指令；所有节点的复制日志完全一致；是状态机的指令来源，是连接共识模块和状态机的”桥梁”。

- **状态机（State Machine）**：指令执行方，部署在每个服务器节点上；是一个确定性的模块，给定相同的初始状态 + 相同的指令序列，必然输出相同的结果、更新为相同的最终状态。

**常见疑问：**

- **为什么要通过复制日志中转，而不是共识模块直接给状态机发指令？**

**解耦**：将”指令的共识统一”和”指令的实际执行”拆分开，各司其职，降低架构复杂度；

- **容错**：复制日志是持久化存储的，即便节点故障重启，也能从日志中恢复未执行的指令；

- **可追溯**：日志保留了所有客户端的指令记录，方便问题排查、系统回滚。

- **为什么这个架构能保证所有节点的状态机输出一致？**

状态机的确定性：相同初始状态 + 相同指令序列，必然得到相同结果；

- 复制日志的一致性：所有节点的日志内容、指令顺序完全相同。

- **为什么由状态机返回结果给客户端？**

共识模块不知道指令是什么意思，也不会执行指令；

- 状态机理解业务含义，执行指令并产生结果。

**故障模型：**

- **非拜占庭故障（Non Byzantine）**：节点只会挂掉、不说话、延迟，但不会撒谎、不会造假。

- **拜占庭故障（Byzantine）**：节点会故意撒谎、伪造消息、合谋叛变、乱发信息。

Raft 假设系统只存在非拜占庭故障。

## 3. Paxos 的问题

- **难以理解**：Paxos 算法逻辑复杂，描述晦涩。

- **难以实现**：工程实现难度大。

**核心区别：**

- **Paxos 基于单决议**：无顺序、孤立、只决定一件事。大家只投一次票，决定一件事，结束。

- **Raft 基于多决议**：有顺序、连续、决定一整条日志。大家一起按完全相同的顺序，做完一整个任务清单，不断加任务。

## 4. 可理解性设计

Raft 通过两种方式提升可理解性：

- **问题分解（Decomposition）**

领导者选举（Leader Election）

- 日志复制（Log Replication）

- 安全性（Safety）

- 成员变更（Membership Changes）

- **简化状态空间**：减少要考虑的状态数量。

## 5. Raft 共识算法

Raft 基于**强 Leader** 设计。Leader 做三件事：

- 从客户端接收日志条目

- 把日志复制到其他服务器

- 告诉其他服务器：什么时候可以安全地把日志应用到状态机

Leader 故障则自动重新选举。

**三个子问题：**

- **选主（Leader Election）**：旧 Leader 挂了自动选新 Leader

- **日志复制（Log Replication）**：Leader 收请求 → 生成日志 → 复制给所有节点 → 保证全集群日志完全相同

- **安全性（Safety）**：核心是状态机安全——只要有一个节点提交执行了某条日志，所有节点在同一个日志位置，都必须是同一条日志。

![Raft 算法总览](/images/posts/raft/figure2.png)

### 5.1 节点状态

**持久化状态（Persistent State）**：

- `currentTerm`：节点见过的最新任期号，单调递增

- `votedFor`：当前任期内投给了哪个候选人

- `log[]`：日志条目集合

**易失性状态（Volatile State）**：

- `commitIndex`：已确认提交的日志条目中，下标最大的那个值

- `lastApplied`：已应用到状态机的日志条目中，下标最大的那个值

**Leader 特有状态**：

- `nextIndex[]`：每个 Follower 下一次发送位置

- `matchIndex[]`：记录日志复制进度

### 5.2 领导者选举

通过**心跳机制**触发选举。

**选举流程：**

- 服务器起始状态是 Follower

- Leader 周期性发送心跳给 Follower 来维持权限

- 如果 Follower 在 `election timeout` 时间内未收到心跳，则开启新一轮选举

- Candidate 增加 `currentTerm`，给自己投票，向其他服务器发送 `RequestVote` RPC

- 获得多数投票的 Candidate 成为 Leader

**解决分裂投票：**让 Election Timer 的超时时间随机化，每个服务器的超时值不同。假设心跳间隔 100ms，选举超时下限可设置为 300ms。

### 5.3 日志复制

![日志结构](/images/posts/raft/figure6.png)

**日志格式：**

- 每个 log entry 存储一个 state machine command 和 term number

- 每个 log entry 有一个 integer index 用于标识它在 log 中的位置

**提交流程：**

- Leader 将命令追加到自己的日志中

- Leader 并发向其他服务器发送 `AppendEntries` RPC 复制日志

- 当日志在大多数节点复制成功后，Leader 将其标记为 `committed`

- Leader 将 committed 日志应用到状态机，并返回结果给客户端

**日志不一致处理：**

Leader 通过强制 Follower 复制自己的 Log 来保证一致性。Leader 为每个 Follower 维护一个 `nextIndex`，表示要发送的下一个日志索引。

![日志不一致情形](/images/posts/raft/figure7.png)

当 Follower 日志与 Leader 不一致时，Leader 会递减 `nextIndex` 并重试，直到找到一致的点，然后删除 Follower 该点之后的日志，发送 Leader 的日志。

### 5.4 安全性

![安全论证图](/images/posts/raft/figure3.png)

**五大核心安全属性：**

- **Election Safety**：一个任期最多只会有一个 Leader 当选

- **Leader Append-Only**：Leader 永远不会覆盖或删除日志条目

- **Log Matching**：如果两个日志的某个条目有相同的下标和任期，那么该条目前的日志完全相同

- **Leader Completeness**：如果一个日志条目在某个任期内被提交，该条目在高任期的 Leader 日志中也必然存在

- **State Machine Safety**：如果节点在给定的下标提交了日志条目，其他节点无法在同一个下标上提交不同的日志条目

**选举限制：**Raft 通过投票过程防止日志不够新的 Candidate 赢得选举。投票者会比较 Candidate 的日志是否至少和自己一样新（先比较 term，再比较 index）。

**旧任期日志提交问题：**

![旧任期日志提交问题](/images/posts/raft/figure8.png)

关键点：

- **旧任期日志**：即使复制到多数节点，也不能提交，因为可能被后来的 Leader 覆盖

- **当前任期日志**：只要复制到多数节点，就可以安全提交

- 一旦当前任期日志提交，它前面所有旧日志自动提交

## 6. 成员变更

![配置变更问题](/images/posts/raft/figure10.png)

直接从一种配置切换到另一种配置是不安全的，因为不同的服务器会在不同的时间进行切换，可能导致同时选出两个 Leader。

**解决方案：联合共识（Joint Consensus）**

![配置变更过程](/images/posts/raft/figure11.png)

采用两阶段方法：

- 先切换到 Cold,new 联合配置

- 再切换到 Cnew 新配置

## 7. 日志压缩

![快照替换日志](/images/posts/raft/figure12.png)

当日志增长过长时，使用快照（Snapshot）替换已提交的日志条目。快照只存储当前状态。

![InstallSnapshot RPC](/images/posts/raft/figure13.png)

通过 `InstallSnapshot` RPC 将快照分块传输给 Follower。

## 8. 客户端交互

**找到 Leader：**

- 客户端初次启动时随机连接一台服务器

- 如果连接的不是 Leader，服务器会告知当前 Leader 信息

- 如果 Leader 崩溃，客户端请求超时后重新随机选择服务器

**线性一致性：**

- 客户端为每条命令分配唯一序列号

- 状态机为每个客户端记录最近处理的序列号及响应结果

- 如果收到重复序列号的命令，直接返回缓存结果而不重新执行

**只读操作：**Leader 必须在响应只读请求前：

- 提交一条当前任期的 no-op 条目

- 与集群大多数节点交换心跳，确认自己仍是 Leader

## 参考

- [Raft 论文](https://raft.github.io/raft.pdf) - In Search of an Understandable Consensus Algorithm

- [Raft 官网](https://raft.github.io/)

- [化繁为简，聊一聊复制状态机系统架构抽象](https://xie.infoq.cn/article/52a2d33f5757cea4713f47793)

- [Raft 共识算法（及 etcd&#x2F;raft 源码解析）](https://arthurchiao.art/blog/raft-paper-zh/)
