---
title: InnoDB中B-tree(B+ tree)的加锁策略
date: 2025-11-12 22:35:51
tags: innodb, B tree, B+ tree
---

此处的锁分两个级别，树级别的锁tree latch，和节点级别的锁node latch. tree latch 会保护所有的非叶子节点(non-leaf nodes)，node latch 自然是保护节点本身。

为什么tree-latch只保护non-leaf nodes？因为B+ tree中叶子节点(leaf nodes)会存储数据，访问频率高，tree-latch保护范围若包括leaf-nodes会更容易出发锁竞争，降低并发性能。从non-leaf nodes的角度讲，在B+ tree中non-leaf nodes 存储的是指向子节点的指针，保护non-leaf nodes就是保护树结构。

操作B tree时通常先获取 tree-latch-s，也就是树级别的s锁，这可以保证树的结构不被修改，然后自顶向下遍历树，找到要操作的叶子节点，对叶子节点加锁(node-latch)。在查找叶子节点的过程中，不会对非叶子节点加锁，这可以节省CPU时间，只需要保证响应的数据页不会被换出内存(bufferfixed)。


如果操作会改变树结构，那就要先对树加x锁(tree-latch-x)，以节点分裂为例，首先找到要分裂的叶子节点，分配一个新数据页，向上层非叶子节点插入指向新页面的指针，之后就可以释放tree-latch-x（因为树结构变更已经完成），迁移部分数据从原叶子节点到新分裂出的叶子节点。