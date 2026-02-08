---
title: MySQL元数据
date: 2026-02-01 23:30:00
tags:
  - MySQL
  - 元数据
  - 源码分析
categories:
  - 数据库
comments: true
---

## MySQL 元数据

> 本文基于 MySQL8.4 编写

MySQL的元数据可以从不同的层次去看，正如它的架构分为sql层（server层）层和innodb层（存储引擎层），元数据在不同层也使用了不同的抽象。
* MySQL元数据可以分三层来描述，sql层，dd层，innodb层。

* sql 层和 innodb 层好理解，而dd指的是 MySQL8.0引入的数据字典 dict dictionary，dd 会贯穿 sql 和 innodb，所以笔者为此单列一层。

> 笔者习惯称sql层而非server层，因为MySQL8.4源码有专门的sql目录，称之为sql层更符合直观感受.

## 什么是元数据？

我们都知道元数据是描述数据的数据，在此场景下其实应该更加具象一些。对于数据库来说，最直观的数据就是表。如何去描述这个表，描述表的数据就是元数据。这并不严谨，但建立直觉足以。