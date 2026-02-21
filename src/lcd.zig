//! This file only support stm32g431xx
//! Especially the lan qiao bei dev-kit

const hal = @cImport({
    @cDefine("STM32G431xx", {});
    @cDefine("USE_HAL_DRIVER", {});
    @cInclude("main.h");
});

/// pin should be assigned with port and pin number
const Pin = struct {
    port: u8,
    pin: u8,
};

pub const LCD = struct {
    /// self reference
    const Self = @This();
    pub const emptyLine = "                    ";
    pub const color = enum(u16) {
        black = 0x0000,
        white = 0xFFFF,
        grey = 0xF7DE,
        blue = 0x001F,
        blue2 = 0x051F,
        red = 0xF800,
        magenta = 0xF81F,
        green = 0x07E0,
        cyan = 0x07FF,
        yellow = 0xFFE0,
    };
    pub const line = enum(u8) {
        line0 = 0,
        line1 = 24,
        line2 = 48,
        line3 = 72,
        line4 = 96,
        line5 = 120,
        line6 = 144,
        line7 = 168,
        line8 = 192,
        line9 = 216,
    };
    pub const direction = enum(u8) {
        horizontal = 0,
        vertical = 1,
    };
    // CS = PB9
    // RS = PB8
    // WR = PB5
    // RD = PA8
    // DATA1 -> DATA16 => PC0~PC15(ALL)
    const CS = Pin{ .port = hal.GPIOB, .pin = hal.GPIO_PIN_9 };
    const RS = Pin{ .port = hal.GPIOB, .pin = hal.GPIO_PIN_8 };
    const WR = Pin{ .port = hal.GPIOB, .pin = hal.GPIO_PIN_5 };
    const RD = Pin{ .port = hal.GPIOA, .pin = hal.GPIO_PIN_8 };
    const DATA = Pin{
        .port = hal.GPIOC,
        .pin = hal.GPIO_PIN_All,
        // not sure if that works:
        // .pin = hal.GPIO_PIN_0 | hal.GPIO_PIN_1 |
        //     hal.GPIO_PIN_2 | hal.GPIO_PIN_3 |
        //     hal.GPIO_PIN_4 | hal.GPIO_PIN_5 |
        //     hal.GPIO_PIN_6 | hal.GPIO_PIN_7,
    };
    // instance variables
    _textColor: color = .black,
    _bgColor: color = .white,

    pub fn init() void {
        ctrlLinesConfig();
        // TODO:
    }

    pub fn setTextColor(self: Self, textColor: color) void {
        self._textColor = textColor;
    }

    pub fn setBackgroundColor(self: Self, bgColor: color) void {
        self._backColor = bgColor;
    }
    pub fn clearLine(self: Self, lineNumber: line) void {
        displayStringLine(lineNumber, emptyLine);
    }

    pub fn clear(clearColor: color) void {}
    pub fn setCursor(self: Self, x: u8, y: u8) void {
        writeRegister();
    }
    pub fn drawChar(x: u8, y: u8, char: u8) void {
        hal.__HAL_RCC_GPIOA_CLK_ENABLE();
    }
    pub fn displayChar() void {}
    pub fn displayStringLine() void {}
    pub fn setDisplayWindow() void {}
    pub fn windowModeDisable() void {}
    pub fn drawLine() void {}
    pub fn drawRect() void {}
    pub fn drawCircle() void {}
    pub fn drawMonoPict() void {}
    pub fn writeBMP() void {}
    pub fn drawBMP() void {}
    pub fn drawPicture() void {}
    pub fn writeRAM_Prepare() void {}
    pub fn writeRAM() void {}
    pub fn readRAM() void {}
    pub fn powerOn() void {}
    pub fn displayOn() void {}
    pub fn displayOff() void {}

    /// times: number of nops to execute
    inline fn nops(times: u8) void {
        inline for (0..times) |_| {}
    }

    /// configure bus (in mode)
    fn busIn() void {
        var gpioInitStruct: hal.GPIO_InitTypeDef = .{
            .Pin = DATA.pin,
            .Mode = hal.GPIO_MODE_INPUT,
            .Speed = hal.GPIO_SPEED_FREQ_VERY_HIGH,
            .Pull = hal.GPIO_NOPULL,
        };
        hal.GPIO_Init(DATA.port, &gpioInitStruct);
    }

    /// configure bus (out mode)
    fn busOut() void {
        var gpioInitStruct: hal.GPIO_InitTypeDef = .{
            .Pin = DATA.pin,
            .Mode = hal.GPIO_MODE_OUTPUT_PP,
            .Speed = hal.GPIO_SPEED_FREQ_VERY_HIGH,
            .Pull = hal.GPIO_NOPULL,
        };
        hal.GPIO_Init(DATA.port, &gpioInitStruct);
    }

    /// initialize control lines
    fn ctrlLinesConfig() void {
        // set RCC
        hal.RCC.*.AHB2ENR |= (hal.RCC_AHB2ENR_GPIOAEN | hal.RCC_AHB2ENR_GPIOBEN | hal.RCC_AHB2ENR_GPIOCEN);
        _ = hal.RCC.*.AHB2ENR & (hal.RCC_AHB2ENR_GPIOAEN | hal.RCC_AHB2ENR_GPIOBEN | hal.RCC_AHB2ENR_GPIOCEN);

        var gpioInitStruct: hal.GPIO_InitTypeDef = .{
            .Pin = CS.pin,
            .Mode = hal.GPIO_MODE_OUTPUT_PP,
            .Speed = hal.GPIO_SPEED_FREQ_LOW,
            .Pull = hal.GPIO_NOPULL,
        };
        hal.HAL_GPIO_Init(CS.port, &gpioInitStruct);

        gpioInitStruct.Pin = RS.pin;
        hal.HAL_GPIO_Init(RS.port, &gpioInitStruct);

        gpioInitStruct.Pin = WR.pin;
        hal.HAL_GPIO_Init(WR.port, &gpioInitStruct);

        gpioInitStruct.Pin = RD.pin;
        hal.HAL_GPIO_Init(RD.port, &gpioInitStruct);
    }

    /// write data to the specific register
    fn writeRegister(addr: u8, data: u16) void {
        startTransmission();
        sendRegisterAddr(addr);
        writeBusData(data);
        endTransmission();
    }
    /// read data from the specific register
    fn readRegister(addr: u8) u16 {
        var readData: u16 = 0;

        startTransmission();
        sendRegisterAddr(addr);
        readData = readBusData();
        endTransmission();

        return readData;
    }

    // TODO: 下面的可能还存在问题
    pub fn writeRAMPrepared(self: *LCD) void {
        startTransmission();

        DATA.port.*.ODR = hal.R34;
        WR.port.*.BRR |= WR.pin;
        self.nops(3);
        WR.port.*.BSRR |= WR.pin;
        RS.port.*.BSRR |= RS.pin;
        self.nops(3);

        endTransmission();
    }

    pub fn LCD_WriteRAM(self: *LCD, RGB_Code: u16) void {
        CS.port.*.BRR |= CS.pin;
        RS.port.*.BSRR |= RS.pin;
        WR.port.*.BSRR |= WR.pin;

        writeBusData(RGB_Code);
        self.nops(3);

        endTransmission();
    }

    pub fn LCD_ReadRAM() u16 {
        var temp: u16 = 0;

        startTransmission();

        DATA.port.*.ODR = hal.R34;
        WR.port.*.BRR |= WR.pin;
        nops(3);
        WR.port.*.BSRR |= WR.pin;
        RS.port.*.BSRR |= RS.pin;

        temp = readBusData();

        endTransmission();

        return temp;
    }

    // I2C transfer protocol
    /// Start transmission by some initializations
    fn startTransmission() void {
        CS.port.*.BRR |= CS.pin; // chip select (set low)
        RS.port.*.BRR |= RS.pin; // register select (set low)
        WR.port.*.BSRR |= WR.pin; // write enable for writing addr (set high)
    }

    /// tell which register to write to
    fn sendRegisterAddr(addr: u8) void {
        writeBusData(@as(u16, addr));
        // // tell which register to write to
        // DATA.port.*.ODR = addr;
        // // wait for write to complete
        // WR.port.*.BRR |= WR.pin;
        // nops(3);
        // WR.port.*.BSRR |= WR.pin;
        // RS.port.*.BSRR |= RS.pin;
    }

    /// read data from the bus
    fn readBusData() u16 {
        var readData: u16 = 0;
        busIn();
        RD.port.*.BRR |= RD.pin;
        nops(3);
        readData = DATA.port.*.IDR;
        RD.port.*.BSRR |= RD.pin;

        busOut();
        return readData;
    }

    /// write data to the bus
    fn writeBusData(data: u16) void {
        DATA.port.*.ODR = data;
        WR.port.*.BRR |= WR.pin;
        nops(3);
        WR.port.*.BSRR |= WR.pin;
        RS.port.*.BSRR |= RS.pin;
    }

    /// End transmission by setting chip select high
    fn endTransmission() void {
        CS.port.*.BSRR |= CS.pin;
    }
};
