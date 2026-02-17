# STM32G431 搭建 Zig 开发环境

## 特别鸣谢

此工程模板已经开源，在此需要感谢优秀的开源项目 [STM32-Zig-移植指南][stm32-zig-porting-guide]，只不过它是基于 F7 的，并且没有提及链接脚本的问题（这也是本文要解决的问题）。

[我的开源直链，点击直达][self-template-opensource]

## 开发环境说明

- OS: Endeavour OS（**注意我不用 Win11**！但是这套技巧应该是通用的）
- Vscode (插件：EIDE, Cortex-Debug, Ziglang, C/C++)
- Arm GNU GCC Toolchain
- STM32CubeMX
- 蓝桥杯开发板（新版）（STM32G431RBT6）

## 搭建 Zig 开发环境实现点灯

### Zig 编译器和 arm-none-eabi 工具链搭建

首先去 [Zig语言官网][ziglang] 下载编译器，我这里使用的版本如下：

```bash
❯ zig version
0.15.1
# 此外顺带给一下 gcc 的版本
❯ arm-none-eabi-gcc --version                       
arm-none-eabi-gcc (Arm GNU Toolchain 15.2.Rel1 (Build arm-15.86)) 15.2.1 20251203
Copyright (C) 2025 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
```

[懒人直链][ziglang-download]，找到 0.15.1 版本下载并解压，然后配下环境，以 Linux 为例：

```bash
echo "export PATH=$PATH:/path/to/your/zig/executable" >> ~/.bashrc
source ~/.bashrc
```

### CubeMX 基础配置

选择 STM32G431RBT6 生成工程到指定位置（这一步应该不用我说吧），
工具链选择：先 MDK-ARM （用于给 EIDE 导入工程），
然后换成 Makefile 再生成一遍（使用 gcc 编译）。

![][CubeMX工具链选择]

然后简单配置一下，我这里用的是蓝桥杯的板子，其实只要配几个 LED 就行：

![][CubeMX基础配置1]

LED 让它默认高电平，这样子 ~~没那么晃眼~~ 等会点灯现象明显一些：

![][蓝桥杯板子 LED 原理图]

![][CubeMX基础配置2]

### Vscode 环境配置

然后打开 Vscode，选择 EIDE 并导入工程，
然后插件会提示你是否要在 MDK-ARM 目录下创建 workspace，
这个就看你个人习惯了，我是更喜欢把 worksapce 放到父文件夹去的。

打开工作区之后侧边导航栏点开 EIDE：
- 项目资源点开 Application/MDK-ARM，
  移除这个给 armcc 用的汇编启动文件，
  添加选择 Makefile 后 CubeMX 新生成的汇编启动文件。
- 构建配置选择 GNU Arm Embedded Toolchain
- 链接脚本路径则填入 STM32G431XX_FLASH.ld 的相对路径
- 烧录配置选择 OpenOCD，并将芯片配置改为 stm32g4x.cfg，接口配置改为 cmsis-dap.cfg

然后再说到 Vscode 对 Debug 的支持，
我们用的插件是 Cortex-Debug，简单写一下 launch.json 文件即可，
由于我们接下来的配置需要建立在对 Makefile 和 Zig 两个工程生成的二进制文件的对比上，
所以我们需要配置两个 Debug 选项：

```json
{
    // 使用 IntelliSense 了解相关属性。 
    // 悬停以查看现有属性的描述。
    // 欲了解更多信息，请访问: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "cwd": "${workspaceRoot}",
            // 填自己项目中的对应路径
            "executable": "/path/to/zig-built/binary.elf",
            "name": "[DEBUG] zig ver",
            "request": "launch",
            "type": "cortex-debug",
            "servertype": "openocd",
            "configFiles": [
                "interface/cmsis-dap.cfg",
                "target/stm32g4x.cfg"
            ],
            "searchDir": [],
            "runToEntryPoint": "main",
            "showDevDebugOutput": "none"
        },
        {
            "cwd": "${workspaceRoot}",
            // 填自己项目中的对应路径
            "executable": "/path/to/arm-gcc-built/binary.elf",
            "name": "[DEBUG] arm-gcc ver",
            "request": "launch",
            "type": "cortex-debug",
            "servertype": "openocd",
            "configFiles": [
                "interface/cmsis-dap.cfg",
                "target/stm32g4x.cfg"
            ],
            "searchDir": [],
            "runToEntryPoint": "main",
            "showDevDebugOutput": "none"
        },
    ]
}
```

如果你想要像 Keil 一样动态查看值（不过只能看值）的话，加入：

```json
"liveWatch": { // Cortex-Debug 的动态监视功能，同 Keil 的全局监视
    "enabled": true,
    "samplesPerSecond": 4
},
```

如果你想要看外设寄存器的值，考虑装一个 Peripheral Viewer 插件，并导入 SVD 文件：

```json
// 看 Periphial （外设） 值
"svdPath": "/path/to/STM32G431.svd", // 获取设备包
```

不过现阶段导入 SVD 没什么用，我们下面要看的寄存器不在 SVD 文件的配置里。

这时正常来说就可以编译烧录了，应该同时也可以调试了（arm-gcc ver 的选项，zig 的还没配完）。

然后 MDK-ARM 你想保留也行，删掉也行，
Makefile 也不是必须的，但我这里为了配置环境会建议你先留着，
因为使用 Zig 构建需要引入一些平时不会去留意的库（Makefile 帮我们做好了），
我们需要通过 Makefile 查看。

### 加入点灯代码

接下来编辑 `Core/Src/main.c` 找到对应位置并加入如下代码：

宏定义：

这个你也可以在 EIDE 插件内选择 C/C++ 属性，
然后在预处理器定义里面加入宏定义，
我就直接写代码里了。

```c
/* USER CODE BEGIN PD */
/// NOTE: 这两个是互斥的
/// NOTE: BUILD_BY_EIDE 默认表示用 EIDE 构建，点灯代码在这个文件里
/// NOTE: BUILD_BY_ZIG 表示用 zig 构建，点灯代码在 src/main.zig 里
#define BUILD_BY_EIDE
// #define BUILD_BY_ZIG
/* USER CODE END PD */
```

外部函数声明：

```c
/* USER CODE BEGIN 0 */
#if defined(BUILD_BY_ZIG) && !defined(BUILD_BY_EIDE)
// 需要 extern 声明以告知编译器确实存在这么个函数
extern void zigMain(void); 
#endif
/* USER CODE END 0 */
```

`main` 函数内部调用：

```c
  /* USER CODE BEGIN 2 */
#if defined(BUILD_BY_ZIG) && !defined(BUILD_BY_EIDE)
  zigMain(); // 不返回！
#endif
  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
// test if the c code is ok
#if !defined(BUILD_BY_ZIG) && defined(BUILD_BY_EIDE)
    HAL_GPIO_WritePin(LED1_GPIO_Port, LED1_Pin, GPIO_PIN_RESET);
    HAL_Delay(1000);
    HAL_GPIO_WritePin(LED1_GPIO_Port, LED1_Pin, GPIO_PIN_SET);
    HAL_Delay(1000);
#endif
  }
```

然后编辑 `src/main.zig`，删除默认代码并加入如下代码：

```zig
export fn zigMain() void {
    while (true) {}
}
```

### Zig 项目初始化

如果你已经设置好了 Zig 的环境变量，
那么直接 `cd` 到你的工作区， `zig init` 一下就可以生成一个项目了。
默认会创建：

- `build.zig`
- `build.zig.zon`
- `src/main.zig`
- `src/root.zig`

其中 `build.zig` 起到类似 Makefile/CMake 的作用，但是完全由 Zig 书写，
你不需要多学一门工具（不过真的有人不会上面那两个的其中一个吗？）。
`build.zig.zon` 我还没研究过，貌似可以从 GitHub 导入外部库。

我们这里暂时不需要 `src/root.zig`，等会会改 `build.zig`，使之只使用 `src/main.zig` 的代码。

### 修改 `build.zig`

接下来我们就要开始写相当重量级的东西了，理解这个过程之后你对整个 STM32 生成项目的步骤都会有质的飞跃。

#### 编译原理简单回顾

我们都知道，C 语言的编译生成二进制文件的过程分为：

![][C 语言编译过程]

- 预处理步骤就是简单的文本替换，我们不需要关心。
- **编译过程**会生成汇编码，这一步就会决定你的代码能在什么平台上跑，这是我们**需要关心**的。
- 汇编过程是生成机器码（二进制），我们不太需要关心。
- **链接过程**会将你的代码与其他二进制文件（lib, o 等）进行链接，
  以补充一些我们自己写的 `extern` 的外部函数/变量及预处理阶段产生的函数声明的实现。
  想了解更多的话可以自行搜索静态链接和动态链接。
  这也是我们**需要关心**的。

Zig 和 C ，以及各种多语言项目之所以可行，其实就在上面已经说明了。
只要 C 生成的二进制文件（动态链接库等）和 Zig 或者是其他语言生成的二进制文件，
两者链接一下，就可以实现多语言项目，
当然前提是生成的二进制文件指令集要匹配，源代码要注明外部都有什么东西。

#### 观察 Makefile

让我们把 Makefile 的 `BUILD_DIR` 换成 `build-make`（防止覆盖 EIDE 默认的 `build` 目录）

接下来 `cd` 到 Makefile 的根目录下，执行 `make -j$(nproc)`，观察命令输出：

下面是生成 obj 文件的过程（由于许多都是差不多的结构，因此只贴一个）：

```bash
arm-none-eabi-gcc -c -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard -DUSE_HAL_DRIVER -DSTM32G431xx -ICore/Inc -IDrivers/STM32G4xx_HAL_Driver/Inc -IDrivers/STM32G4xx_HAL_Driver/Inc/Legacy -IDrivers/CMSIS/Device/ST/STM32G4xx/Include -IDrivers/CMSIS/Include -Og -Wall -fdata-sections -ffunction-sections -g -gdwarf-2 -MMD -MP -MF"build-make/main.d" -Wa,-a,-ad,-alms=build-make/main.lst Core/Src/main.c -o build-make/main.o
```

下面是生成 elf 文件的过程（链接）：

```bash
arm-none-eabi-gcc build-make/main.o build-make/gpio.o build-make/usart.o build-make/stm32g4xx_it.o build-make/stm32g4xx_hal_msp.o build-make/stm32g4xx_hal_pwr_ex.o build-make/stm32g4xx_hal_uart.o build-make/stm32g4xx_hal_uart_ex.o build-make/stm32g4xx_hal.o build-make/stm32g4xx_hal_rcc.o build-make/stm32g4xx_hal_rcc_ex.o build-make/stm32g4xx_hal_flash.o build-make/stm32g4xx_hal_flash_ex.o build-make/stm32g4xx_hal_flash_ramfunc.o build-make/stm32g4xx_hal_gpio.o build-make/stm32g4xx_hal_exti.o build-make/stm32g4xx_hal_dma.o build-make/stm32g4xx_hal_dma_ex.o build-make/stm32g4xx_hal_pwr.o build-make/stm32g4xx_hal_cortex.o build-make/system_stm32g4xx.o build-make/sysmem.o build-make/syscalls.o build-make/startup_stm32g431xx.o  -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard -specs=nano.specs -TSTM32G431XX_FLASH.ld  -lc -lm -lnosys  -Wl,-Map=build-make/zig-test.map,--cref -Wl,--gc-sections -o build-make/zig-test.elf
```

我们可以看到，`arm-none-eabi-gcc` 带有如下参数：

- -Ixxx
- -DUSE_HAL_DRIVER 
- -DSTM32G431xx
- -mcpu=cortex-m4
- -mthumb
- -mfpu=fpv4-sp-d16
- -mfloat-abi=hard
- -specs=nano.specs
- -TSTM32G431XX_FLASH.ld
- -lc -lm -lnosys
- -Wl, -Map=build-make/zig-test.map
- --cref
- -Wl, --gc-sections
...

然后我们来捋一下这里每个参数的作用（下面的表格让 AI 生成了一下）

| 参数                                  | 作用说明                                                                                                                                                           |
| :------------------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **-Ixxx**                             | **头文件搜索路径**<br>告诉编译器在 `xxx` 目录下查找头文件（`.h` 文件）。通常用于包含工程中的驱动目录或中间件目录。                                                 |
| **-DUSE_HAL_DRIVER**                  | **定义宏**<br>在代码中定义 `USE_HAL_DRIVER` 宏。这通常用于 STM32 HAL 库，告诉编译器启用 HAL 库相关的代码（`stm32g4xx_hal_conf.h` 中会检查此宏）。                  |
| **-DSTM32G431xx**                     | **定义宏**<br>定义目标芯片型号为 `STM32G431xx`。这使得 HAL 库能够根据该型号包含特定的外设定义和初始化代码。                                                        |
| **-mcpu=cortex-m4**                   | **目标 CPU**<br>指定目标处理器为 ARM Cortex-M4 内核。                                                                                                              |
| **-mthumb**                           | **指令集**<br>生成 Thumb 指令集代码。这是 Cortex-M 系列处理器（ARMv7-M）默认使用的 16/32 位混合指令集，比传统 ARM 指令更节省空间。                                 |
| **-mfpu=fpv4-sp-d16**                 | **FPU 类型**<br>指定浮点运算单元（FPU）架构。这里表示使用单精度（SP）浮点 VFPv4，包含 16 个双精度寄存器（D0-D15）。                                                |
| **-mfloat-abi=hard**                  | **浮点 ABI**<br>指定浮点二进制接口为 `hard`。意味着浮点运算直接通过硬件 FPU 执行，且函数调用时浮点参数通过浮点寄存器传递，性能更高。                               |
| **-specs=nano.specs**                 | **链接库规格**<br>使用 `newlib-nano` 库规格。这是针对嵌入式系统优化的精简版 C 标准库，代码体积更小。                                                               |
| **-TSTM32G431XX_FLASH.ld**            | **链接脚本**<br>指定使用 `STM32G431XX_FLASH.ld` 作为链接脚本文件。该脚本定义了代码和数据在 Flash 和 RAM 中的存储布局（如堆栈大小、段地址）。                       |
| **-lc -lm -lnosys**                   | **链接库**<br>指定链接时需要的库文件：<br>1. `-lc`: C 标准库<br>2. `-lm`: 数学库<br>3. `-lnosys`: 也就是 `libnosys.a`，用于提供空的系统调用实现（防止链接报错）。 |
| **-Wl, -Map=build-make/zig-test.map** | **链接器参数：生成 MAP 文件**<br>`-Wl` 表示将后面的参数传递给链接器。这里指示链接器生成名为 `zig-test.map` 的映射文件，用于查看内存占用和符号地址。                |
| **--cref**                            | **输出交叉引用表**<br>（通常配合 Map 文件使用）在生成的 Map 文件中输出符号的交叉引用表，显示哪个符号引用了哪个符号。                                               |
| **-Wl, --gc-sections**                | **链接器参数：删除无用段**<br>指示链接器开启垃圾回收机制。它会删除未使用的函数和全局变量（段），从而显著减小最终生成的固件体积。                                   |

我们刚才说到，要关心的主要是编译和链接两个过程，因此这里：

- -mcpu, -mthumb, -mfpu, -mfloat-abi 
- -lc -sepcs=nano.specs, -lm, -lnosys, -TSTM32G431XX_FLASH.ld, -Wl --gc-sections

需要我们关注，其他的也要关注，但它们不是最主要的难点（试问添加头文件和宏定义谁不会呢？）

有了这些信息之后，我们要干的事情就很简单了，只要解决这些问题，理论上就可以用 zig 开发单片机了。

#### 修改 `build.zig`， 编译、链接

先提醒一句，为了避免是 Zig 代码导致的灯不闪烁，现在启用的宏是 `BUILD_BY_EIDE`.

现在我们打开 `build.zig`，删掉多余的注释和 `build` 函数内的内容，然后添加如下内容：

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            // -mthumb
            .cpu_arch = .thumb,
            // 表示无操作系统（裸机环境）
            .os_tag = .freestanding,
            // eabi-hard-float
            .abi = .eabihf,
            // -mcpu=cortex-m4
            .cpu_model = std.Target.Query.CpuModel{ .explicit = &std.Target.arm.cpu.cortex_m4 },
            // 这里可以加入 CPU 特性，比如上面的 -mfpu=fpv4-sp-d16，我这里就没加入
            .cpu_features_add = std.Target.arm.featureSet(
                &[_]std.Target.arm.Feature{},
            ),
        },
    });

    const exec_name = "zig-test";
    // 优化，有四个等级可选，这里默认
    const optimize = b.standardOptimizeOption(.{});

    // 加入模块
    const mod = b.addModule(exec_name, .{
        // 这里指定一下使用 src/main.zig
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = false, // 嵌入式环境不需要 libc
        .single_threaded = true, // 单线程
        .sanitize_c = .off, // 移除 C 语言的 UBSAN 运行时库（避免二进制文件膨胀）
    });

    // 加入可执行文件
    const exe = b.addExecutable(.{
        .name = exec_name ++ ".elf", // 生成 ${exec_name}.elf
        .root_module = mod,
        .linkage = .static, // 静态链接，我们手动指定要链接什么文件
    });

    // 找 arm gcc 编译器，如果没有加入环境的话的话需要用 -Darmgcc 定义
    const arm_gcc_pgm = if (b.option([]const u8, "armgcc", "Path to arm-none-eabi-gcc compiler")) |arm_gcc_path|
        b.findProgram(&.{"arm-none-eabi-gcc"}, &.{arm_gcc_path}) catch {
            std.log.err("Couldn't find arm-none-eabi-gcc at provided path: {s}\n", .{arm_gcc_path});
            unreachable;
        }
    else
        b.findProgram(&.{"arm-none-eabi-gcc"}, &.{}) catch {
            std.log.err("Couldn't find arm-none-eabi-gcc in PATH, try manually providing the path to this executable with -Darmgcc=[path]\n", .{});
            unreachable;
        };

    if (b.option(bool, "NEWLIB_PRINTF_FLOAT", "Force newlib to include float support for printf()")) |_| {
        // -u _printf_float 使之支持打印浮点数
        exe.forceUndefinedSymbol("_printf_float");
    }

    // 链接 GCC 的一些必要的文件（.o 文件）
    // 这里先获取当前环境 GCC 的库路径，然后再在下面进行路径拼接并加入链接
    const gcc_arm_sysroot_path = std.mem.trim(u8, b.run(&.{ arm_gcc_pgm, "-print-sysroot" }), "\r\n");
    const gcc_arm_multidir_relative_path = std.mem.trim(u8, b.run(&.{ arm_gcc_pgm, "-mcpu=cortex-m4", "-mfloat-abi=hard", "-print-multi-directory" }), "\r\n");
    const gcc_arm_version = std.mem.trim(u8, b.run(&.{ arm_gcc_pgm, "-dumpversion" }), "\r\n");
    const gcc_arm_lib_path1 = b.fmt("{s}/../lib/gcc/arm-none-eabi/{s}/{s}", .{ gcc_arm_sysroot_path, gcc_arm_version, gcc_arm_multidir_relative_path });
    const gcc_arm_lib_path2 = b.fmt("{s}/lib/{s}", .{ gcc_arm_sysroot_path, gcc_arm_multidir_relative_path });

    // 手动加入 newlib 和 c_nano 库
    mod.addLibraryPath(.{ .cwd_relative = gcc_arm_lib_path1 });
    mod.addLibraryPath(.{ .cwd_relative = gcc_arm_lib_path2 });
    mod.addSystemIncludePath(.{ .cwd_relative = b.fmt("{s}/include", .{gcc_arm_sysroot_path}) });
    // -lc_nano，由于 zig 没有 -specs=nano.specs 字段，因此只能显式链接 libc_nano.a
    mod.linkSystemLibrary("c_nano", .{
        .needed = true,
        .preferred_link_mode = .static,
        .use_pkg_config = .no,
    });
    mod.linkSystemLibrary("m", .{
        .needed = true,
        .preferred_link_mode = .static,
        .use_pkg_config = .no,
    });

    // 这里在链接一些必要的 CRT (C Run-Time) obj 文件 
    mod.addObjectFile(.{ .cwd_relative = b.fmt("{s}/crt0.o", .{gcc_arm_lib_path2}) });
    mod.addObjectFile(.{ .cwd_relative = b.fmt("{s}/crti.o", .{gcc_arm_lib_path1}) });
    mod.addObjectFile(.{ .cwd_relative = b.fmt("{s}/crtbegin.o", .{gcc_arm_lib_path1}) });
    mod.addObjectFile(.{ .cwd_relative = b.fmt("{s}/crtend.o", .{gcc_arm_lib_path1}) });
    mod.addObjectFile(.{ .cwd_relative = b.fmt("{s}/crtn.o", .{gcc_arm_lib_path1}) });

    const STM32_Driver_Path = "HAL_Driver";

    // 这里就是加入 STM32 HAL 库的头文件
    mod.addIncludePath(b.path(b.fmt("{s}/Core/Inc", .{STM32_Driver_Path})));
    mod.addIncludePath(b.path(b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Inc", .{STM32_Driver_Path})));
    mod.addIncludePath(b.path(b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Inc/Legacy", .{STM32_Driver_Path})));
    mod.addIncludePath(b.path(b.fmt("{s}/Drivers/CMSIS/Device/ST/STM32G4xx/Include", .{STM32_Driver_Path})));
    mod.addIncludePath(b.path(b.fmt("{s}/Drivers/CMSIS/Include", .{STM32_Driver_Path})));
    // 汇编启动文件
    mod.addAssemblyFile(b.path(b.fmt("{s}/startup_stm32g431xx.s", .{STM32_Driver_Path})));
    // 源文件
    mod.addCSourceFiles(.{
        .files = &.{
            b.fmt("{s}/Core/Src/main.c", .{STM32_Driver_Path}),
            b.fmt("{s}/Core/Src/usart.c", .{STM32_Driver_Path}),
            b.fmt("{s}/Core/Src/gpio.c", .{STM32_Driver_Path}),
            b.fmt("{s}/Core/Src/stm32g4xx_it.c", .{STM32_Driver_Path}),
            b.fmt("{s}/Core/Src/stm32g4xx_hal_msp.c", .{STM32_Driver_Path}),
            b.fmt("{s}/Core/Src/system_stm32g4xx.c", .{STM32_Driver_Path}),
            b.fmt("{s}/Core/Src/sysmem.c", .{STM32_Driver_Path}),
            b.fmt("{s}/Core/Src/syscalls.c", .{STM32_Driver_Path}),
            // HAL Drivers
            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal.c", .{STM32_Driver_Path}),

            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_pwr.c", .{STM32_Driver_Path}),
            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_pwr_ex.c", .{STM32_Driver_Path}),

            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_dma.c", .{STM32_Driver_Path}),
            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_dma_ex.c", .{STM32_Driver_Path}),

            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_gpio.c", .{STM32_Driver_Path}),

            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_exti.c", .{STM32_Driver_Path}),

            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_cortex.c", .{STM32_Driver_Path}),

            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_rcc.c", .{STM32_Driver_Path}),
            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_rcc_ex.c", .{STM32_Driver_Path}),

            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_flash.c", .{STM32_Driver_Path}),
            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_flash_ex.c", .{STM32_Driver_Path}),
            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_flash_ramfunc.c", .{STM32_Driver_Path}),

            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_uart.c", .{STM32_Driver_Path}),
            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_uart_ex.c", .{STM32_Driver_Path}),

            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_tim.c", .{STM32_Driver_Path}),
            b.fmt("{s}/Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_tim_ex.c", .{STM32_Driver_Path}),
        },
    });

    // -DUSE_HAL_DRIVER
    mod.addCMacro("USE_HAL_DRIVER", "");
    // -DSTM32G431xx
    mod.addCMacro("STM32G431xx", "");

    // -Wl, --gc-sections
    exe.link_gc_sections = true;
    // -fdata-sections
    exe.link_data_sections = true;
    // -ffunction-sections
    exe.link_function_sections = true;

    // -TSTM32G431xx_FLASH.ld
    exe.setLinkerScript(b.path(b.fmt("{s}/STM32G431XX_FLASH.ld", .{STM32_Driver_Path})));
    // 生成 elf 文件
    b.installArtifact(exe);
}
```

理论上来说到这里，我们就可以开始 `zig build` 然后愉快地编译了。

但是等一下，为什么会报错？

```bash
❯ zig build          
install
└─ install zig-test.elf
   └─ compile exe zig-test.elf Debug thumb-freestanding-eabihf 1 errors
error: ld.lld: /home/ferne/桌面/stm32-zig-test/HAL_Driver/STM32G431XX_FLASH.ld:56: memory region not defined: RAM
    note: _estack = ORIGIN(RAM) + LENGTH(RAM);    /* end of RAM */
    note:                     ^
error: the following command failed with 1 compilation errors:
...
```

可以看到是链接文件的问题，它提示我们 RAM 这个内存区域没有定义，那么我们来看一下 CubeMX 生成的 ld 文件：

### 修改 `STM32G431XX_FLASH.ld`，链接

我们来看这一段：

```ld
/* Entry Point */
ENTRY(Reset_Handler)

/* Highest address of the user mode stack */
_estack = ORIGIN(RAM) + LENGTH(RAM);    /* end of RAM */
/* Generate a link error if heap and stack don't fit into RAM */
_Min_Heap_Size = 0x200;      /* required amount of heap  */
_Min_Stack_Size = 0x400; /* required amount of stack */

/* Specify the memory areas */
MEMORY
{
RAM (xrw)      : ORIGIN = 0x20000000, LENGTH = 32K
FLASH (rx)      : ORIGIN = 0x8000000, LENGTH = 128K
}
```

可以看到是定义了 RAM 的，但是是在使用之后定义的，这是很典型的前向引用问题，修改一下就好了：

```ld
/* Entry Point */
ENTRY(Reset_Handler)

/* Specify the memory areas */
MEMORY
{
RAM (xrw)      : ORIGIN = 0x20000000, LENGTH = 32K
FLASH (rx)      : ORIGIN = 0x8000000, LENGTH = 128K
}

/* Highest address of the user mode stack */
_estack = ORIGIN(RAM) + LENGTH(RAM);    /* end of RAM */
/* Generate a link error if heap and stack don't fit into RAM */
_Min_Heap_Size = 0x200;      /* required amount of heap  */
_Min_Stack_Size = 0x400; /* required amount of stack */
```

然后再 build，发现更多的问题：

```bash
❯ zig build
install
└─ install zig-test.elf
   └─ compile exe zig-test.elf Debug thumb-freestanding-eabihf 29 errors
error: ld.lld: /home/ferne/桌面/stm32-zig-test/HAL_Driver/STM32G431XX_FLASH.ld:106: symbol not found: READONLY
error: ld.lld: /home/ferne/桌面/stm32-zig-test/HAL_Driver/STM32G431XX_FLASH.ld:113: symbol not found: READONLY
error: ld.lld: /home/ferne/桌面/stm32-zig-test/HAL_Driver/STM32G431XX_FLASH.ld:122: symbol not found: READONLY
...
```

我个人推测是因为 zig 的编译器 `zig cc` 没有实现 GCC11 及更高版本所支持的 `READONLY` 关键字，
我们删掉 ld 文件中所有带 `READONLY` 的部分，然后再 `zig build`。

好，构建成功！

```bash
❯ zig build

❯ echo $? # 看下返回值
0
```

但是这就完事了吗？来，我们烧录进去看一下。

```bash
❯ /usr/bin/openocd  -s "/path/to/your/project" -f "interface/cmsis-dap.cfg" -f "target/stm32g4x.cfg" -c "program \"/path/to/your/binary.elf\" verify " -c "reset run" -c "exit"
Open On-Chip Debugger 0.12.0-01004-g9ea7f3d64-dirty (2025-11-12-08:18)
Licensed under GNU GPL v2
For bug reports, read
        http://openocd.org/doc/doxygen/bugs.html
Info : auto-selecting first available session transport "swd". To override use 'transport select <transport>'.
Info : CMSIS-DAP: SWD supported
Info : CMSIS-DAP: JTAG supported
Info : CMSIS-DAP: FW Version = 1.0
Info : CMSIS-DAP: Interface Initialised (SWD)
Info : SWCLK/TCK = 1 SWDIO/TMS = 1 TDI = 1 TDO = 1 nTRST = 0 nRESET = 1
Info : CMSIS-DAP: Interface ready
Info : clock speed 2000 kHz
Info : SWD DPIDR 0x2ba01477
Info : [stm32g4x.cpu] Cortex-M4 r0p1 processor detected
Info : [stm32g4x.cpu] target has 6 breakpoints, 4 watchpoints
Info : starting gdb server for stm32g4x.cpu on 3333
Info : Listening on port 3333 for gdb connections
[stm32g4x.cpu] halted due to debug-request, current mode: Thread 
xPSR: 0x01000000 pc: 0x08000468 msp: 0x20008000
** Programming Started **
Info : device idcode = 0x20036468 (STM32G43/G44xx - Rev 'unknown' : 0x2003)
Info : RDP level 0 (0xAA)
Info : flash size = 128 KiB
Info : flash mode : single-bank
Info : Padding image section 3 at 0x080033e4 with 4 bytes (bank write end alignment)
Warn : Adding extra erase range, 0x080033e8 .. 0x080037ff
Info : device idcode = 0x20036468 (STM32G43/G44xx - Rev 'unknown' : 0x2003)
Info : RDP level 0 (0xAA)
Info : OTP size is 1024 bytes, base address is 0x1fff7000
Warn : no flash bank found for address 0x2000005c
** Programming Finished **
** Verify Started **
Error: checksum mismatch - attempting binary compare
embedded:startup.tcl:1516: Error: ** Verify Failed **
Traceback (most recent call last):
  File "embedded:startup.tcl", line 1577, in program
    program_error {** Verify Failed **} 0
  File "embedded:startup.tcl", line 1516, in program_error
    error {** Verify Failed **}
```

看下报错，发现有两处：

> Warn : no flash bank found for address 0x2000005c
> 
> embedded:startup.tcl:1516: Error: ** Verify Failed **

一是 no flash bank，二是 Verify Failed，让我们去掉 `verify` 再试一次：

```bash
❯ /usr/bin/openocd  -s "/path/to/your/project" -f "interface/cmsis-dap.cfg" -f "target/stm32g4x.cfg" -c "program \"/path/to/your/binary.elf\" " -c "reset run" -c "exit"
...
Info : Padding image section 3 at 0x080033e4 with 4 bytes (bank write end alignment)
Warn : Adding extra erase range, 0x080033e8 .. 0x080037ff
Info : device idcode = 0x20036468 (STM32G43/G44xx - Rev 'unknown' : 0x2003)
Info : RDP level 0 (0xAA)
Info : OTP size is 1024 bytes, base address is 0x1fff7000
Warn : no flash bank found for address 0x2000005c
** Programming Finished **
```

### 为何 `HardFault` ？

首先我想提醒的是，一定注意是小端序的，不要读错内存了！
**小端序是低位放在低地址的！**

如果你很懒，不想看一大段分析，那么可以从[这里](#lma-vma以及-hardfault-破案)跳转到最后看解决方案。

#### 事故现场分析

发现虽然还有 Warn，但至少烧录成功了。
但为什么板子灯是全亮的？这显然不合理，
这时候我们写的 Cortex-Debug 配置就派上用场了，
选择这个选项开始调试。
我们启用的宏是 `BUILD_BY_EIDE`，这就确保了不会是 Zig 代码的问题，
现在我们来看一下：

![][ZIG-DEBUG-HardFault]

什么情况？怎么触发 `HardFault` 了？
那好吧，断点打到这里看一下。

![][ZIG-DEBUG-HardFault-StackTrace]

可以看到这里的调用堆栈显示进入 `HardFault` 的过程是：

```
Reset_Handler@0x0800049a ->
__libc_init_array@0x080003a4 ->
??@0x0001f000 -> 
<signal handler called>@0xfffffff9 ->
HardFault_Handler@0x080007ac
```

因此肯定是上面的某个函数出了什么问题而导致的 `HardFault`，
我们先来看下 `HardFault` 可能出现的原因。

下文引自清华大学出版社出版的 Cortex-M4 权威指南：

![][CortexM4权威指南-SCB介绍]

可以看到 HardFault 是各种错误都有可能的，这确实加大了排查难度。
不过我们的堆栈里面似乎提到了 `__libc_init_array`，看着就像是和数组/内存的非法访问有关。
那么是吗？我在找的过程中还发现了 SCB 这个控制块，也许它能给我们点信息：

![][CortexM4权威指南-SCB-HFSR等寄存器]

可以看到这个是和 `HardFault` 有关的寄存器，也许我们能从这里找到点灵感。
接下来打开 Cortex-Debug 提供的 Memory View，输入 `0xe000ed2c`，可以看到：

![][MemoryView-HFSR-DEBUG]

显示的 C 文件是 `core_cm4.c`，可以经由 `stm32g4xx_hal_cortex.c` 中任意对 NVIC 操作的宏函数定位到该文件。
此处的 `uint32_t HFSR` 位于 `SCB_Type` 结构体中，
在 Memory View 里面我们可以看到值为 `0x4000 0000`（时刻注意，是**小端序**！）
0x4000 0000：3 * 8 = 24 个 0，加上 0x40 的 6 个 0，也就是 30 个 0，
             1 在 31 位，但数据手册从 0 开始数位数，因此第 30 位被置 1，
             下面也是一样的分析方法，就不赘述了。
接下来让我们看下 STM32 Cortex-M4 编程手册：

![][STM32-CortexM4-Ref-SCB-HFSR]

可以看到这里是因为某些原因写入了第 30 位（FORCED）所导致的 `HardFault`，
而这个通常是由于其他可配置的错误触发的。
这里只是说被强制 `HardFault` 了，但是并没有说明具体是什么原因导致的，我们还得再找找。
Cortex M4 编程手册指导我们应当再看一下其他的错误寄存器，那就看一下。

我们还注意到了有个 CFSR，看下是否有什么提示信息。
查看之后发现值为 `0x0002 0000`，也就是第 17 个 bit 被写入：

![][STM32-CortexM4-Ref-SCB-CFSR]

![][STM32-CortexM4-Ref-CFSR-UFSR]

错误原因：

> Invalid state usage fault. When this bit is set to 1, the PC value stacked for the exception return points to the instruction that attempted the illegal use of the EPSR.
>
> EPSR: Execution program status register

因此这看起来像是错误调用了什么函数，执行到了某条错误的指令（因为和 PC 有关），
上面的调用堆栈里面，`Reset_Handler` 和 `__libc_init_array` 是存在的，
`HardFault_Handler` 是存在的，但是我们看不到 `__libc_init_array` 的实现，
也许我们需要借助互联网的伟力，以及一些小小的反汇编技巧。
这里暂时按下不表，目前的信息还是比较匮乏的，我们还需要获得更多故障信息。

我们再查阅一下 Cortex M4 权威指南，看下还有没有关于 SCB 的更多信息，
现在似乎只能知道可能是因为调用了某个函数而导致的错误。
但很遗憾，除了上面提到的 UFSR 以外，其他错误寄存器并不能给我们提供什么有用的信息。

这里提到了 EPSR，因此需要查看一下寄存器操作。
我们查阅此[博客][cortexm4-xpsr]。
留意到 xPSR，它的读数为：`0x8100 0003`（调试中的 Register 提示），
由上面的博客和 STM32 的 Cortex M4 编程手册可知此时指示我们：

- N：小于或等于标志（ 0x8... ）
- 工作在 thumb 指令集（`-mthumb`, 0x81... 的 1 表示为 thumb 指令集）
- 发生了 `HardFault`（末尾数字是 3，指示为 `HardFault`）

这似乎并不能给我们提供什么有用的信息，
我们顶多知道在触发 `HardFault` 之前做了一下减法运算，
但是姑且先放在这里作为一条信息吧。

我们再次回到官方的编程手册，其中 `EXEC_RETURN` 中似乎指示了什么数字：

![][STM32-CortexM4-Ref-EXECRETURN]

这里提到了 `0xFFFF FFF9`，似乎很眼熟，我们回到调用堆栈：

```
...
??@0x0001f000 -> 
<signal handler called>@0xfffffff9 ->
...
```

看到了吗，这里有一个 `0xFFFF FFF9`，让我们看下上面的解释。
> 返回至线程模式，异常返回过程将使用主堆栈（MSP） 中保存的非浮点状态，且返回后的程序执行也将继续使用主堆栈（MSP）。

这说明进行了状态切换，现在我们没有更多信息了，那让我们整理一下已有的信息吧。

#### 故障信息汇总

1. 程序执行流程为 `Reset_Handler` --> `__libc_init_array` --> `??` --> 状态切换 --> `HardFault_Handler`
2. 可能是由于错误的函数调用（执行了某个非法地址的函数，其中疑点是 ?? 所代表的 PC 地址）导致了 `HardFault`

我们接下来对应的解题思路是：

1. 对 `__libc_init_array` 进行反汇编，看下是否有可疑之处
2. 查找 `??` 所代表的 PC 地址在 Cortex M4 的内存映射中是什么

### 程序启动流程

如果到了现在，你依然认为烧进去的程序第一个从 `main` 函数开始的话，那我也不知道说什么了。

很显然，启动顺序应该是：

```
Reset_Handler --> SystemInit --> <Some functions for initialzing data> --> __libc_init_array --> main
```

这一段通过对 `startup_stm32g431xx.s` 的分析即可得知，
我们出问题的地方就是 `__libc_init_array` 往后，
且经过调试之后发现 Makefile 创建的 elf 文件不会在 `__libc_init_array` 处炸掉。
这里我找来了这个函数的[源码实现][impl-of-__libc_init_array-1]:

```c
/* These magic symbols are provided by the linker.  */
extern void (*__preinit_array_start []) (void) __attribute__((weak));
extern void (*__preinit_array_end []) (void) __attribute__((weak));
extern void (*__init_array_start []) (void) __attribute__((weak));
extern void (*__init_array_end []) (void) __attribute__((weak));
extern void (*__fini_array_start []) (void) __attribute__((weak));
extern void (*__fini_array_end []) (void) __attribute__((weak));

extern void _init (void);
extern void _fini (void);

/* Iterate over all the init routines.  */
void
__libc_init_array (void)
{
  size_t count;
  size_t i;

  count = __preinit_array_end - __preinit_array_start;
  for (i = 0; i < count; i++)
    __preinit_array_start[i] ();

  _init ();

  count = __init_array_end - __init_array_start;
  for (i = 0; i < count; i++)
    __init_array_start[i] ();
}
```

给某些不太清楚这玩意是干啥的读者介绍一下：
在嵌入式系统编程中，`__libc_init_array` 函数是一个关键的启动时调用，
负责初始化 C 库环境以及调用静态对象的构造函数。
这个函数通常在程序的 `main` 函数之前被调用，确保所有必要的系统和库初始化都已完成。

由于我找到了两个来源（[第二个][impl-of-__libc_init_array-2]），
因此这里的源码只能作为一个参考，实际上需要逆向生成的二进制文件，
但是既然有了这段源码，就可以推知应该是这里的数组或者 `_init()` 哪里有问题了。

### 对 `zig` 和 `gcc` 构建的两种二进制产物的逆向分析

我们接下来开始尝试分析这两个二进制文件的异同，看下究竟是什么导致的问题。
经过上面的分析，我们已经可以将问题锁定在函数调用相关的操作上了，
尤其是 `__libc_init_array`，这是需要重点排查的。

#### 初始设定

为了简化操作，我们临时给一堆东西赋个值。

```bash
❯ ac_pre=arm-none-eabi
❯ acc=$ac_pre-gcc       # 编译器
❯ aod=$ac_pre-objdump   # 反汇编
❯ are=$ac_pre-readelf   # 读 elf
❯ anm=$ac_pre-nm        # 看符号表
❯ aoc=$ac_pre-objcopy   # 转换格式
❯ make_elf=HAL_Driver/build-make/zig-test.elf
❯ zig_elf=zig-out/bin/zig-test.elf
```

#### 文件头分析

```bash
❯ $are -h $make_elf
ELF Header:
  Magic:   7f 45 4c 46 01 01 01 00 00 00 00 00 00 00 00 00 
  Class:                             ELF32
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0
  Type:                              EXEC (Executable file)
  Machine:                           ARM
  Version:                           0x1
  Entry point address:               0x8001ba9
  Start of program headers:          52 (bytes into file)
  Start of section headers:          196448 (bytes into file)
  Flags:                             0x5000400, Version5 EABI, hard-float ABI
  Size of this header:               52 (bytes)
  Size of program headers:           32 (bytes)
  Number of program headers:         3
  Size of section headers:           40 (bytes)
  Number of section headers:         22
  Section header string table index: 21
```

```bash
❯ $are -h $zig_elf 
ELF Header:
  Magic:   7f 45 4c 46 01 01 01 00 00 00 00 00 00 00 00 00 
  Class:                             ELF32
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0
  Type:                              EXEC (Executable file)
  Machine:                           ARM
  Version:                           0x1
  Entry point address:               0x8000251
  Start of program headers:          52 (bytes into file)
  Start of section headers:          1156992 (bytes into file)
  Flags:                             0x5000400, Version5 EABI, hard-float ABI
  Size of this header:               52 (bytes)
  Size of program headers:           32 (bytes)
  Number of program headers:         9
  Size of section headers:           40 (bytes)
  Number of section headers:         30
  Section header string table index: 28
```

可以看到两者基本都相同：elf 文件，ARM 架构，32 位，小端序，硬浮点数…。
这里基本没什么问题。
入口点无法保证完全相同（大概是因为一些 bss 段、data 段等的占用），
但是只要在 `0x0800 0000` 以后即可（这和 Cortex M4 的复位启动流程有关，见[下文](#cortex-m4-启动流程)）

#### 内存分析

```bash
❯ $are -l $make_elf

Elf file type is EXEC (Executable file)
Entry point 0x8001ba9
There are 3 program headers, starting at offset 52

Program Headers:
  Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
  LOAD           0x001000 0x08000000 0x08000000 0x01fd4 0x01fd4 R E 0x1000
  LOAD           0x003000 0x20000000 0x08001fd4 0x0000c 0x000a4 RW  0x1000
  LOAD           0x0000a4 0x200000a4 0x08001fe0 0x00000 0x00604 RW  0x1000

 Section to Segment mapping:
  Segment Sections...
   00     .isr_vector .text .rodata .ARM.exidx.text.__udivmoddi4 
   01     .data .bss 
   02     ._user_heap_stack 
```

```bash
❯ $are -l $zig_elf 

Elf file type is EXEC (Executable file)
Entry point 0x8000251
There are 9 program headers, starting at offset 52

Program Headers:
  Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
  LOAD           0x010000 0x08000000 0x08000000 0x00248 0x00248 R   0x10000
  LOAD           0x010248 0x08000248 0x08000248 0x030ec 0x030ec R E 0x10000
  LOAD           0x013334 0x08003334 0x08003334 0x00064 0x00064 R   0x10000
  LOAD           0x020000 0x20000000 0x08003398 0x0005c 0x0005c RW  0x10000
  LOAD           0x02005c 0x2000005c 0x2000005c 0x007fc 0x007fc RW  0x10000
  GNU_RELRO      0x020850 0x20000850 0x20000850 0x00008 0x00008 R   0x1
  GNU_EH_FRAME   0x01338c 0x0800338c 0x0800338c 0x0000c 0x0000c R   0x4
  GNU_STACK      0x000000 0x00000000 0x00000000 0x00000 0x1000000 RW  0
  ARM_EXIDX      0x0101d8 0x080001d8 0x080001d8 0x00070 0x00070 R   0x4

 Section to Segment mapping:
  Segment Sections...
   00     .isr_vector .ARM.exidx 
   01     .text 
   02     .rodata .ARM.extab.text.HAL_RCC_OscConfig .ARM.extab.text.__udivmoddi4 .eh_frame_hdr 
   03     .data 
   04     .tm_clone_table .bss ._user_heap_stack .init_array .fini_array 
   05     .init_array .fini_array 
   06     .eh_frame_hdr 
   07     
   08     .ARM.exidx 
```

此时我们需要注意了，
`zig_elf` 的版本里面似乎出现了许多我们在 `make_elf` 中没看到的东西，
而我们之前特别提到了要注意函数调用之类的操作。

注意 `.init_array` 和 `.fini_array`，从名字中可以看出它肯定和函数调用有点关系。

此外我们还观察到了一点：
Makefile 编译的文件，VirtAddr 和 PhysAddr 不一致，但是 Zig 编译的则是一致的，
这是否会导致什么区别呢？

#### 反汇编分析

接下来我们来抓包 `__libc_init_array`：

```bash
❯ $aod -S $zig_elf | grep -i "__libc_init_array"   
 8000292:       f000 f86d       bl      8000370 <__libc_init_array>
08000370 <__libc_init_array>:
 ...
 8000496:       f7ff ff6b       bl      8000370 <__libc_init_array>
```

```bash
❯ $aod -S $zig_elf | grep -A 26 -i "<__libc_init_array>:"
08000370 <__libc_init_array>:
 8000370:       b570            push    {r4, r5, r6, lr}
 8000372:       4b0d            ldr     r3, [pc, #52]   @ (80003a8 <__libc_init_array+0x38>)
 8000374:       4c0d            ldr     r4, [pc, #52]   @ (80003ac <__libc_init_array+0x3c>)
 8000376:       2600            movs    r6, #0
 8000378:       1b1d            subs    r5, r3, r4
 800037a:       ebb6 0fa5       cmp.w   r6, r5, asr #2
 800037e:       d109            bne.n   8000394 <__libc_init_array+0x24>
 8000380:       f002 ffc4       bl      800330c <_init>
 8000384:       4c0a            ldr     r4, [pc, #40]   @ (80003b0 <__libc_init_array+0x40>)
 8000386:       4b0b            ldr     r3, [pc, #44]   @ (80003b4 <__libc_init_array+0x44>)
 8000388:       2600            movs    r6, #0
 800038a:       1b1d            subs    r5, r3, r4
 800038c:       ebb6 0fa5       cmp.w   r6, r5, asr #2
 8000390:       d105            bne.n   800039e <__libc_init_array+0x2e>
 8000392:       bd70            pop     {r4, r5, r6, pc}
 8000394:       f854 3b04       ldr.w   r3, [r4], #4
 8000398:       4798            blx     r3
 800039a:       3601            adds    r6, #1
 800039c:       e7ed            b.n     800037a <__libc_init_array+0xa>
 800039e:       f854 3b04       ldr.w   r3, [r4], #4
 80003a2:       4798            blx     r3
 80003a4:       3601            adds    r6, #1
 80003a6:       e7f1            b.n     800038c <__libc_init_array+0x1c>
        ...
 80003b0:       20000850        .word   0x20000850
 80003b4:       20000854        .word   0x20000854
```

从上面的反汇编看来，我之前找到的源码基本是八九不离十的，
接下来让我们看下 `bl _init`（调用 `_init` 函数），看下 `_init` 函数又做了什么：

```bash
❯ $aod -S $zig_elf | grep -A 20 -i "<_init>:"
0800330c <_init>:
 800330c:       b5f8            push    {r3, r4, r5, r6, r7, lr}
 800330e:       bf00            nop
 8003310:       bcf8            pop     {r3, r4, r5, r6, r7}
 8003312:       bc08            pop     {r3}
 8003314:       469e            mov     lr, r3
 8003316:       4770            bx      lr

08003318 <_fini>:
 8003318:       b5f8            push    {r3, r4, r5, r6, r7, lr}
 800331a:       bf00            nop
 800331c:       bcf8            pop     {r3, r4, r5, r6, r7}
 800331e:       bc08            pop     {r3}
 8003320:       469e            mov     lr, r3
 8003322:       4770            bx      lr
```

然后我们看下 makefile 生成的：

```bash
❯ $aod -S $make_elf | grep -A 26 -i "<__libc_init_array>:"
08001c0c <__libc_init_array>:
 8001c0c:       b570            push    {r4, r5, r6, lr}
 8001c0e:       4b0d            ldr     r3, [pc, #52]   @ (8001c44 <__libc_init_array+0x38>)
 8001c10:       4c0d            ldr     r4, [pc, #52]   @ (8001c48 <__libc_init_array+0x3c>)
 8001c12:       2600            movs    r6, #0
 8001c14:       1b1d            subs    r5, r3, r4
 8001c16:       ebb6 0fa5       cmp.w   r6, r5, asr #2
 8001c1a:       d109            bne.n   8001c30 <__libc_init_array+0x24>
 8001c1c:       f000 f9aa       bl      8001f74 <_init>
 8001c20:       4c0a            ldr     r4, [pc, #40]   @ (8001c4c <__libc_init_array+0x40>)
 8001c22:       4b0b            ldr     r3, [pc, #44]   @ (8001c50 <__libc_init_array+0x44>)
 8001c24:       2600            movs    r6, #0
 8001c26:       1b1d            subs    r5, r3, r4
 8001c28:       ebb6 0fa5       cmp.w   r6, r5, asr #2
 8001c2c:       d105            bne.n   8001c3a <__libc_init_array+0x2e>
 8001c2e:       bd70            pop     {r4, r5, r6, pc}
 8001c30:       f854 3b04       ldr.w   r3, [r4], #4
 8001c34:       4798            blx     r3
 8001c36:       3601            adds    r6, #1
 8001c38:       e7ed            b.n     8001c16 <__libc_init_array+0xa>
 8001c3a:       f854 3b04       ldr.w   r3, [r4], #4
 8001c3e:       4798            blx     r3
 8001c40:       3601            adds    r6, #1
 8001c42:       e7f1            b.n     8001c28 <__libc_init_array+0x1c>
        ...
```

```bash
❯ $aod -S $make_elf | grep -A 20 -i "<_init>:"
08001f74 <_init>:
 8001f74:       b5f8            push    {r3, r4, r5, r6, r7, lr}
 8001f76:       bf00            nop
 8001f78:       bcf8            pop     {r3, r4, r5, r6, r7}
 8001f7a:       bc08            pop     {r3}
 8001f7c:       469e            mov     lr, r3
 8001f7e:       4770            bx      lr

08001f80 <_fini>:
 8001f80:       b5f8            push    {r3, r4, r5, r6, r7, lr}
 8001f82:       bf00            nop
 8001f84:       bcf8            pop     {r3, r4, r5, r6, r7}
 8001f86:       bc08            pop     {r3}
 8001f88:       469e            mov     lr, r3
 8001f8a:       4770            bx      lr
```

对比上面两个汇编，发现什么了吗？对，`zig` 构建的版本有 `__init_array_start` 数组：

```
 80003b0:       20000850        .word   0x20000850
 80003b4:       20000854        .word   0x20000854
```

显然我们需要知道这两处地方到底存了什么东西，因为上面 `__libc_init_array` 调用了这里的内容，
如果这里的内容是垃圾值的话，很显然会导致报错。

回到我们提过的 `.init_array` 和 `.fini_array`，看来我们现在要看的是链接阶段产生的 `.section` 了。
我们的 `STM32G431XX_FLASH.ld` 是否有定义这两个东西呢？肯定是没有的。
那么为什么 `zig cc` 会把它制造出来呢？这可能就是 `zig` 内部的默认实现了。
那么 `zig` 默认会把这东西放哪里呢？不好说，所以这里我们到时候肯定要琢磨一下重写掉。

### “拆除 `HardFault` 炸弹”

#### 观察错误的 PC 值

我们现在锁定了问题，在 `__init_array_start` 数组中到底存在什么东西？
导致 MCU 调用这里的程序后就触发了异常？
我们看到调用堆栈，观察地址：`??@0x0001f000`，这个在 STM32 中对应是什么内存区域呢：

![][STM32-参考手册-内存布局]

我们发现，`0x0001 f000` 属于：
> Flash, system memory or SRAM, depending on BOOT configuration

根据蓝桥杯板子的 BOOT0 引脚配置，可以得知现在是主存作为 boot 引导区域（这似乎是废话）

![][蓝桥杯板子 BOOT0 配置]

![][STM32-参考手册-BOOT配置]

#### Cortex M4 启动流程

但问题是，Cortex-M4 的复位启动流程是什么？
明明之前都是在 `0x0800 xxxx` 执行的代码，怎么一下子跳到 `0x0001 ffff` 了？

![][CortexM4权威指南-复位流程]

所以我们可以发现，一开始读取 SP 之后就会跳转到对应的地方去执行代码。
根据文件头分析中的内容，我们知道 zig 编译的程序的入口点在 `0x0800 0251`，
因此如果莫名回到了 `0x0001 ffff`，那么很显然就是函数调用出现问题。

但是，为什么函数的入口点就会在 `0x0800 0251` 呢？为什么不可以从 `0x000 0008` 开始呢？
这就要请出链接脚本了。

#### 链接脚本 (.ld/.lds) 简介

那么链接脚本是干什么的？或者说在裸机环境下如何构造内存布局？

如果你曾经学习过编译原理和操作系统相关的知识的话，
那么你会知道操作系统需要进行内存管理，内存管理有专门的模块，
OS 负责将一个个程序加载进入内存里面去执行。

但是在裸机环境下，并不存在这样的模块（Cortex-M4 复位后会从 `0x0000 0000` 开始执行），
因此我们需要用到链接脚本，
链接脚本会告诉链接器应该如何组织各个编译单元生成的目标文件（.o）中的段（section），
从而保证：
1. 向量表（.isr_vector）位于 Flash 起始地址 `0x0800 0000`
2. 代码段（.text）紧随其后
3. 数据段（.data）和 BSS 段（.bss）位于 SRAM
4. 栈和堆的位置和大小符合要求

因此我们需要用到链接脚本，链接脚本会告诉链接器应该怎么分配整合各个汇编阶段生成的二进制文件，
通过调整链接脚本，我们可以改变程序在内存中的布局。

顺带说一下：
- VMA（Virtual Memory Address）：程序运行时的地址（即 VirtualAddr）
- LMA（Load Memory Address）：程序加载时的地址（即 PhysicAddr）

我们来分析一下 STM32CubeMX 生成的链接脚本，以辅助大家理解。

下面这段表示程序将从 Reset_Handler 作为程序入口点开始运行：

```ld
/* Entry Point */
ENTRY(Reset_Handler)
```

下面这段指示 RAM 和 FLASH 的起始位置和长度，同时声明只有 RAM 是可执行的：

r：可读；w：可写；x：可执行

```ld
/* Specify the memory areas */
MEMORY
{
RAM (xrw)      : ORIGIN = 0x20000000, LENGTH = 32K
FLASH (rx)      : ORIGIN = 0x8000000, LENGTH = 128K
}
```

下面这段声明 _estack 在 RAM 结束之后，同时指示 Heap 和 Stack 的大小：

```ld
/* Highest address of the user mode stack */
_estack = ORIGIN(RAM) + LENGTH(RAM);    /* end of RAM */
/* Generate a link error if heap and stack don't fit into RAM */
_Min_Heap_Size = 0x200;      /* required amount of heap  */
_Min_Stack_Size = 0x400; /* required amount of stack */
```

下面这段则是关于各个 SECTION（段） 的定义

```ld
/* Define output sections */
SECTIONS
{
  /* The startup code goes first into FLASH */
  .isr_vector : /* 中断向量表 */
  {
    . = ALIGN(4); /* 指示当前内容为 4 字节对齐，对齐只能是 2^n (n >=0, n 为整数) */
    /* 要求必须保留这个段，不能让链接器优化这部分内容 */
    KEEP(*(.isr_vector)) /* Startup code */
    . = ALIGN(4);
  } >FLASH /* 将其写入 FLASH 中 */
  /* 受制于篇幅，只分析这么多 */
}
```

#### LMA, VMA，以及 `HardFault` 破案

这个时候我们之前提到的 VMA 和 LMA 的概念就派上用场了：

简单点说，LMA 决定了程序加载到内存中的位置，VMA 决定了程序运行时的位置。
此外，当 LMA == VMA 时，将不会执行从 Flash 复制值到 RAM 的操作，
而当 LMA != VMA 时则会复制值到 RAM 中。
那么这有什么重要的呢？

还记得我们在查看二进制内存分析的时候提到的么？
Zig 编译产物，LMA == VMA，因此不会将 Flash 内容复制到 RAM 中，
当我们查看内存分析时，
我们可以发现 Zig 编译的片段有部分内容在 PhysAddr 为 `0x2000 xxxx` 的区域，
而实际上这块区域属于 SRAM，SRAM 属于易失存储器，因此上电之后值必然是随机的，
同时也就必然导致 `__init_array_start` 数组中的值是随机的，
单片机尝试调用那里的函数就是在找死，最后也就触发 `HardFault`，因此解决方法也很简单。

我们之前提到了 `.init_array` 和 `.fini_array`，那么我们如何修改链接脚本呢？
实际上只需要在 `.rodata` 后面跟上：

```ld
.init_array :
{
  . = ALIGN(4);
  PROVIDE_HIDDEN (__init_array_start = .);
  KEEP(*(SORT(.init_array.*)))
  KEEP(*(.init_array*))
  PROVIDE_HIDDEN (__init_array_end = .);
  . = ALIGN(4);
} >FLASH

.fini_array :
{
  . = ALIGN(4);
  PROVIDE_HIDDEN (__fini_array_start = .);
  KEEP(*(SORT(.fini_array.*)))
  KEEP(*(.fini_array*))
  PROVIDE_HIDDEN (__fini_array_end = .);
  . = ALIGN(4);
} >FLASH
```

从而保证把烧录的东西存到 FLASH 即可。此时再编译烧录，就不会触发 `HardFault` 了。

此外我们发现 Makefile 的版本没有提供 `__preinit_array_start` 和 `__init_array_start`，
它只调用了 `_init()`，
因此其实也可以把汇编启动文件的 `bl __libc_init_array` 换成 `bl _init`，效果是一样的，不用改链接脚本。

此外我们来看下两个文件的大小吧：

```bash
❯ size $zig_elf  
   text    data     bss     dec     hex filename
  13192    1640     496   15328    3be0 zig-out/bin/zig-test.elf

❯ size $make_elf
   text    data     bss     dec     hex filename
   8148      12    1692    9852    267c HAL_Driver/build-make/zig-test.elf
```

可以发现大概大了 5KB 左右，如果你的板子内存杠杠的话用 Zig 完全没问题：

```python
Python 3.14.2 (main, Jan  2 2026, 14:27:39) [GCC 15.2.1 20251112] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> (15328 - 9852) / 1024
5.34765625
```

### 加入 Zig 代码

接下来我们来写 `src/main.zig`：

```zig
const hal = @cImport({
    @cDefine("STM32G431xx", {});
    @cDefine("USE_HAL_DRIVER", {});
    @cInclude("main.h");
});

export fn zigMain() void {
    while (true) {
        hal.HAL_GPIO_WritePin(hal.LED1_GPIO_Port, hal.LED1_Pin, hal.GPIO_PIN_SET);
        hal.HAL_Delay(1000);
        hal.HAL_GPIO_WritePin(hal.LED1_GPIO_Port, hal.LED1_Pin, hal.GPIO_PIN_RESET);
        hal.HAL_Delay(1000);
    }
}
```

然后再修改 `Core/Src/main.c` 并启用 `BUILD_BY_ZIG` 宏：

```c
/* USER CODE BEGIN PD */
/// NOTE: 这两个是互斥的
/// NOTE: BUILD_BY_ZIG 表示用 zig 构建，点灯代码在 src/main.zig 里
/// NOTE: BUILD_BY_EIDE 默认表示用 EIDE 构建，点灯代码在这个文件里
// #define BUILD_BY_EIDE
#define BUILD_BY_ZIG
// USER CODE END PD
```

接下来运行 `zig build` 并烧录二进制文件，可以观察到 LED1 闪烁。

```bash
# 由于某些原因，似乎 verify 会导致烧录失败，暂时没查明是什么原因
❯ /usr/bin/openocd -s $(pwd) -f interface/cmsis-dap.cfg -f target/stm32g4x.cfg -c "program $(pwd)/zig-out/bin/zig-test.elf " -c "reset run" -c "exit"
Open On-Chip Debugger 0.12.0-01004-g9ea7f3d64-dirty (2025-11-12-08:18)
Licensed under GNU GPL v2
For bug reports, read
        http://openocd.org/doc/doxygen/bugs.html
Info : auto-selecting first available session transport "swd". To override use 'transport select <transport>'.
Info : CMSIS-DAP: SWD supported
Info : CMSIS-DAP: JTAG supported
Info : CMSIS-DAP: FW Version = 1.0
Info : CMSIS-DAP: Interface Initialised (SWD)
Info : SWCLK/TCK = 1 SWDIO/TMS = 1 TDI = 1 TDO = 1 nTRST = 0 nRESET = 1
Info : CMSIS-DAP: Interface ready
Info : clock speed 2000 kHz
Info : SWD DPIDR 0x2ba01477
Info : [stm32g4x.cpu] Cortex-M4 r0p1 processor detected
Info : [stm32g4x.cpu] target has 6 breakpoints, 4 watchpoints
Info : starting gdb server for stm32g4x.cpu on 3333
Info : Listening on port 3333 for gdb connections
[stm32g4x.cpu] halted due to debug-request, current mode: Thread 
xPSR: 0x01000000 pc: 0x08000468 msp: 0x20008000
** Programming Started **
Info : device idcode = 0x20036468 (STM32G43/G44xx - Rev 'unknown' : 0x2003)
Info : RDP level 0 (0xAA)
Info : flash size = 128 KiB
Info : flash mode : single-bank
Warn : Adding extra erase range, 0x080033f8 .. 0x080037ff
Info : device idcode = 0x20036468 (STM32G43/G44xx - Rev 'unknown' : 0x2003)
Info : RDP level 0 (0xAA)
Info : OTP size is 1024 bytes, base address is 0x1fff7000
Warn : no flash bank found for address 0x2000005c
** Programming Finished **
```

现象如下面视频：

<video width="100%" height="100px" controls>
  <source src="/images/build-up-zig-dev-env-on-stm32g431/[ZIG-BUILD]-Success.mp4" type="video/mp4">
</video>


## 附录

### 对链接过程和内存分配的更加细致的观察

现在我们知道了 `ENTRY` 指定了程序的入口为 `Reset_Handler`，
也就是我们查看堆栈时第一个执行的函数。
理论上来说 `Reset_Handler` 是程序的入口地址，
但似乎 Zig 会自带一套东西
（这段内容我暂时不清楚，有人说是 libc，但我在 `build.zig` 里面已经禁用了）
所以它会先初始化 C 运行时（即初始化堆栈等）：

```bash
# 这里需要四字节对齐，因此不是 grep 08000251，下同
❯ $aod -S $zig_elf | grep -i 20 "08000250"
08000250 <_mainCRTStartup>:
```

而在 Makefile 编译的版本中，就的的确确是 `Reset_Handler` 在文件入口处：

```bash
❯ $aod -S $make_elf | grep -i "8001ba8"
08001ba8 <Reset_Handler>:
 8001ba8:       480d            ldr     r0, [pc, #52]   @ (8001be0 <LoopForever+0x2>)
```

由于 `Reset_Handler` 就在汇编启动文件中躺着，我们也可以来看下是什么情况：

```asm
Reset_Handler:
  ldr   r0, =_estack
  mov   sp, r0          /* set stack pointer */
  
/* Call the clock system initialization function.*/
    bl  SystemInit

/* Copy the data segment initializers from flash to SRAM */
  ldr r0, =_sdata
  ldr r1, =_edata
  ldr r2, =_sidata
  movs r3, #0
  b	LoopCopyDataInit
```

可以看到它做的事情就是初始化堆栈，
这和 Zig 的 `_mainCRTStartup` 所做的事情一致。
以及和 Zig 不同的：调用 `SystemInit` 为下一步做准备。
此外请注意这一句：

`/* Copy the data segment initializers from flash to SRAM */`

这也是我们上面分析出来错误的一环，可以得知默认行为是会将 `_sdata` 等字段从 Flash 复制到 RAM，而我们的 `.init_array` 和 `.fini_array` 由于没有显式声明导致读取了 RAM 的垃圾值。

而通过对 `_mainCRTStartup` 的进一步抓包，我们可以观察到：

```bash
❯ $aod -S $zig_elf | grep -i -A 42 "08000250"
08000250 <_mainCRTStartup>:
 8000250:       4b17            ldr     r3, [pc, #92]   @ (80002b0 <_mainCRTStartup+0x60>)
 8000252:       2b00            cmp     r3, #0
 8000254:       bf08            it      eq
 8000256:       4b13            ldreq   r3, [pc, #76]   @ (80002a4 <_mainCRTStartup+0x54>)
 8000258:       469d            mov     sp, r3
 800025a:       f7ff fff5       bl      8000248 <_stack_init>
 800025e:       2100            movs    r1, #0
 8000260:       468b            mov     fp, r1
 8000262:       460f            mov     r7, r1
 8000264:       4813            ldr     r0, [pc, #76]   @ (80002b4 <_mainCRTStartup+0x64>)
 8000266:       4a14            ldr     r2, [pc, #80]   @ (80002b8 <_mainCRTStartup+0x68>)
 8000268:       1a12            subs    r2, r2, r0
 800026a:       f000 f878       bl      800035e <memset>
 800026e:       4b0e            ldr     r3, [pc, #56]   @ (80002a8 <_mainCRTStartup+0x58>)
 8000270:       2b00            cmp     r3, #0
 8000272:       d000            beq.n   8000276 <_mainCRTStartup+0x26>
 8000274:       4798            blx     r3
 8000276:       4b0d            ldr     r3, [pc, #52]   @ (80002ac <_mainCRTStartup+0x5c>)
 8000278:       2b00            cmp     r3, #0
 800027a:       d000            beq.n   800027e <_mainCRTStartup+0x2e>
 800027c:       4798            blx     r3
 800027e:       2000            movs    r0, #0
 8000280:       2100            movs    r1, #0
 8000282:       0004            movs    r4, r0
 8000284:       000d            movs    r5, r1
 8000286:       480d            ldr     r0, [pc, #52]   @ (80002bc <_mainCRTStartup+0x6c>)
 8000288:       2800            cmp     r0, #0
 800028a:       d002            beq.n   8000292 <_mainCRTStartup+0x42>
 800028c:       480c            ldr     r0, [pc, #48]   @ (80002c0 <_mainCRTStartup+0x70>)
 800028e:       f000 f800       bl      8000292 <_mainCRTStartup+0x42>
 8000292:       f000 f86d       bl      8000370 <__libc_init_array>
 8000296:       0020            movs    r0, r4
 8000298:       0029            movs    r1, r5
 800029a:       f000 f90f       bl      80004bc <main>
 800029e:       f000 f88b       bl      80003b8 <exit>
 80002a2:       bf00            nop
 80002a4:       00080000        .word   0x00080000
        ...
 80002b4:       2000005c        .word   0x2000005c
 80002b8:       2000024c        .word   0x2000024c
        ...
```

不过由于 Zig 的入口点是 `_mainCRTStartup` 
（覆盖了链接脚本的 `ENTRY`， zig lld 有自己的想法），
那么可以推断 Zig 下其实会先使用自带的初始化方式（即 `_mainCRTStartup`），
然后再进行抓包之后发现这一段：

```
08000444 <frame_dummy>:
 8000444:       b508            push    {r3, lr}
 8000446:       4b05            ldr     r3, [pc, #20]   @ (800045c <frame_dummy+0x18>)
 8000448:       b11b            cbz     r3, 8000452 <frame_dummy+0xe>
 800044a:       4905            ldr     r1, [pc, #20]   @ (8000460 <frame_dummy+0x1c>)
 800044c:       4805            ldr     r0, [pc, #20]   @ (8000464 <frame_dummy+0x20>)
 800044e:       f000 f800       bl      8000452 <frame_dummy+0xe>
 8000452:       e8bd 4008       ldmia.w sp!, {r3, lr}
 8000456:       f7ff bfcf       b.w     80003f8 <register_tm_clones>
 800045a:       bf00            nop
 800045c:       00000000        .word   0x00000000
 8000460:       2000019c        .word   0x2000019c
 8000464:       08000248        .word   0x08000248

08000468 <Reset_Handler>:

    .section    .text.Reset_Handler
        .weak   Reset_Handler
        .type   Reset_Handler, %function
```

注意 `frame_dummy` 这个函数并没有 `bl` 到 `Reset_Handler` 下面的函数，
且对其他汇编函数的分析（我这里就不全贴上来了，感兴趣的读者自己 dump 一下），
那么根据汇编语句默认顺序执行的特点，很容易得知 Zig 编译的产物会调用两次初始化函数：
`_mainCRTStartup` 和默认的 `Reset_Handler`。

但这里唯一无法解释的是为什么不会直接从：
`_mainCRTStartup` 的 `bl 80004bc <main>` 开始一路执行到结束？
这个问题我打算挖个坑，可能永远都不会更新（笑）


### Zig 语言的一些介绍

和 Python 的 `import this` 一样，Zig 也有自己的 Zig 之禅。

```bash
❯ zig zen

 * Communicate intent precisely.
 * Edge cases matter.
 * Favor reading code over writing code.
 * Only one obvious way to do things.
 * Runtime crashes are better than bugs.
 * Compile errors are better than runtime crashes.
 * Incremental improvements.
 * Avoid local maximums.
 * Reduce the amount one must remember.
 * Focus on code rather than style.
 * Resource allocation may fail; resource deallocation must succeed.
 * Memory is a resource.
 * Together we serve the users.
```

对于 Zig 来说，我个人认为最重要的一点是官网注明的：

> No hidden control flow. 
> 
> 没有隐式控制流。
> 
> No hidden memory allocations. 
> 
> 没有隐式内存分配。
> 
> No preprocessor, no macros.
> 
> 没有预处理，没有宏。

没有宏这点我持保留意见，
毕竟 Rust 的宏超级强大（虽然代价是编译比较慢），
但 Zig 引入了 `comptime` 的概念，
这种机制允许你对一些语句进行编译时计算，和写普通代码区别不大。

不过 C 的宏（尤其是宏函数）有的时候确实会造成一些灾难，
我个人做法就是每个变量都跟 PTSD 一样的疯狂加括号。

以及对于 C/C++ 生态（如果导入源码或者 vcpkg 也能算生态的话）的无缝衔接：

> Use Zig as a zero-dependency, drop-in C/C++ compiler that supports cross-compilation out-of-the-box.
> 
> 将 Zig 作为零依赖、即插即用的 C/C++ 编译器使用，支持开箱即用的跨编译。
> 
> Leverage zig build to create a consistent development environment across all platforms.
> 
> 利用 zig build 创建跨所有平台的统一开发环境。
> 
> Add a Zig compilation unit to C/C++ projects, exposing the rich standard library to your C/C++ code.
> 
> 向 C/C++ 项目添加 Zig 编译单元，将丰富的标准库暴露给你的 C/C++ 代码。

Zig 有个 `@cImport()` 和 `@cInclude()` 函数，可以导入 C 头文件，
这意味着零成本集成 C/C++ 生态，也是我最喜欢的一点，
没有 FFI 的开销，这对于嵌入式环境来说无疑是十分优秀的。

显式优于隐式的设计思想是我个人觉得 Zig 非常优秀的一点，这意味着下面的 C 语言行为将不复存在：

```c
#include <stdio.h>

int return_int() {
    char a = '0';
    // 甚至警告都不会触发，直接就给你转换了
    return a;
}

int main() {
    int uninit_var;
    printf("未初始化变量值: %d\n", uninit_var);  // 编译器警告
    
    // 垃圾值
    if (uninit_var > 10) {
        printf("条件成立\n");
    }

    int a = return_int();
    printf("return_int() 返回值: %d\n", a);

    return 0;
}
```

```bash
# 甚至你要自己用 -Wall 选项才会开启警告
# 如果开发习惯不好，对这些没有规范，可以想象会造成多少潜在的运行时问题
# 相信大部分人用 Keil 都是只要不是 1 error(s) 就心满意足了
# 不影响编译就啥都不管了
❯ gcc -Wall -Wextra -o test test.c
test.c: 在函数‘main’中:
test.c:11:5: 警告：‘uninit_var’未经初始化被使用 [-Wuninitialized]
   11 |     printf("未初始化变量值: %d\n", uninit_var);  // 编译器警告
      |     ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
test.c:10:9: 附注：‘uninit_var’在此声明
   10 |     int uninit_var;
      |         ^~~~~~~~~~
```

又或者是一些其他有的没的，
比如隐式类型转换，或者是数组越界只会触发编译器警告而非编译不通过，
在 Zig 里面这些问题都能得到最大程度的避免。

更多详细的内容请参考[官方文档][ziglang-doc]。

下面是一段 Zig 的示例代码（摘自官网）：

```zig
const std = @import("std");
const parseInt = std.fmt.parseInt;

test "parse integers" {
    const input = "123 67 89,99";
    const gpa = std.testing.allocator;

    var list: std.ArrayList(u32) = .empty;
    // Ensure the list is freed at scope exit.
    // Try commenting out this line!
    defer list.deinit(gpa);

    var it = std.mem.tokenizeAny(u8, input, " ,");
    while (it.next()) |num| {
        const n = try parseInt(u32, num, 10);
        try list.append(gpa, n);
    }

    const expected = [_]u32{ 123, 67, 89, 99 };

    for (expected, list.items) |exp, actual| {
        try std.testing.expectEqual(exp, actual);
    }
}
```

以及我自己在做的玩具 Zig 项目：

```zig
pub const ColorType = enum { R, G, B };

// 错误是一种枚举类型，你无法在错误里面捎带太多信息，
// 这种返回值的错误处理方式延续了 C 语言的做法，
// 但是 Zig 会强制要求你处理错误，C 不会，
// 相信大部分人应该没用过 `printf` 的返回值吧。
pub const ColorError = error{
    // used for formation of RGB in PPM file format
    NotExpectedBufferSize,
};

pub const Color = struct {
    R: u8 = 0, // zig 支持给结构体加默认值
    G: u8 = 0,
    B: u8 = 0,
    MaxColorValue: u8 = 255,

    // 以及结构体内部可以写函数/方法
    pub fn init() Color {
        return .{};
    }

    pub fn setMaxColorValue(self: *Color, value: u8) void {
        self.MaxColorValue = value;
    }

    pub fn setPixel(self: *Color, color: ColorType, value: u8) void {
        switch (color) {
            ColorType.R => self.R = value,
            ColorType.G => self.G = value,
            ColorType.B => self.B = value,
        }
    }

    pub fn toString(self: Color, buffer: []u8) !void { 
        // !void 表示一个错误联合类型，Union[void, Error]
        // 也就是说正常情况下返回 void，否则抛出 Error
        if (buffer.len != 14) {
            log.err("Expected a buffer: [14]u8, got {d}", .{buffer.len});
            return ColorError.NotExpectedBufferSize;
        }
        _ = try fmt.bufPrint(buffer, "{d:3} {d:3} {d:3}   ", .{ self.R, self.G, self.B });
    }

    pub fn fromArray(self: *Color, pixelUnit: []const u8) !void {
        const colorSequence = [_]ColorType{ .R, .G, .B };

        for (pixelUnit, 0..) |origin, currentColorIdx| {
            var value: u8 = origin;
            if (value > self.MaxColorValue) {
                log.warn("Got a number bigger than MaxColorValue:\n\t" ++
                    "Number: {d}, MaxColorValue: {d}\n" ++
                    "Set to MaxColorValue.", .{ value, self.MaxColorValue });
                value = self.MaxColorValue;
            }

            self.setPixel(colorSequence[currentColorIdx], value);
        }
    }

    // zig 的测试用例
    // 这里表示针对 setMaxColorValue 函数的测试用例
    test setMaxColorValue {
        var color = Color.init();
        color.setMaxColorValue(20);
        try testing.expect(color.MaxColorValue == 20);
    }

    test toString {
        var color = Color.init();
        var arr = [_]u8{ 255, 255, 20 };
        // 如果没有初始化，那么必须要指定 undefined，以告诉编译器你还没初始化
        var buf: [14]u8 = undefined;

        try color.fromArray(&arr);
        try color.toString(&buf);
        try testing.expect(mem.eql(u8, &buf, "255 255  20   "));

        var buf2: [1]u8 = undefined;
        const err = color.toString(&buf2);
        try testing.expectError(ColorError.NotExpectedBufferSize, err);
    }

    test fromArray {
        var color = Color.init();
        var arr = [_]u8{ 255, 255, 20 };

        try color.fromArray(&arr);
        try testing.expect(color.R == 255 and color.G == 255 and color.B == 20);
    }
};
```

此外 Zig 作者 Andrew Kelley 的野心十分大，
他甚至想替换掉 llvm 自己做编译优化，实现一个平台无关的通用语言。
不过目前还是 llvm，也许这就是为什么 Zig 能横跨多端的原因。
我看好这门语言，但现在还不是时候（不稳定），期待它未来会有更好的发展。

这里需要注意的是，
Zig 是一个还没 1.0 的语言，并且 0.16 还大改了 0.15 的一些 API，
这意味着你必须要固定在一个版本做开发，尽量不要追新。
我个人建议是在个人小项目上尝鲜就好，暂时不要进生产环境，
哪怕语法再优秀，理念再先进，不稳定都是白搭，此外：

> 1.0 will come out when it's "ready" (quoted from Andrew Kelley). The Zig core team doesn't want to rush to 1.0 and wants to ensure everything is great (so that they regret as few decisions as possible when the first "language stable" release is actually out and you can't really change stuff anymore).
> On GitHub, there was once a milestone of (bigger) issues that need to be fixed before 1.0. I think that included stuff like formal specification of the Zig programming language, making the main Zig executable no longer depend on LLVM for as much stuff as possible (maybe not the best optimizations, but faster compilations speeds, incremental compilation etc.), a full audit of the standard library + compiler-rt (ensuring stuff is actually usable etc.) and I'm sure I forgot thousand other things.
> Suffice it to say, it will not come out in the next year.

这意味着 1.0 大概是遥遥无期的。
详细内容见我在 Codeberg 提出的 [issue][codeberg-ziglang-issue]

---

<p style="display:none">图片链接：</p>

[CubeMX工具链选择]: /images/build-up-zig-dev-env-on-stm32g431/CubeMX工具链选择.png
[CubeMX基础配置1]: /images/build-up-zig-dev-env-on-stm32g431/CubeMX的一些基础配置(1).png
[CubeMX基础配置2]: /images/build-up-zig-dev-env-on-stm32g431/CubeMX的一些基础配置(2).png
[蓝桥杯板子 LED 原理图]: /images/build-up-zig-dev-env-on-stm32g431/蓝桥杯板子LED原理图.png
[蓝桥杯板子 BOOT0 配置]: /images/build-up-zig-dev-env-on-stm32g431/蓝桥杯板子BOOT0配置.png
[C 语言编译过程]: /images/build-up-zig-dev-env-on-stm32g431/C语言编译过程.png
[MemoryView-HFSR-DEBUG]: /images/build-up-zig-dev-env-on-stm32g431/MemoryView-HFSR-DEBUG.png
[ZIG-DEBUG-HardFault]: /images/build-up-zig-dev-env-on-stm32g431/[ZIG-DEBUG]-HardFault.png
[ZIG-DEBUG-HardFault-StackTrace]: /images/build-up-zig-dev-env-on-stm32g431/[ZIG-DEBUG]-HFStackTrace.png
[STM32-CortexM4-Ref-SCB-HFSR]: /images/build-up-zig-dev-env-on-stm32g431/STM32-CortexM4-编程手册-SCB-HFSR.png
[STM32-CortexM4-Ref-SCB-CFSR]: /images/build-up-zig-dev-env-on-stm32g431/STM32-CortexM4-编程手册-SCB-CFSR.png
[STM32-CortexM4-Ref-CFSR-UFSR]: /images/build-up-zig-dev-env-on-stm32g431/STM32-CortexM4-编程手册-SCB-CFSR-UFSR.png
[STM32-CortexM4-Ref-EXECRETURN]: /images/build-up-zig-dev-env-on-stm32g431/STM32-CortexM4-编程手册-EXECRETURN.png
[STM32-参考手册-NVIC优先级表]: /images/build-up-zig-dev-env-on-stm32g431/STM32-参考手册-NVIC优先级表.png
[STM32-参考手册-内存布局]: /images/build-up-zig-dev-env-on-stm32g431/STM32-参考手册-内存布局.png
[STM32-参考手册-BOOT配置]: /images/build-up-zig-dev-env-on-stm32g431/STM32-参考手册-BOOT配置.png
[CortexM4权威指南-SCB介绍]: /images/build-up-zig-dev-env-on-stm32g431/CortexM4权威指南-SCB介绍.png
[CortexM4权威指南-SCB-HFSR等寄存器]: /images/build-up-zig-dev-env-on-stm32g431/CortexM4权威指南-HFSR等寄存器.png
[CortexM4权威指南-复位流程]: /images/build-up-zig-dev-env-on-stm32g431/CortexM4权威指南-复位流程.png
[ZIG-BUILD-SUCCESS]: /images/build-up-zig-dev-env-on-stm32g431/[ZIG-BUILD]-Success.mp4

<p style="display:none">参考资料：</p>

[ziglang]: https://ziglang.org/
[ziglang-doc]: https://ziglang.org/documentation/0.15.2/
[ziglang-download]: https://ziglang.org/download/
[codeberg-ziglang-issue]: https://codeberg.org/ziglang/zig/issues/30678
[stm32-zig-porting-guide]: https://github.com/haydenridd/stm32-zig-porting-guide/
[stm32-hello-world-zig]: https://www.weskoerber.com/posts/blog/stm32-zig-1/
[stm32-svd-file]: https://github.com/modm-io/cmsis-svd-stm32/blob/main/stm32g4/STM32G431.svd
[Vscode-Cortex-Debug-Config-Guide]: https://timye-development.readthedocs.io/en/latest/
[impl-of-__libc_init_array-1]: https://web.archive.org/web/20161113155513/http://newlib.sourcearchive.com/documentation/1.18.0/init_8c-source.html
[impl-of-__libc_init_array-2]: https://static.grumpycoder.net/pixel/uC-sdk-doc/initfini_8c_source.html
[cortexm4-xpsr]: https://blog.csdn.net/kouxi1/article/details/122914131
[lma-vma]: https://www.cnblogs.com/blogernice/articles/9856216.html
[self-template-opensource]: https://github.com/aliferne/STM32G431-Zig-Framework

