# STM32G431 搭建 Zig 开发环境

## 特别鸣谢

此工程模板已经开源，在此需要感谢优秀的开源项目 [STM32-Zig-移植指南][stm32-zig-porting-guide]，只不过它是基于 F7 的，并且没有提及链接脚本的问题（这也是本文要解决的问题）。

详细内容请前往[个人博客](https://aliferne.github.io/2026/02/17/build-up-zig-dev-env-on-stm32g431/)查看

此处的 compile_commands.json 是借助 `bear` 生成的，用于给 Zed 提供 C/C++ 的 clangd 语法支持。
