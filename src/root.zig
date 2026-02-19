const main = @import("main.zig");
const startup = @import("startup.zig");

/// 作为接口给 Core/Src/main.c 调用
export fn zigMain() void {
    main.main();
}
