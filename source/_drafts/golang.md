---
title: golang中何时使用指针
date: 2025-11-12 22:11:04
tags: golang
---


* 最直观的是降低拷贝开销，这和c/c++中的指针类似，当一个大的结构体作为函数参数时，传指针只需要8Bytes（64-bit机器）开销。
```go
// 大结构体（包含大量字段或大数组）
type LargeData struct {
    ID    int64
    Data  [1024 * 1024]byte // 1MB 大小的数组
}

// 用值类型作为参数：每次调用都会拷贝整个 LargeData（1MB+）
func ProcessData(data LargeData) {}

// 用指针作为参数：仅拷贝 8 字节（64位系统指针大小），无额外开销
func ProcessData(data *LargeData) {}
```
