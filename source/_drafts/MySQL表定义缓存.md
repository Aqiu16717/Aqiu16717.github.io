---
layout: d
title: MySQL表定义缓存
date: 2025-10-15 12:38:12
tags:
---

MySQL的表定义缓存系统采用两级缓存架构，第一层是session级别的表定义缓存struct TABLE，第二层是全局共享的表定义缓存struct TABLE_SHARE。

一个表对应一个TABLE_SHARE，当一个表首次被访问时为其创建和缓存一个TABLE_SHARE对象，TABLE_SHARE的内容最初从数据字典中读取。

要获取表的TABLE_SHARE，需要调用 get_table_share() 函数。
