const cImport = @import("cImport.zig");
const hal = cImport.hal;
const lcd = @import("lcd.zig");

pub fn main() void {
    while (true) {
        hal.HAL_GPIO_TogglePin(hal.LED1_GPIO_Port, hal.LED1_Pin);
        hal.HAL_Delay(1000);
    }
}
