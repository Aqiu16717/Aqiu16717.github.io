---
layout: d
title: MySQL DDL Log 剖析
date: 2025-10-14 22:30:37
tags: MySQL DDL
---
MySQL 中的 DDL Log 用于保证 DDL 的原子性。本文介绍它的概念和相关源码。

## 简介
* mysql.innodb_ddl_log是一个内部系统表
  * innobase_ddse_dict_init()可以看到表的创建过程


* DDL的执行分以下几个阶段：
  1. prepare
  2. execute
  3. commit
  4. post_ddl

## show me the code
> 代码分支: mysql-9.3.0
* DDL log 的核心类是 class Log_DDL
* 核心源文件：storage/innobase/include/log0ddl.h, storage/innobase/log/log0ddl.cc
* class DDL_Log_Table: 封装了对mysql.innodb_ddl_log的操作