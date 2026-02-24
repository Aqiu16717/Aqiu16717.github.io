---
title: MDL 从入门到入土
tags: MySQL, MDL
---
> aq1u@outlook.com

# MDL 从入门到入土
MDL的全称是Metadata Lock，即元数据锁。

## 直觉建立

* **常见误解**
    * 当提到MDL，我们的第一想法往往是它是一把元数据锁
        * 普通读写事务需要获取对应表的 MDL 读锁
        * DDL 操作需要获取对应表的 MDL 写锁
    * **我们习惯这么描述，然而这并不准确，修正这个第一直觉对于理解和使用MDL至关重要。**

* **直觉纠正**
    * MDL是一个锁系统，并不是一把锁。

既然是系统，我们就可以定义 input 和 output
* 视 MDL 系统为一个 black box
    * input：某个锁请求
    * output：某个锁票据

## 数据结构

* mdl的实现在mdl.h和mdl.cc中
* 如果你没有看过mdl的源码，可以按下列子章节顺序来看。我会先讲如何描述Input和Output所需的数据结构，再讲内部运作所需的其他数据结构。

### MDL_key

* 既然叫key，它是一个唯一标识符，用于表示一个数据库对象（如表、Schema 等）。通过三元组定义（namespace, db_name, name）：
    * namespace
    * db_name
    * table_name

向 MDL 系统输入一个锁请求时，需要提供一个 MDL_key 来标识要锁定的数据库对象。

db_name和table_name好理解，namespace是个什么东西？

作为C++开发工程师，很容义联想到C++中的namespace，它的作用是将全局命名空间分隔成多个逻辑上独立的部分，避免命名冲突。理解此处的mdl_namespace的核心也是**冲突**，不同namespace的锁请求是不会冲突的。

namespace 通过一个枚举类型来表示，很方便向后兼容，新增对象类型只需在末尾追加枚举值。
```c++
enum enum_mdl_namespace {
  GLOBAL = 0,
  BACKUP_LOCK,
  TABLESPACE,
  SCHEMA,
  TABLE,
  FUNCTION,
  PROCEDURE,
  TRIGGER,
  EVENT,
  COMMIT,
  USER_LEVEL_LOCK,
  LOCKING_SERVICE,
  SRID,
  ACL_CACHE,
  COLUMN_STATISTICS,
  RESOURCE_GROUPS,
  FOREIGN_KEY,
  CHECK_CONSTRAINT,
  /* This should be the last ! */
  NAMESPACE_END
};
```

### MDL_request

* 一个锁请求和一个已授予的元数据锁由不同的类表示，它们具有不同的分配位置，不同的生命周期。
* 锁请求的分配是从元数据锁 (MDL) 子系统外部控制的
* MDL_request 是 MDL 系统外部控制：请求 来自 MDL 系统外部，视 MDL 系统为一个 black box
* MDL_ticket 是 MDL 内部控制：授予 来自 MDL 系统内部


### MDL_lock
* 表示一个数据库对象（如表）的锁状态池
* 每个数据库对象（由 MDL_key 标识）对应一个 MDL_lock 实例，负责跟踪该对象上的所有锁请求（已授予或等待中）
* **Ticket_list**
* bitmap_t m_bitmap：表示这个链表中都有哪些 ticket（锁）类型。

### **MDL_map**
* 单例模式，全局唯一，所有的 mdl 锁存在在这里


### **MDL_context：每个事务 (THD/connection) 有一个 MDL_context.**
* acquire_locks
* 对锁请求排序


* acquire_lock
* MDL_ticket_store m_ticket_store
* Lists of all MDL tickets acquired by this connection


* **作为 THD 的成员**
* **bool MDL_context::try_acquire_lock_impl(MDL_request *mdl_request, MDL_ticket **out_ticket)**
* 内部函数
* 先查找上下文中是否已经有票据
* 已有票据的强度大于等于请求
* 直觉建立：自动周期的锁票据和手动周期的锁票据要分开




* **bool MDL_context::has_lock(const MDL_savepoint &mdl_savepoint, MDL_ticket *mdl_ticket)**
* 这个函数名称非常有误导性
* 新凭据在链表头部
* 从头开始遍历，遍历到链表尾部或者保存点中保存的票据
* 如果在链表中找到了目标票据，那么这个票据一定比保存点的票据新，该票据会随这个保存点网回滚被释放


* 如果遍历结束都没找到，说明票据要么比较旧，要么是显示获取的（不在链表中），该票据会随这个保存点的回滚被释放
* 用法：`is_new_ticket = !has_lock(mdl_svp, mdl_new_lock_request.ticket);`
* 不能直接用返回 true 来判断“新”




* **MDL_savepoint mdl_savepoint()**
* 每次调用都构建一个 savepoint，取的是链表中最薪的 ticket


* **bool MDL_context::upgrade_shared_lock()**
```cpp
/*
The below code can't handle situation when we upgrade to lock requiring
SE notification and it turns out that we already have lock of this type
associated with different ticket.
*/
assert(is_new_ticket || !mdl_new_lock_request.ticket->m_hton_notified);
// 1. mdl_new_lock_request.ticket 是新票据，不在乎有没有通知过存储引擎
// 2. mdl_new_lock_request.ticket 是旧票据，理应没有通知存储引擎

```


* **bool MDL_context::clone_ticket(MDL_request *mdl_request)**
* 根据 mdl_request 中的信息克隆出一个票据，克隆出的票据挂在同一个 MDL_lock 下
* 克隆操作成功完成后，新生成的克隆票据 (ticket) 会被赋值给 mdl_request->ticket
* 为什么需要克隆？
* HANDLER CLOSE 时不释放事务级票据；
* 事务 COMMIT 时不释放 HANDLER 持有的锁凭据；


### **MDL_ticket_store**
* 每个 MDL_context 实例内部包含一个 MDL_ticket_store
* MDL_context 负责锁的申请、释放及事务/语句级锁的生命周期管理。
* MDL_ticket_store 负责具体存储和快速访问 MDL_ticket，减少内存开销。
* 新凭据在链表头部，头插法



### **MDL_ticket**
* 已授予的锁（票证）的分配是在 MDL 子系统内部控制的
* 会话级别的锁实例，每个会话对同一对象的锁请求对应一个独立的 MDL_ticket，但共享同一个 MDL_lock
* 一个链接可以申请很多个 ticket
* m_hton_notified 是否已经通知存储引擎


### **MDL_lock_strategy**
* 定义在 MDL_lock 内部
* 锁策略根据 MDL_key 的 namespace 来进行分类
* 有两种策略，scope 和 object，分别使用 `MDL_lock::m_scoped_lock_strategy` 与 `MDL_lock::m_object_lock_strategy` 表示


* **MDL_lock::MDL_lock_strategy**
* **bitmap_t m_granted_incompatible[MDL_TYPE_END]**
* 类型：bitmap_t 是两个 Byte，一共 16bit，最高左移位数是 1<<15
* 数组大小：数组的大小为 11，数组下标代表了不同的锁类型
* 数组元素：（下标表示的锁）与哪种冲突
* 0：（下标表示的锁）与任何锁都不冲突
* 非 0
* MDL_BIT(MDL_EXCLUSIVE)：（下标表示的锁）与 X 锁冲突
* MDL_BIT(MDL_EXCLUSIVE) | MDL_BIT(MDL_SHARED_NO_READ_WRITE)：下标表示的锁与 X 锁、SNRW 冲突






* **m_waiting_incompatible 和 m_current_waiting_incompatible_idx**，一个二维数组，一个二维数组的第一维下标
* 二维数组：4 * 11


* **m_unobtrusive_lock_increment**
* 类型
* 数组大小：数组的大小为 11，数组下标代表了不同的锁类型
* 数组元素：表示增量


```cpp
{
  0,          // MDL_INTENTION_EXCLUSIVE (非侵入式，不参与快路径)
  1,          // MDL_SHARED (S) -> 0-19位，增量1 (1 << 0)
  1,          // MDL_SHARED_HIGH_PRIO (SH) -> 0-19位，增量1
  1ULL << 20, // MDL_SHARED_READ (SR) -> 20-39位，增量1 << 20
  1ULL << 40, // MDL_SHARED_WRITE (SW) -> 40-59位，增量1 << 40
  1ULL << 40, // MDL_SHARED_WRITE_LOW_PRIO (SWLP) -> 40-59位，增量1 << 40
  0, 0, 0, 0, 0 // 其他侵入式锁，增量0
}

```





---

### **等待与死锁检测**

* **piget 和 hog**
* 什么样的锁是 piget
* 什么样的锁是 hog：MDL_OBJECT_HOG_LOCK_TYPES
* 这些锁类型具有较高的优先级，可能会饿死低优先级的锁请求。
* 系统限制这些锁类型连续授予的次数，不超过 max_write_lock_count 次




* **MDL_lock::can_grant_lock**
* **非侵入式锁 unobtrusive lock**
* **MDL_savepoint**
* 生命周期，MDL_savepoint 有两个构造函数，一个是 public 的无参构建供用户使用，一个是 private 的有参构建供 MDL 系统内部使用
* 真正的构建只能在 MDL_context 内部进行，也就是只能在 MDL 系统内构建
* 用户可以从 MDL 系统内部获取一个 MDL_savepoint，用户临时保存
* 用户可以让 MDL 系统回滚到某个 MDL_savepoint


* 用法
```cpp
MDL_savepoint mdl_savepoint = thd->mdl_context.mdl_savepoint();
// ...
thd->mdl_context.rollback_to_savepoint(mdl_savepoint);

```




* **MDL_wait_for_subgraph**
* 死锁检测体系的核心抽象类
* 表示等待图中的边，一个锁等待关系
* 为死锁检测算法提供统一的接口
* 遍历等待图节点、计算死锁权重


* **MDL_wait_for_graph_visitor**
* 实现“访问者模式”


* **Deadlock_detection_visitor**
* 实现 MDL_wait_for_graph_visitor


* **MDL_wait**
* 封装锁等待的生命周期管理
* 线程挂起等待锁结果


* **死锁检测器会在不同的线程之间穿梭**
* **锁的类型**
* **p mdl_request->key.mdl_namespace()**
* **p mdl_request.type**

---

### **锁策略与锁类型**

* **PIN**
* LF_PINBOX：全局 / MDL 上下文级的 “PIN 管理中心”，统筹所有 PIN 资源的分配、释放和回调管理；
* LF_PINS：线程 / MDL 上下文中持有的 “PIN 实例集合”，每个实例管理一组固定的资源指针；


* **锁策略 MDL_lock_strategy**
* scope
* object


* **锁类型**
* **MDL_INTENTION_EXCLUSIVE**
* 只用于 scope
* 防止 schema 被删除
* 可进一步获取不同的 object 的可升级锁其他锁


* **MDL_SHARED**
* 只使用元数据
* 不使用数据


* **MDL_SHARED_HIGH_PRIO**
* 无视其他连接正在等待的排他锁请求


* **MDL_SHARED_READ**
* 读取元数据
* 读取数据
* 典型场景：select


* **MDL_SHARED_WRITE**
* 读表的元数据（表结构）
* 向表中写入数据
* 场景：insert


* **MDL_SHARED_UPGRADABLE**
* 读取表的元数据
* 读取表的数据
* 可升级：SNW, SNRW, X
* 场景：alter 的第一阶段


