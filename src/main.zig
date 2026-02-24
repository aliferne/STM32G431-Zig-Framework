const cImport = @import("cImport.zig");
const hal = cImport.hal;
const lcd = @import("lcd.zig").LCD;

// do this: https://www.weskoerber.com/posts/blog/stm32-zig-1/
pub fn main() !void {
    var screen: lcd = .{};
    screen.init();
    try screen.clear(lcd.Color.white);
    screen.setBackgroundColor(lcd.Color.white);
    screen.setTextColor(lcd.Color.black);
    hal.HAL_Delay(1000);
    try screen.clear(lcd.Color.white);
    // try screen.drawRect(20, 20, 60, 60);
    try screen.drawLine(10, 10, 150, lcd.Direction.horizontal);
    try screen.drawLine(10, 10, 150, lcd.Direction.vertical);

    try screen.displayChar(lcd.Line.line5, 20, 0);
    while (true) {
        hal.HAL_GPIO_TogglePin(hal.LED1_GPIO_Port, hal.LED1_Pin);
        hal.HAL_Delay(1000);
    }
}
