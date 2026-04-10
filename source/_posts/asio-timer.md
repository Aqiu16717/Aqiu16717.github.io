---
title: asio timer
date: 2026-04-10 13:20:36
tags:
---

asio::steady_timer 是 Asio 库中最基础、最常用的定时器，专门用于异步 / 同步延时操作。


* 同步定时器，阻塞等待

```cpp
asio::io_context io_ctx;
asio::steady_timer timer(io_ctx, asio::chrono::seconds(5));
timer.wait();
```

* 异步定时器，不会阻塞程序，时间到了后会自动回调函数

```cpp
asio::io_context io_ctx;
asio::steady_timer timer(io_ctx);
timer.expires_after(asio::chrono::seconds(3));
timer.async_wait([](const asio::error_code& ec) {
    if (!ec) {
        std::cout << "do something" << std::endl;
    });
io_ctx.run();
```

* 取消定时器

```cpp
// 取消定时器
timer.cancel();

// 回调中会收到 operation_aborted 错误
timer.async_wait([](const asio::error_code& ec) {
    if (ec == asio::error::operation_aborted) {
        std::cout << "定时器被取消\n";
    }
});
```


* asio 兼容 C++ 标准 chrono

```cpp
// 秒
asio::chrono::seconds(1)
// 毫秒
asio::chrono::milliseconds(100)
// 微秒
asio::chrono::microseconds(1000)
```

* 编译命令

```sh
g++ main.cpp -o timer -lasio -pthread
```
