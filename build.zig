const std = @import("std");
const Module = std.Build.Module;
const Compile = std.Build.Step.Compile;

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
            .cpu_features_add = std.Target.arm.featureSet(
                &[_]std.Target.arm.Feature{.fp_armv8d16sp},
            ),
        },
    });

    const exec_name = "zig-test";
    // 优化，有四个等级可选，这里默认
    const optimize = b.standardOptimizeOption(.{});

    // 加入模块
    const mod = b.addModule(exec_name, .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = false,
        .single_threaded = true, // 单线程
        .sanitize_c = .off, // 移除 C 语言的 UBSAN 运行时库（避免二进制文件膨胀）
    });

    // 加入可执行文件
    const exe = b.addExecutable(.{
        .name = exec_name ++ ".elf", // 生成 ${exec_name}.elf
        .root_module = mod,
        .linkage = .static, // 静态链接，我们手动指定要链接什么文件
    });

    if (b.option(bool, "NEWLIB_PRINTF_FLOAT", "Force newlib to include float support for printf()")) |_| {
        // -u _printf_float 使之支持打印浮点数
        exe.forceUndefinedSymbol("_printf_float");
    }

    const STM32_Driver_Path = "HAL_Driver";

    addCRTFiles(b, mod);
    addIncludes(b, mod, STM32_Driver_Path);
    // 汇编启动文件
    mod.addAssemblyFile(b.path(b.fmt("{s}/startup_stm32g431xx.s", .{STM32_Driver_Path})));
    // 源文件
    addSources(b, mod, STM32_Driver_Path);

    addCMacros(mod);
    // 加入链接选项
    addLinkerDependencies(b, exe);
    // 生成 elf 文件
    b.installArtifact(exe);

    // 烧录配置
    const interface_cfg = "interface/cmsis-dap.cfg";
    const target_cfg = "target/stm32g4x.cfg";
    // this root must success
    const build_root = b.build_root.path orelse unreachable;
    const flash_run = b.addSystemCommand(&.{
        "/usr/bin/openocd",
        "-f",
        interface_cfg,
        "-f",
        target_cfg,
        "-c",
        b.fmt("program {s}/zig-out/bin/{s}", .{ build_root, exec_name ++ ".elf" }),
        "-c",
        "reset run",
        "-c",
        "exit",
    });
    const flash_step = b.step("flash", "Flash the code to the target");
    // 此处借助 b.getInstallStep 确保已经生成了 zig-test.elf 之后，才执行烧录
    // installArtifact 会把安装步骤添加到 getInstallStep 中
    flash_run.step.dependOn(b.getInstallStep());
    flash_step.dependOn(&flash_run.step);
}

/// add Include Paths
fn addIncludes(b: *std.Build, mod: *Module, STM32_Driver_Path: []const u8) void {
    // 这里就是加入 STM32 HAL 库的头文件
    // 需要强制编译时确认，否则会在 for 循环处报错（提示未确认的编译时值）
    const includePaths = comptime [_][]const u8{
        "Core/Inc",
        "Drivers/CMSIS/Include",
        "Drivers/STM32G4xx_HAL_Driver/Inc",
        "Drivers/STM32G4xx_HAL_Driver/Inc/Legacy",
        "Drivers/CMSIS/Device/ST/STM32G4xx/Include",
    };

    // 使用这种方式可以避免构造一大堆 {s}/
    for (includePaths) |path| {
        mod.addIncludePath(b.path(b.fmt("{s}/{s}", .{ STM32_Driver_Path, path })));
    }
}

/// add source files
fn addSources(b: *std.Build, mod: *Module, STM32_Driver_Path: []const u8) void {
    // 这里就是加入 STM32 HAL 库的源文件
    const sourceFiles = comptime [_][]const u8{
        // Core/Src
        "Core/Src/main.c",
        "Core/Src/usart.c",
        "Core/Src/gpio.c",
        "Core/Src/stm32g4xx_it.c",
        "Core/Src/stm32g4xx_hal_msp.c",
        "Core/Src/system_stm32g4xx.c",
        "Core/Src/sysmem.c",
        "Core/Src/syscalls.c",

        // HAL Drivers
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_pwr.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_pwr_ex.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_dma.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_dma_ex.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_gpio.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_exti.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_cortex.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_rcc.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_rcc_ex.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_flash.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_flash_ex.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_flash_ramfunc.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_uart.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_uart_ex.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_tim.c",
        "Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_tim_ex.c",
    };
    var formattedPaths: [sourceFiles.len][]const u8 = undefined;
    for (sourceFiles, 0..) |path, i| {
        formattedPaths[i] = b.fmt("{s}/{s}", .{ STM32_Driver_Path, path });
    }
    mod.addCSourceFiles(.{ .files = &formattedPaths });
}

/// add C Run-Time files
fn addCRTFiles(b: *std.Build, mod: *Module) void {
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
}

/// add C Macros (-Dxxx)
fn addCMacros(mod: *Module) void {
    // -DUSE_HAL_DRIVER
    mod.addCMacro("USE_HAL_DRIVER", "");
    // -DSTM32G431xx
    mod.addCMacro("STM32G431xx", "");
    // -DNEWLIB_PRINTF_FLOAT
    mod.addCMacro("NEWLIB_PRINTF_FLOAT", "");
}

/// add linker scripts and options for linker
fn addLinkerDependencies(b: *std.Build, exe: *Compile) void {
    // -Wl, --gc-sections
    exe.link_gc_sections = true;
    // -fdata-sections
    exe.link_data_sections = true;
    // -ffunction-sections
    exe.link_function_sections = true;

    // -TSTM32G431xx_FLASH.ld
    exe.setLinkerScript(b.path("STM32G431XX_FLASH.ld"));
}
