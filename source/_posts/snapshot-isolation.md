---
title: 快照隔离级别（Snapshot Isolation）详解
tags:
  - 数据库
  - 事务
  - 隔离级别
  - MVCC
categories:
  - 数据库
comments: true
date: 2026-02-09 23:30:00
---


# snapshot isolation

snapshot isolation 即快照隔离级别，是数据库用于并发控制的一种隔离级别。

## 实现

* snapshot isolation 通过mvcc实现

## mvcc

* mvcc指多版本并发控制（multi-version concurrency control）

## 读操作

* 快照读：不使用锁机制，基于事务开始时刻的快照进行读取 

## 写操作

* 读-写冲突：读写之间不会发生冲突，读操作基于事务开始时的快照，不会阻塞写操作
* 写-写冲突：只有一个事务能提交成功，另外一个事务会回滚。
  * 写入时需要进行冲突检测：在提交时检查是否有其他并发事务修改了相同的数据

* 乐观并发控制
  * 提交时进行冲突检测，如果有冲突就回滚，然后重试
  * 快照隔离级别中的写写冲突控制属于这个范畴
* 悲观并发控制
  * 写操作先对资源加锁，然后再进行操作
  * 存在锁等待问题，需要处理锁超时。存在死锁问题，需要进行死锁检测

## 存在的问题

* 幻读
* 写偏斜

## 2pl (2-phase locking)

* 2pl是一种悲观并发控制方法，保证冲突序列化性
* 锁的应用和删除分两个阶段
  * 扩展阶段：事务可以获取锁，但不能释放锁
  * 收缩阶段：事务可以释放锁，但不能获取锁。一旦事务开始释放锁就进入了收缩阶段，就不能再获取锁
* 基本协议使用两种锁类型：共享锁和排他锁
  * 共享锁/读锁
    * 允许多个事务同时读取数据而不进行写入
    * 当一个数据项被共享锁定时，其他事务也可以申请共享锁，但不能申请排他锁
  * 排他锁/写锁
    * 允许事务对数据进行读取和写入
    * 当一个数据项被排他锁定时，其他事务不能申请任何类型的锁

## 参考
* https://docs.pingcap.com/zh/tidb/stable/transaction-isolation-levels
* https://docs.pingcap.com/zh/tidb/stable/pessimistic-transaction
