---
title: Understanding Snapshot Isolation Level
tags:
  - database
  - transaction
  - isolation level
  - MVCC
  - concurrency control
categories:
  - database
comments: true
date: 2026-02-09 23:30:00
lang: en
permalink: /en/2026/02/09/snapshot-isolation/index.html
---

# Snapshot Isolation

**Snapshot Isolation** is a transaction isolation level used by databases for concurrency control. It allows transactions to work with a consistent snapshot of the database, providing a balance between consistency and concurrency.

## Implementation

Snapshot isolation is implemented through **MVCC** (Multi-Version Concurrency Control).

### What is MVCC?

MVCC stands for Multi-Version Concurrency Control. It maintains multiple versions of data items to allow readers to access data without blocking writers, and vice versa.

## Read Operations

- **Snapshot Read**: Does not use locking mechanisms. Reads are based on a snapshot of the database at the time the transaction started.

## Write Operations

### Read-Write Conflicts

Read and write operations do not conflict with each other. Read operations are based on the snapshot at the start of the transaction and will not block write operations.

### Write-Write Conflicts

Only one transaction can commit successfully; the other transaction will be rolled back. Conflict detection is performed at commit time to check if other concurrent transactions have modified the same data.

### Concurrency Control Methods

**Optimistic Concurrency Control**
- Conflict detection is performed at commit time
- If a conflict is detected, the transaction is rolled back and retried
- The write-write conflict control in snapshot isolation belongs to this category

**Pessimistic Concurrency Control**
- Write operations first acquire locks on resources, then perform operations
- Lock waiting issues exist, requiring timeout handling
- Deadlock issues exist, requiring deadlock detection

## Known Issues

### Phantom Read

A transaction re-executes a query returning a set of rows that satisfy a search condition and finds that the set has changed due to another recently-committed transaction.

### Write Skew

Two concurrent transactions read the same data, modify disjoint sets of data, and both commit successfully, violating a constraint that should have been maintained.

## Two-Phase Locking (2PL)

2PL is a pessimistic concurrency control method that guarantees conflict serializability. Lock acquisition and release are divided into two phases:

### Expanding Phase
- Transactions can acquire locks but cannot release them

### Shrinking Phase  
- Transactions can release locks but cannot acquire new ones
- Once a transaction starts releasing locks, it enters the shrinking phase and cannot acquire any more locks

### Lock Types

**Shared Lock (S Lock / Read Lock)**
- Allows multiple transactions to read data simultaneously without writing
- When a data item is locked in shared mode, other transactions can also request shared locks but cannot request exclusive locks

**Exclusive Lock (X Lock / Write Lock)**
- Allows a transaction to read and write data
- When a data item is locked in exclusive mode, other transactions cannot request any type of lock

## Comparison with Other Isolation Levels

| Isolation Level | Dirty Read | Non-Repeatable Read | Phantom Read |
|----------------|------------|---------------------|--------------|
| Read Uncommitted | Possible | Possible | Possible |
| Read Committed | Not Possible | Possible | Possible |
| Repeatable Read | Not Possible | Not Possible | Possible |
| Snapshot Isolation | Not Possible | Not Possible | Possible |
| Serializable | Not Possible | Not Possible | Not Possible |

## References

- [TiDB Transaction Isolation Levels](https://docs.pingcap.com/zh/tidb/stable/transaction-isolation-levels)
- [TiDB Pessimistic Transaction](https://docs.pingcap.com/zh/tidb/stable/pessimistic-transaction)
- "Designing Data-Intensive Applications" by Martin Kleppmann
