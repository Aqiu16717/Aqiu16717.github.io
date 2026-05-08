---
title: MySQL 源码剖析：TABLE 对象的生命周期
date: 2026-05-09 10:00:00
tags:
  - MySQL
  - InnoDB
  - 源码剖析
  - 数据库
categories:
  - 数据库
lang: zh-CN
---

在 MySQL Server 层，`TABLE` 结构体是 SQL 执行过程中最核心的数据结构之一。它既不是磁盘上的表定义，也不是存储引擎里的数据页，而是**Server 层对一个已打开表的运行时抽象**。

本文基于 MySQL 8.0.25 源码，梳理 `TABLE` 对象从创建到销毁的完整生命周期。涉及的源码文件主要集中在 `sql/table.h`、`sql/table.cc` 和 `sql/sql_base.cc`。

<!-- more -->

## 1. TABLE 与 TABLE_SHARE：实例与模板

理解 `TABLE` 的生命周期，首先要分清两个核心结构：

| 结构体 | 语义 | 数量 | 生命周期 |
|---|---|---|---|
| **`TABLE_SHARE`** | 表的**定义模板**（列、索引、默认值等） | 全局唯一（每表一个） | 常驻 TDC，DDL 时失效 |
| **`TABLE`** | 表的**打开实例**（含运行时状态、行缓冲、存储引擎句柄） | 每线程每表可有一个 | 语句级或连接级 |

`TABLE_SHARE` 相当于类的静态定义，`TABLE` 相当于运行时 new 出来的对象。多个线程可以同时打开同一张表，各自持有独立的 `TABLE`，但共享同一个 `TABLE_SHARE`。

```cpp
// sql/table.h:1389
struct TABLE {
  TABLE_SHARE *s{nullptr};        // 指向共享定义
  handler *file{nullptr};         // 存储引擎句柄（如 ha_innodb）
  THD *in_use{nullptr};           // 当前使用这个 TABLE 的线程
  TABLE *next{nullptr}, *prev{nullptr};  // 链接在 thd->open_tables 链表中

  uchar *record[2]{nullptr, nullptr};    // 行缓冲：record[0] 当前行，record[1] 更新前镜像
  Field **field{nullptr};         // 字段数组（从 TABLE_SHARE clone 后调整偏移）
  // ...
};
```

`TABLE_SHARE` 里放的是"元信息"（有哪些列、什么类型、有哪些索引），`TABLE` 里放的是"运行时态"（当前读到了哪一行、哪些列被置了 NULL、存储引擎句柄指向哪个 ibd 文件）。

---

## 2. 两级缓存架构

MySQL 用**两级缓存**来管理 TABLE 对象，避免每次查询都从头分配：

```
+-------------------------------------------------------------+
|  Level 1: Table_cache (TABLE instance cache)                |
|  - Hash-partitioned by thread_id (max 16 partitions)        |
|  - Each partition has used_tables / free_tables lists       |
|  - Purpose: reuse TABLE objects across statements           |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|  Level 2: table_def_cache (TABLE_SHARE definition cache)    |
|  - Global hash map, protected by LOCK_open                  |
|  - Purpose: avoid reading DD metadata on every open         |
+-------------------------------------------------------------+
```

### 2.1 Table_cache 的分区设计

```cpp
// sql/table_cache.h:67
class Table_cache {
  mysql_mutex_t m_lock;                          // 保护本分区的 mutex
  Table_cache_hash m_cache;                      // hash<key, Table_cache_element*>
  TABLE *m_unused_tables{nullptr};               // 所有未被使用的 TABLE 的 LRU 链表
  uint m_table_count{0};                         // 本分区中 TABLE 总数
};

// sql/table_cache.h:228
class Table_cache_element {
  I_P_List<TABLE, ...> used_tables;              // 正在使用的 TABLE
  I_P_List<TABLE, ...> free_tables;              // 空闲可复用的 TABLE
  TABLE_SHARE *share{nullptr};                   // 指向 TABLE_SHARE
};
```

每个连接根据 `thd->thread_id % table_cache_instances` 选择自己的 partition。这样大多数查询只需锁本 partition 的 mutex，避免全局 `LOCK_open` 成为瓶颈。

### 2.2 TABLE_SHARE 的引用计数

`TABLE_SHARE` 内部维护 `m_ref_count`，记录当前有多少个 `TABLE` 实例正在引用它。只有当 `ref_count` 降到 0 且版本过期时，`TABLE_SHARE` 才会被移出 `table_def_cache` 并销毁。

---

## 3. 生命周期四阶段

以一条最简单的查询为例，看 `TABLE` 对象走过了哪些函数：

```sql
SELECT * FROM users WHERE id = 1;
```

### Phase 1: 打开表（open_table）

执行器在真正读取数据前，必须先拿到 `TABLE` 对象。入口在 `sql/sql_base.cc:2784`：

```cpp
bool open_table(THD *thd, TABLE_LIST *table_list, Open_table_context *ot_ctx)
```

**打开流程：**

1. **计算 cache key**：`"db_name\0table_name\0"`，用于在 Table_cache 中查找。

2. **获取 MDL 锁**：对表名加 Metadata Lock（如 SR 或 SW）。如果别的会话持有冲突的 MDL，这里会阻塞等待。

3. **查 Table_cache**：
   ```cpp
   Table_cache *tc = table_cache_manager.get_cache(thd);
   tc->get_table(thd, key, key_length, &share);  // sql/table_cache.h:444
   ```
   - **Cache hit**：`free_tables` 链表中取出一个空闲 `TABLE`，移到 `used_tables`，设置 `in_use = thd`，直接返回。
   - **Cache miss，但 TABLE_SHARE 存在**：`share != nullptr`，需要新建 `TABLE`。
   - **Cache miss，且 TABLE_SHARE 也不存在**：`share == nullptr`，需要先从 Data Dictionary 加载。

4. **加载 TABLE_SHARE**（如果需要）：
   ```cpp
   get_table_share_with_discover()  // sql/sql_base.cc:872
     -> get_table_share()           // sql/sql_base.cc:660
       -> alloc_table_share()       // sql/table.cc:364
   ```
   `alloc_table_share()` 在独立的 `MEM_ROOT` 上分配 `TABLE_SHARE`，然后触发 Data Dictionary 读取表的列、索引、分区等信息填充进去。

5. **构建 TABLE 实例**：
   ```cpp
   open_table_from_share(thd, share, alias, ...)  // sql/table.cc:2874
   ```
   这是最关键的一步：
   - 分配 `TABLE` 结构体内存
   - `get_new_handler()` 创建存储引擎句柄（如 `ha_innodb`）
   - 分配 `record[0]`、`record[1]` 行缓冲
   - **Clone Field 对象**：从 `TABLE_SHARE` 复制字段定义，但把字段内部的指针偏移调整到新 `TABLE` 的 `record[0]` 上
   - 分配 `read_set` / `write_set` 位图
   - 调用 `handler::ha_open()` 让存储引擎真正打开这个表（InnoDB 层会加载 ibd 文件、初始化 B+ 树游标等）

6. **挂入 THD 的打开表链表**：
   ```cpp
   table->next = thd->open_tables;
   thd->set_open_tables(table);
   ```
   一个连接在同一时刻可能打开多张表，`thd->open_tables` 是一个单向链表，保存着本连接所有活跃的 `TABLE`。

### Phase 2: 执行查询

`TABLE` 构建完成后，执行器通过 `table->file`（即 `handler *`）与存储引擎交互：

```cpp
// 初始化全表扫描
table->file->ha_rnd_init(true);

// 读取下一行
table->file->ha_rnd_next(table->record[0]);

// 根据 read_set 判断哪些列被需要，进行投影、过滤
```

这个阶段 `TABLE` 的所有运行时状态都在被读写：`record[0]` 存放当前行，`read_set` 标记了查询需要的列，存储引擎的游标位置在 `file` 内部维护。

### Phase 3: 语句结束，关闭表（close_thread_tables）

语句执行完毕，并不直接 `free` 掉 `TABLE`。入口在 `sql/sql_base.cc:1530`：

```cpp
void close_thread_tables(THD *thd)
```

**关闭流程：**

1. **释放行锁**：调用 `mysql_unlock_tables()`，通知存储引擎释放 InnoDB 行锁。

2. **遍历 thd->open_tables 链表**，对每个 `TABLE` 调用 `close_thread_table()`：`sql/sql_base.cc:1710`

3. **重置存储引擎状态**：
   ```cpp
   table->file->ha_extra(HA_EXTRA_DETACH_CHILDREN);  // 解绑 MERGE 子表
   table->file->ha_reset();                          // 重置 handler 状态
   ```

4. **决定：放回缓存，还是直接销毁？** `release_or_close_table()`：`sql/sql_base.cc:1691`
   - **如果 TABLE_SHARE 版本已过期**（有人做了 DDL）、或表被标记为 invalid、或服务器正在关闭：
     ```cpp
     tc->remove_table(table);   // 从 Table_cache 中摘除
     intern_close_table(table); // 真正销毁
     ```
   - **否则**：
     ```cpp
     tc->release_table(thd, table);  // sql/table_cache.h:495
     ```
     把 `TABLE` 从 `used_tables` 移到 `free_tables`，并挂到 `m_unused_tables` LRU 链表尾部，设置 `in_use = nullptr`。

**关键点**：语句结束后，`TABLE` 对象绝大多数情况下是**活着回到缓存池**，而不是被释放。这是为了下一条查询能直接复用，省去 `open_table_from_share()` 的分配开销。

### Phase 4: 什么时候真正销毁？

`TABLE` 对象的内存被回收，通常发生在以下几种场景：

| 场景 | 触发函数 | 路径 |
|---|---|---|
| **Table_cache LRU 淘汰** | `Table_cache::free_unused_tables_if_necessary()` | 当本 partition 的 `TABLE` 总数超过 `table_cache_size / table_cache_instances`，淘汰最老的 unused TABLE |
| **DDL / FLUSH TABLES** | `tdc_remove_table()` | `sql/sql_base.cc:10112`。标记 `TABLE_SHARE` 版本过期，销毁该表在所有 partition 中的 unused TABLE |
| **连接断开** | `close_thread_table()` | 本连接持有的 TABLE 归还缓存；如果同时触发缓存淘汰，则销毁 |
| **Server 关闭** | `close_cached_tables()` | 遍历所有 unused TABLE 和 TABLE_SHARE，全部销毁 |

真正执行销毁的是 `intern_close_table()`：`sql/sql_base.cc:1096`

```cpp
void intern_close_table(TABLE *table) {
  free_io_cache(table);              // 释放 IO 缓存（如 MRR buffer）
  destroy(table->triggers);          // 销毁触发器对象
  if (table->file) {
    closefrm(table, true);           // 关闭存储引擎句柄（调用 ha_close）
  }
  destroy(table);                    // 调用 TABLE 析构函数
  my_free(table);                    // 释放 TABLE 结构体内存
}
```

`TABLE_SHARE` 的销毁由 `release_table_share()` 触发：`sql/sql_base.cc:960`。当 `ref_count` 降到 0：

```cpp
void release_table_share(TABLE_SHARE *share) {
  if (--share->m_ref_count == 0) {
    if (share->has_old_version() || shutdown_in_progress) {
      // 从 table_def_cache 中彻底移除并销毁
      table_def_cache.erase(key);
      share->destroy();  // sql/table.cc:530
    } else {
      // 挂到 unused share 的 LRU 链表，等待复用
      link_into_unused_shares(share);
    }
  }
}
```

`TABLE_SHARE::destroy()` 会释放 `MEM_ROOT`、卸载插件、释放直方图统计等所有与表定义相关的资源。

---

## 4. 临时表的特殊路径

临时表不走 Table_cache，也不进 `table_def_cache`。它的生命周期更简单：

- 打开：`open_temporary_table()` 直接分配 `TABLE` 和 `TABLE_SHARE`
- 关闭：`close_temporary_tables()` → 直接 `intern_close_table()` 销毁，**不缓存**
- 断开连接时：自动清理本连接所有临时表

临时表的 `TABLE_SHARE` 不会共享给其他线程，因此不需要引用计数和全局缓存。

---

## 5. FLUSH TABLES 做了什么

`FLUSH TABLES` 是 DBA 常用的维护命令，它的核心动作在 `close_cached_tables()`：`sql/sql_base.cc:1140`

```cpp
bool close_cached_tables(THD *thd, TABLE_LIST *tables, ...)
```

- **无参数**（`FLUSH TABLES`）：
  1. 递增全局 `refresh_version`
  2. 遍历所有 `Table_cache` partition，释放所有 `unused` 的 `TABLE`
  3. 释放所有 `unused` 的 `TABLE_SHARE`

- **带表名**（`FLUSH TABLES t1, t2`）：
  1. 调用 `tdc_remove_table()` 把这些表的 `TABLE_SHARE` 标记为过期
  2. 强制销毁这些表在所有 cache partition 中的 `unused TABLE`
  3. 如果 `ref_count == 0`，把 `TABLE_SHARE` 也从 `table_def_cache` 中删除

这也是为什么 `FLUSH TABLES` 能"清缓存"，而正在执行的查询不受影响——只有 `unused` 的对象会被清掉，正在使用的 `TABLE` 等连接自己 `close_thread_tables()` 时才会发现 share 已过期，然后走销毁路径。

---

## 6. 总结

`TABLE` 对象的生命周期可以概括为一句话：

> **从 Table_cache 中来，到 Table_cache 中去；只有在版本过期或 LRU 淘汰时，才真正销毁。**

完整流程图：

```
                    SELECT * FROM users
                           |
                           v
                       open_table()
                           |
                   +-------+-------+
                   |               |
             Cache Hit         Cache Miss
                   |               |
                   v               v
        get from free_tables   open_table_from_share()
                   |               |
                   |               |
                   +<--------------+
                   |
                   v
            add to used_tables
                   |
                   v
             execute query
                   |
                   v
            close_thread_tables()
                   |
                   v
          release_or_close_table()
                   |
           +-------+-------+
           |               |
           v               v
     share valid      share stale
           |               |
           v               v
    release_table()  intern_close_table()
           |               |
           v               v
         reuse          destroy
```

理解这个生命周期，对排查很多问题都有帮助：

- **Too many open tables**：`table_cache_size` 太小，或连接数太多导致 `TABLE` 对象过多
- **Table cache miss 高**：频繁 `FLUSH TABLES` 或 DDL 导致 cache 失效
- **连接断开慢**：`thd->open_tables` 链表太长，close_thread_tables() 需要逐个清理
- **内存泄漏怀疑**：确认是 `TABLE` 对象没释放，还是 `TABLE_SHARE` 的 `ref_count` 没归零

---

## 参考

- MySQL 8.0.25 `sql/table.h` — `TABLE` (L1389) 与 `TABLE_SHARE` (L687) 定义
- MySQL 8.0.25 `sql/table.cc` — `alloc_table_share()` (L364), `open_table_from_share()` (L2874), `TABLE_SHARE::destroy()` (L530)
- MySQL 8.0.25 `sql/sql_base.cc` — `open_table()` (L2784), `close_thread_tables()` (L1530), `close_thread_table()` (L1710), `intern_close_table()` (L1096), `tdc_remove_table()` (L10112)
- MySQL 8.0.25 `sql/table_cache.h` — `Table_cache` (L67), `Table_cache_element` (L228), `get_table()` (L444), `release_table()` (L495)
- [MySQL 8.0 Reference Manual / Table Open Cache](https://dev.mysql.com/doc/refman/8.0/en/table-cache.html)
