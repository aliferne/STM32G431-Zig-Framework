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

/// error type for LCD operations
const LCDError = error{
    /// set cursor position error (smaller than 0 or larger than w, h)
    invalidCursorPos,
};

pub const LCD = struct {
    /// self reference
    const Self = @This();
    pub const emptyLine = "                    ";
    pub const height = 240;
    pub const width = 320;
    pub const totalPixels = height * width;
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
    CS: Pin = .{ .port = hal.GPIOB, .pin = hal.GPIO_PIN_9 },
    RS: Pin = .{ .port = hal.GPIOB, .pin = hal.GPIO_PIN_8 },
    WR: Pin = .{ .port = hal.GPIOB, .pin = hal.GPIO_PIN_5 },
    RD: Pin = .{ .port = hal.GPIOA, .pin = hal.GPIO_PIN_8 },
    DATA: Pin = .{
        .port = hal.GPIOC,
        .pin = hal.GPIO_PIN_All,
        // not sure if that works:
        // .pin = hal.GPIO_PIN_0 | hal.GPIO_PIN_1 |
        //     hal.GPIO_PIN_2 | hal.GPIO_PIN_3 |
        //     hal.GPIO_PIN_4 | hal.GPIO_PIN_5 |
        //     hal.GPIO_PIN_6 | hal.GPIO_PIN_7,
    },
    _textColor: color = .black,
    _bgColor: color = .white,

    pub fn init(self: Self) void {
        self.ctrlLinesConfig();
        // TODO:
    }

    pub fn setTextColor(self: Self, textColor: color) void {
        self._textColor = textColor;
    }

    pub fn setBackgroundColor(self: Self, bgColor: color) void {
        self._backColor = bgColor;
    }

    pub fn clearLine(self: Self, lineNumber: line) void {
        self.displayStringLine(lineNumber, emptyLine);
    }

    /// clear the screen with a specified color
    pub fn clear(self: Self, fillColor: color) void {
        self.setCursor(0, 0);
        self.prepareWriteGRAM();
        for (0..totalPixels) |_| {
            self.writeGRAM(fillColor);
        }
    }

    /// set the cursor position
    pub fn setCursor(self: Self, x: u8, y: u16) !void {
        // should be found when compiling
        comptime if ((x >= self.width or y >= self.height)) {
            return LCDError.invalidCursorPos;
        };
        self.writeRegister(32, x);
        self.writeRegister(33, y);
    }

    pub fn drawChar(self: Self, x: u8, y: u16, char: u8) void {}
    pub fn displayChar(self: Self) void {}
    pub fn displayStringLine(self: Self) void {}
    pub fn setDisplayWindow(self: Self) void {}
    pub fn windowModeDisable(self: Self) void {}
    pub fn drawLine(self: Self) void {}
    pub fn drawRect(self: Self) void {}
    pub fn drawCircle(self: Self) void {}
    pub fn drawMonoPict(self: Self) void {}
    pub fn writeBMP(self: Self) void {}
    pub fn drawBMP(self: Self) void {}
    pub fn drawPicture(self: Self) void {}
    pub fn powerOn(self: Self) void {}
    pub fn displayOn(self: Self) void {}
    pub fn displayOff(self: Self) void {}

    /// prepare for writing GRAM
    /// call this before call `writeGRAM`
    pub fn prepareWriteGRAM(self: Self) void {
        self.startTransmission();
        self.sendRegisterAddr(34);
        self.endTransmission();
    }

    pub fn writeGRAM(self: Self, pixelColor: color) void {
        self.startTransmission();
        self.writeBusData(@intFromEnum(pixelColor));
        self.endTransmission();
    }

    pub fn readGRAM(self: Self) u16 {
        var gramData: u16 = 0;

        self.startTransmission();
        self.sendRegisterAddr(34);
        gramData = readBusData();
        self.endTransmission();

        return gramData;
    }

    /// times: number of nops to execute
    inline fn nops(times: u8) void {
        inline for (0..times) |_| {}
    }

    /// configure bus (in mode)
    fn busIn(self: Self) void {
        const gpioInitStruct: hal.GPIO_InitTypeDef = .{
            .Pin = self.DATA.pin,
            .Mode = hal.GPIO_MODE_INPUT,
            .Speed = hal.GPIO_SPEED_FREQ_VERY_HIGH,
            .Pull = hal.GPIO_NOPULL,
        };
        hal.HAL_GPIO_Init(self.DATA.port, &gpioInitStruct);
    }

    /// configure bus (out mode)
    fn busOut(self: Self) void {
        const gpioInitStruct: hal.GPIO_InitTypeDef = .{
            .Pin = self.DATA.pin,
            .Mode = hal.GPIO_MODE_OUTPUT_PP,
            .Speed = hal.GPIO_SPEED_FREQ_VERY_HIGH,
            .Pull = hal.GPIO_NOPULL,
        };
        hal.HAL_GPIO_Init(self.DATA.port, &gpioInitStruct);
    }

    /// initialize control lines
    fn ctrlLinesConfig(self: Self) void {
        // set RCC
        hal.RCC.*.AHB2ENR |= (hal.RCC_AHB2ENR_GPIOAEN | hal.RCC_AHB2ENR_GPIOBEN | hal.RCC_AHB2ENR_GPIOCEN);
        _ = hal.RCC.*.AHB2ENR & (hal.RCC_AHB2ENR_GPIOAEN | hal.RCC_AHB2ENR_GPIOBEN | hal.RCC_AHB2ENR_GPIOCEN);

        var gpioInitStruct: hal.GPIO_InitTypeDef = .{
            .Pin = self.CS.pin,
            .Mode = hal.GPIO_MODE_OUTPUT_PP,
            .Speed = hal.GPIO_SPEED_FREQ_LOW,
            .Pull = hal.GPIO_NOPULL,
        };
        hal.HAL_GPIO_Init(self.CS.port, &gpioInitStruct);

        gpioInitStruct.Pin = self.RS.pin;
        hal.HAL_GPIO_Init(self.RS.port, &gpioInitStruct);

        gpioInitStruct.Pin = self.WR.pin;
        hal.HAL_GPIO_Init(self.WR.port, &gpioInitStruct);

        gpioInitStruct.Pin = self.RD.pin;
        hal.HAL_GPIO_Init(self.RD.port, &gpioInitStruct);
    }

    /// write data to the specific register
    fn writeRegister(self: Self, addr: u8, data: u16) void {
        self.startTransmission();
        self.sendRegisterAddr(addr);
        self.writeBusData(data);
        self.endTransmission();
    }
    /// read data from the specific register
    fn readRegister(self: Self, addr: u8) u16 {
        var readData: u16 = 0;

        self.startTransmission();
        self.sendRegisterAddr(addr);
        readData = readBusData();
        self.endTransmission();

        return readData;
    }

    // I2C transfer protocol
    /// Start transmission by some initializations
    fn startTransmission(self: Self) void {
        self.CS.port.*.BRR |= self.CS.pin; // chip select (set low)
        self.RS.port.*.BRR |= self.RS.pin; // register select (set low)
        self.WR.port.*.BSRR |= self.WR.pin; // write enable for writing addr (set high)
    }

    /// tell which register to write to
    fn sendRegisterAddr(self: Self, addr: u8) void {
        self.writeBusData(@as(u16, addr));
    }

    /// read data from the bus
    fn readBusData(self: Self) u16 {
        var readData: u16 = 0;
        self.busIn();

        self.RD.port.*.BRR |= self.RD.pin;
        nops(3);
        readData = self.DATA.port.*.IDR;
        self.RD.port.*.BSRR |= self.RD.pin;

        self.busOut();
        return readData;
    }

    /// write data to the bus
    fn writeBusData(self: Self, data: u16) void {
        self.DATA.port.*.ODR = data;
        self.WR.port.*.BRR |= self.WR.pin;
        nops(3);
        self.WR.port.*.BSRR |= self.WR.pin;
        self.RS.port.*.BSRR |= self.RS.pin;
        nops(3);
    }

    /// End transmission by setting chip select high
    fn endTransmission(self: Self) void {
        self.CS.port.*.BSRR |= self.CS.pin;
    }
};
