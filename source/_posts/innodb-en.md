---
title: InnoDB B-tree (B+ tree) Locking Strategy
date: 2025-11-12 22:35:51
tags: [innodb, B tree, B+ tree, mysql, database]
lang: en
permalink: /en/2025/11/12/innodb/index.html
---

The locks here are divided into two levels: the tree-level lock called **tree latch**, and the node-level lock called **node latch**. The tree latch protects all non-leaf nodes, while the node latch naturally protects the node itself.

## Why Tree Latch Only Protects Non-Leaf Nodes?

In a B+ tree, leaf nodes store actual data and have high access frequency. If the tree latch included leaf nodes in its protection scope, it would be more prone to trigger lock contention and reduce concurrency performance. From the perspective of non-leaf nodes, in a B+ tree, non-leaf nodes store pointers to child nodes. Protecting non-leaf nodes essentially means protecting the tree structure.

## Lock Acquisition Process

When operating on a B-tree, you typically first acquire the tree latch in shared mode (tree-latch-s), which ensures the tree structure won't be modified. Then you traverse the tree from top to bottom to find the target leaf node and lock it (node-latch). During the process of finding the leaf node, non-leaf nodes are not locked, which saves CPU time—you only need to ensure the corresponding data pages won't be swapped out of memory (buffer fixed).

## Tree Structure Modifications

If an operation changes the tree structure, you must first acquire an exclusive lock on the tree (tree-latch-x). Taking node splitting as an example:

1. First, find the leaf node to be split
2. Allocate a new data page
3. Insert a pointer to the new page into the upper-level non-leaf node
4. Release the tree-latch-x (because the tree structure change is complete)
5. Migrate some data from the original leaf node to the newly split leaf node

This approach minimizes the duration of exclusive locks on the tree structure, thereby improving concurrency performance.

## Reference

- MySQL InnoDB Source Code
- "Database Internals" by Alex Petrov
