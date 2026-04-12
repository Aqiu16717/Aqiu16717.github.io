---
title: 现代CPP
date: 2026-03-19 14:48:45
tags:
  - C++
  - CPP
---

## std::span

C++20 引入了 std::span

std::span 是一个轻量级对象，通常只包含一个指针和一个长度，通常总共 16 字节（64-bit-machine)

它本身不持有数据的所有权，只是指向一段已经存在的连续内存，类似指针，没有所有权

std::span 最核心、最经典的使用场景是作为函数参数类型

像在 C 语言中传递 `struct { T* ptr; size_t len; }`

- `std::span<T>` 类似 `T*`
- `std::span<const T>` 类似 `const T* ptr`
- 只有 `std::span<const T>` 才能接纳 const 容器

## std::optional
std::optional<T> 是 C++17 引入的一个类型安全的容器，它要么包含一个 T 类型的值，要么为空（std::nullopt）。它在栈上分配内存，不需要动态内存分配
std::optional<T> 的大小大于 T.它需要 1 个字节存储 bool 标志位，但由于 内存对齐（Alignment），编译器通常会填充更多的字节。
个人不建议使用。
