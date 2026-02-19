const hal = @cImport({
    @cDefine("STM32G431xx", {});
    @cDefine("USE_HAL_DRIVER", {});
    @cInclude("main.h");
});

pub fn main() void {
    while (true) {
        hal.HAL_GPIO_TogglePin(hal.LED1_GPIO_Port, hal.LED1_Pin);
        hal.HAL_Delay(1000);
    }
}
