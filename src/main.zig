const cImport = @import("cImport.zig");
const hal = cImport.hal;
const lcd = @import("lcd.zig").LCD;

// do this: https://www.weskoerber.com/posts/blog/stm32-zig-1/
pub fn main() !void {
    var screen: lcd = .{};
    // try screen.init(.white, .black);
    try screen.functionTest();
    
    while (true) {
        hal.HAL_GPIO_TogglePin(hal.LED1_GPIO_Port, hal.LED1_Pin);
        hal.HAL_Delay(1000);
    }
}
