---
name: compesations
description: 任何时候，只要涉及到代码都应当使用
---

# Compesations

# 项目描述

使用 HAL 库和 Zig 联合开发 STM32G431RBT6 （蓝桥杯开发版）的实验性项目。

HAL_Driver 目录为 HAL 库源码和部分依赖，一般不会改动。

src 目录下所有 Zig 文件均是实际用户会写的逻辑。

# 约束

本项目基于 Zig 0.15.1，因此只能寻找 0.15.x 扳本的 Zig 相关代码示例

你将被允许在如下网站阅读相关指南：

- [Zig 0.15.2 DOcumentation](https://ziglang.org/documentation/0.15.2/)
- [My Personal Blog](https://aliferne.github.io/2026/02/17/build-up-zig-dev-env-on-stm32g431/)

以及 ST 和 ARM 相关的一些网站，个人博客，博客园，稀土掘金，Stack Overflow 等网站。

不允许从 CSDN 中获取信息。

改动必须保证奥卡姆剃刀原则（如无必要，勿增实体）。

你将只被允许改动：
- src 目录下所有文件
- build.zig 文件
- build.zig.zon 文件（但请尽量不要引入外部依赖）

其余任何文件的改动都将是非法行为。

在改动时必须注明为 AI 生成，如下格式：

```zig
// AI Generated

Your Code

// AI Generated
```

