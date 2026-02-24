//! This file only support stm32g431xx
//! Especially the lan qiao bei dev-kit

const hal = @cImport({
    @cDefine("STM32G431xx", {});
    @cDefine("USE_HAL_DRIVER", {});
    @cInclude("main.h");
});

const asciiFonts = struct {
    const raw = @embedFile("fonts.bin");
    // convert raw data to u16 array
    pub const data: []const u16 =
        @as([*]const u16, @ptrCast(@alignCast(raw.ptr)))[0..(raw.len / 2)];
    pub const cols = 24;
    pub const rows = 16;
    pub const fontSize = rows;
};

/// pin should be assigned with port and pin number
const Pin = struct {
    port: [*c]hal.GPIO_TypeDef,
    pin: u16,
};

/// LCD Struct,
/// contains the definition and methods of LCD,
/// always mind that in this setting (Initialization)
/// the origin is set to top right
///
/// ```
///              x
/// +------------<---· (origin)
/// |                |
/// |                v y
/// |                |
/// +----------------+
/// ```
pub const LCD = struct {
    /// self reference
    const Self = @This();
    pub const EmptyLine = "                    ";
    pub const LineHeight = 24;
    pub const Height = 240;
    pub const Width = 320;
    pub const TotalPixels = Height * Width;
    pub const Color = enum(u16) {
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
    pub const Line = enum(u8) {
        line0 = 0 * LineHeight,
        line1 = 1 * LineHeight,
        line2 = 2 * LineHeight,
        line3 = 3 * LineHeight,
        line4 = 4 * LineHeight,
        line5 = 5 * LineHeight,
        line6 = 6 * LineHeight,
        line7 = 7 * LineHeight,
        line8 = 8 * LineHeight,
        line9 = 9 * LineHeight,
    };
    pub const Direction = enum(u8) {
        horizontal = 0,
        vertical = 1,
    };
    pub const Err = error{
        InvalidCursorPositionError,
        InvalidAsciiCharError,
        MaxStrLenError,
    };
    // used for setting the voltage level of RS
    const WriteMode = enum(u8) {
        command = 0,
        data = 1,
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
    textColor: Color = .black,
    bgColor: Color = .white,

    pub fn init(self: Self) void {
        self.ctrlLinesConfig();
        var dummy: u16 = self.readRegister(0);
        if (dummy == 0x8230) {
            // pass
        } else {
            // self.ili9325_Init();
            self._REG_932X_Init();
            // self.REG_932X_Init();
        }
        dummy = self.readRegister(0);
        hal.HAL_Delay(50);
        // self.displayOn();
        //
        // _ = self;
        // hal.LCD_Init();
        // hal.LCD_SetBackColor(@intFromEnum(color.white));
        // hal.LCD_SetTextColor(@intFromEnum(color.black));
        // hal.LCD_DisplayChar(@intFromEnum(line.line0),1, '1');
    }

    pub fn setTextColor(self: *Self, textColor: Color) void {
        self.textColor = textColor;
    }

    pub fn setBackgroundColor(self: *Self, bgColor: Color) void {
        self.bgColor = bgColor;
    }

    pub fn clearLine(self: Self, lineNumber: Line) void {
        self.displayStringLine(lineNumber, EmptyLine);
    }

    /// clear the screen with a specified color
    pub fn clear(self: Self, fillColor: Color) !void {
        try self.setCursor(0, 0);
        self.prepareWriteGRAM();
        for (0..TotalPixels) |_| {
            self.writeGRAM(fillColor);
        }
    }

    /// set the cursor position
    pub fn setCursor(self: Self, x: u8, y: u16) Err!void {
        // should be found when compiling
        if ((x > Height) or (y > Width)) {
            // Can't use @compileError since x, y are runtime value
            // @compileError("Invalid cursor position");
            return Err.InvalidCursorPositionError;
        }
        self.writeRegister(32, x);
        self.writeRegister(33, y);
    }

    pub fn drawChar(self: Self, x: u8, y: u16, char: []const u16) !void {
        var xaddr: u8 = x;
        const mask: u16 = 1;

        try self.setCursor(xaddr, y);
        for (0..asciiFonts.cols) |idx| {
            self.prepareWriteGRAM();
            // if char[idx] == 1
            // render it with text color (show text)
            for (0..asciiFonts.rows) |i| {
                // should cast i to u16
                // otherwise Zig will regard it as u4 (LHS can express 0~15)
                // silly inference
                // by the way should use mask (u16)
                // if use 1, then Zig can't infer how many bits it can shift
                // comptime_int hasn't the bit info
                if ((char[idx] & (mask << @intCast(i))) == 0x00) {
                    self.writeGRAM(self.bgColor);
                } else {
                    self.writeGRAM(self.textColor);
                }
            }
            xaddr += 1;
            try self.setCursor(xaddr, y);
        }
    }

    pub fn displayChar(self: Self, lineNumber: Line, column: u16, char: u8) Err!void {
        // make char to index, should mark it as u16 otherwise integer ovf
        var idx: u16 = char;
        if (idx < 0x20) {
            return Err.InvalidAsciiCharError;
        }
        idx -= 0x20;
        const start: u16 = idx * asciiFonts.cols;
        try self.drawChar(@intFromEnum(lineNumber), column, asciiFonts.data[start..(start + asciiFonts.cols)]);
    }

    pub fn displayStringLine(self: Self, lineNumber: Line, string: []const u8) !void {
        const maxStrLen = Width / asciiFonts.fontSize;
        if (string.len > maxStrLen) {
            // Can't use since []const u8 is a runtime value
            // @compileError(
            //     \\ [in `displayStringLine`] string is too long,
            //     \\ it will be truncated to `maxStrLen` when running the program,
            //     \\ which may lead to undefined behavior.
            // );
        }

        // 相较于 C，
        // 这里如果越界会先触发 Zig 内置的错误，
        // 告诉你 index out of range，然后触发 HardFault
        for (0..@min(string.len, maxStrLen)) |i| {
            const idx = @as(u16, @intCast(i));
            try self.displayChar(lineNumber, (maxStrLen - idx) * asciiFonts.fontSize, string[idx]);
        }
    }
    /// Sets a display window
    pub fn setDisplayWindow(
        self: Self,
        x: u8,
        y: u16,
        height: u8,
        width: u16,
    ) !void {
        if (x >= height) {
            try self.writeRegister(80, x - height + 1);
        } else {
            try self.writeRegister(80, 0);
        }
        try self.writeRegister(81, x);

        if (y >= width) {
            try self.writeRegister(82, y - width + 1);
        } else {
            try self.writeRegister(82, 0);
        }
        try self.writeRegister(83, y);

        try self.setCursor(x, y);
    }

    /// Disables LCD Window mode
    pub fn windowModeDisable(self: Self) !void {
        try self.setDisplayWindow(239, 0x13F, 240, 320);
        try self.writeRegister(3, 0x1018);
    }

    pub fn drawLine(
        self: Self,
        xStart: u8,
        yStart: u16,
        length: u16,
        direction: Direction,
    ) !void {
        try self.setCursor(xStart, yStart);

        if (direction == Direction.horizontal) {
            self.prepareWriteGRAM();
            for (0..length) |_| {
                self.writeGRAM(self.textColor);
            }
        } else {
            for (0..length) |i| {
                const idx = @as(u8, @intCast(i));
                self.prepareWriteGRAM();
                self.writeGRAM(self.textColor);
                try self.setCursor(xStart + idx, yStart);
            }
        }
    }

    pub fn drawRect(
        self: Self,
        xStart: u8,
        yStart: u16,
        height: u8,
        width: u16,
    ) !void {
        try self.drawLine(xStart, yStart, width, Direction.horizontal);
        try self.drawLine((xStart + height), yStart, width, Direction.horizontal);

        try self.drawLine(xStart, yStart, height, Direction.vertical);
        try self.drawLine(xStart, (yStart - width + 1), height, Direction.vertical);
    }

    /// Displays a circle using Bresenham's algorithm
    pub fn drawCircle(self: Self, xPos: u8, yPos: u16, radius: u16) !void {
        var D: i32 = 3 - (@as(i32, radius) << 1);
        var curX: u32 = 0;
        var curY: u32 = radius;

        while (curX <= curY) {
            try self.setCursor(xPos + @as(u8, curX), yPos + curY);
            self.prepareWriteGRAM();
            self.writeGRAM(self.textColor);

            try self.setCursor(xPos + @as(u8, curX), yPos - curY);
            self.prepareWriteGRAM();
            self.writeGRAM(self.textColor);

            try self.setCursor(xPos - @as(u8, curX), yPos + curY);
            self.prepareWriteGRAM();
            self.writeGRAM(self.textColor);

            try self.setCursor(xPos - @as(u8, curX), yPos - curY);
            self.prepareWriteGRAM();
            self.writeGRAM(self.textColor);

            try self.setCursor(xPos + @as(u8, curY), yPos + curX);
            self.prepareWriteGRAM();
            self.writeGRAM(self.textColor);

            try self.setCursor(xPos + @as(u8, curY), yPos - curX);
            self.prepareWriteGRAM();
            self.writeGRAM(self.textColor);

            try self.setCursor(xPos - @as(u8, curY), yPos + curX);
            self.prepareWriteGRAM();
            self.writeGRAM(self.textColor);

            try self.setCursor(xPos - @as(u8, curY), yPos - curX);
            self.prepareWriteGRAM();
            self.writeGRAM(self.textColor);

            if (D < 0) {
                D += (@as(i32, curX) << 2) + 6;
            } else {
                D += ((@as(i32, curX) - @as(i32, curY)) << 2) + 10;
                curY -= 1;
            }
            curX += 1;
        }
    }

    // pub fn drawMonoPict(self: Self) void {}
    // pub fn powerOn(self: Self) void {}
    // pub fn displayOn(self: Self) void {}
    // pub fn displayOff(self: Self) void {}
    // pub fn writeBMP(self: Self) void {}
    // pub fn drawBMP(self: Self) void {}

    /// Displays a 16 color picture
    pub fn drawPicture(self: Self, picture: []const u8) !void {
        try self.setCursor(0, 0);
        self.prepareWriteGRAM();

        for (0..TotalPixels) |index| {
            const pixel = (@as(u16, picture[2 * index + 1]) << 8) | picture[2 * index];
            self.writeGRAM(@as(Color, @enumFromInt(pixel)));
        }
    }

    /// prepare for writing GRAM
    /// call this before call `writeGRAM`
    pub fn prepareWriteGRAM(self: Self) void {
        self.startTransmission();
        self.sendRegisterAddr(34);
        self.endTransmission();
    }

    pub fn writeGRAM(self: Self, pixelColor: Color) void {
        self.startTransmission();
        self.writeBusData(@intFromEnum(pixelColor), WriteMode.data);
        self.endTransmission();
    }

    pub fn readGRAM(self: Self) u16 {
        var gramData: u16 = 0;

        self.startTransmission();
        self.sendRegisterAddr(34);
        gramData = self.readBusData();
        self.endTransmission();

        return gramData;
    }

    /// times: number of nops to execute
    inline fn nops(times: u8) void {
        inline for (0..times) |_| {}
    }

    /// configure bus (in mode)
    fn busIn(self: Self) void {
        var gpioInitStruct: hal.GPIO_InitTypeDef = .{
            .Pin = self.DATA.pin,
            .Mode = hal.GPIO_MODE_INPUT,
            .Speed = hal.GPIO_SPEED_FREQ_VERY_HIGH,
            .Pull = hal.GPIO_NOPULL,
        };
        hal.HAL_GPIO_Init(self.DATA.port, &gpioInitStruct);
    }

    /// configure bus (out mode)
    fn busOut(self: Self) void {
        var gpioInitStruct: hal.GPIO_InitTypeDef = .{
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
        hal.RCC.*.AHB2ENR |= hal.RCC_AHB2ENR_GPIOAEN;
        hal.RCC.*.AHB2ENR |= hal.RCC_AHB2ENR_GPIOBEN;
        hal.RCC.*.AHB2ENR |= hal.RCC_AHB2ENR_GPIOCEN;

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

        self.busOut();
    }

    /// write data to the specific register
    fn writeRegister(self: Self, addr: u8, data: u16) void {
        self.startTransmission();
        self.sendRegisterAddr(addr);
        self.writeBusData(data, WriteMode.data);
        self.endTransmission();
    }
    /// read data from the specific register
    fn readRegister(self: Self, addr: u8) u16 {
        var readData: u16 = 0;

        self.startTransmission();
        self.sendRegisterAddr(addr);
        readData = self.readBusData();
        self.endTransmission();

        return readData;
    }

    // ILI932X Communication Protocol
    // Here we control the register
    // to assert(set) or unassert(unset) the voltage level
    // of the bus
    // BRR is Bit Reset Register
    // BSRR is Bit Set Reset Register
    // ODR is Output Data Register
    // e.g. Port.BRR  | Pin means to unassert the Pin (Pin = 0)
    //      Port.BSRR | Pin is to assert (Pin = 1)
    // the timing graph can be referred from ILI932X datasheet, chapter Interface Timing

    /// Start transmission by some initializations
    fn startTransmission(self: Self) void {
        self.CS.port.*.BRR |= self.CS.pin; // chip select (set low)
        self.RS.port.*.BSRR |= self.RS.pin; // RS = 1
        self.RD.port.*.BSRR |= self.RD.pin; // RD = 1
        self.WR.port.*.BSRR |= self.WR.pin; // WR = 1
    }

    /// tell which register to write to
    fn sendRegisterAddr(self: Self, addr: u8) void {
        self.writeBusData(@as(u16, addr), WriteMode.command);
    }

    /// read data from the bus
    fn readBusData(self: Self) u16 {
        var readData: u16 = 0;
        self.busIn();

        self.RD.port.*.BRR |= self.RD.pin;
        nops(3);
        // truncate a 32-bit register value to u16
        readData = @truncate(self.DATA.port.*.IDR);
        self.RD.port.*.BSRR |= self.RD.pin;

        self.busOut();
        return readData;
    }

    /// write data to the bus
    fn writeBusData(self: Self, data: u16, mode: WriteMode) void {
        if (mode == WriteMode.command) {
            self.RS.port.*.BRR |= self.RS.pin; // RS = 0
        } else {
            self.RS.port.*.BSRR |= self.RS.pin; // RS = 1
        }

        self.DATA.port.*.ODR = data;
        self.WR.port.*.BRR |= self.WR.pin;
        nops(3);
        self.WR.port.*.BSRR |= self.WR.pin;
        nops(3);
        self.RS.port.*.BSRR |= self.RS.pin; // RS = 1
    }

    /// End transmission by setting chip select high
    fn endTransmission(self: Self) void {
        self.RS.port.*.BSRR |= self.RS.pin; // RS = 1
        self.RD.port.*.BSRR |= self.RD.pin; // RD = 1
        self.WR.port.*.BSRR |= self.WR.pin; // WR = 1
        self.CS.port.*.BSRR |= self.CS.pin; // CS = 1 (chip unselect)
    }

    // hardware initializations

    // TODO
    fn REG_932X_Init(self: Self) void {
        // Power On sequence
        self.writeRegister(0x07, 0x0000); // DTE = D[1:0] = GON = 0
        self.writeRegister(0x12, 0x0000); // PON = VRH[2:0] = 0
        self.writeRegister(0x11, 0x0000); // VC[2:0] = 0
        self.writeRegister(0x29, 0x0000); // VCM[5:0] = 0
        self.writeRegister(0x13, 0x0000); // VDV[5:0] = 0
        self.writeRegister(0x10, 0x0000); // BT[2:0] = 0
        hal.HAL_Delay(60); // delay 50ms or more
        self.writeRegister(0x10, 0x07F0); // BT[2:0] = APE = AP[2:0] = 1
        self.writeRegister(0x11, 0x0770); // DC1[2:0] = DC0[2:0] = 1
        self.writeRegister(0x12, 0x0010); // PON = 1
        hal.HAL_Delay(100); // delay 80ms or later
        // Display On sequence
        self.writeRegister(0x10, 0x17F0); // Add SAP=1 (BT[2:0] = APE = AP[2:0] = 1)
        self.writeRegister(0x07, 0x0001); // D[1:0] = 01, GON = 0, DTE = 0
        hal.HAL_Delay(60); // delay 50ms or more
        self.writeRegister(0x07, 0x0021); // D[1:0] = 01, GON = 1, DTE = 0
        self.writeRegister(0x07, 0x0023); // D[1:0] = 11, GON = 1, DTE = 0
        hal.HAL_Delay(60); // delay 50ms or more
        self.writeRegister(0x07, 0x0033); // D[1:0] = 11, GON = 1, DTE = 1
    }

    /// Initialize the ILI9325 LCD
    /// This function initializes the ILI9325 LCD controller
    pub fn ili9325_Init(self: Self) void {
        self.ctrlLinesConfig();

        // Start Initial Sequence
        self.writeRegister(0, 0x0001); // Start internal OSC.
        self.writeRegister(1, 0x0100); // Set SS and SM bit
        self.writeRegister(2, 0x0700); // Set 1 line inversion
        self.writeRegister(3, 0x1018); // Set GRAM write direction and BGR=1.
        self.writeRegister(4, 0x0000); // Resize register
        self.writeRegister(8, 0x0202); // Set the back porch and front porch
        self.writeRegister(9, 0x0000); // Set non-display area refresh cycle ISC[3:0]
        self.writeRegister(10, 0x0000); // FMARK function
        self.writeRegister(12, 0x0000); // RGB interface setting
        self.writeRegister(13, 0x0000); // Frame marker Position
        self.writeRegister(15, 0x0000); // RGB interface polarity

        // Power On sequence
        self.writeRegister(16, 0x0000); // SAP, BT[3:0], AP, DSTB, SLP, STB
        self.writeRegister(17, 0x0000); // DC1[2:0], DC0[2:0], VC[2:0]
        self.writeRegister(18, 0x0000); // VREG1OUT voltage
        self.writeRegister(19, 0x0000); // VDV[4:0] for VCOM amplitude

        self.writeRegister(16, 0x17B0); // SAP, BT[3:0], AP, DSTB, SLP, STB
        self.writeRegister(17, 0x0137); // DC1[2:0], DC0[2:0], VC[2:0]

        self.writeRegister(18, 0x0139); // VREG1OUT voltage

        self.writeRegister(19, 0x1d00); // VDV[4:0] for VCOM amplitude
        self.writeRegister(41, 0x0013); // VCM[4:0] for VCOMH

        self.writeRegister(32, 0x0000); // GRAM horizontal Address
        self.writeRegister(33, 0x0000); // GRAM Vertical Address

        // Adjust the Gamma Curve (ILI9325)
        self.writeRegister(48, 0x0007);
        self.writeRegister(49, 0x0302);
        self.writeRegister(50, 0x0105);
        self.writeRegister(53, 0x0206);
        self.writeRegister(54, 0x0808);
        self.writeRegister(55, 0x0206);
        self.writeRegister(56, 0x0504);
        self.writeRegister(57, 0x0007);
        self.writeRegister(60, 0x0105);
        self.writeRegister(61, 0x0808);

        // Set GRAM area
        self.writeRegister(80, 0x0000); // Horizontal GRAM Start Address
        self.writeRegister(81, 0x00EF); // Horizontal GRAM End Address
        self.writeRegister(82, 0x0000); // Vertical GRAM Start Address
        self.writeRegister(83, 0x013F); // Vertical GRAM End Address

        self.writeRegister(96, 0xA700); // Gate Scan Line
        self.writeRegister(97, 0x0001); // NDL,VLE, REV
        self.writeRegister(106, 0x0000); // set scrolling line

        // Partial Display Control
        self.writeRegister(128, 0x0000);
        self.writeRegister(129, 0x0000);
        self.writeRegister(130, 0x0000);
        self.writeRegister(131, 0x0000);
        self.writeRegister(132, 0x0000);
        self.writeRegister(133, 0x0000);

        // Panel Control
        self.writeRegister(144, 0x0010);
        self.writeRegister(146, 0x0000);
        self.writeRegister(147, 0x0003);
        self.writeRegister(149, 0x0110);
        self.writeRegister(151, 0x0000);
        self.writeRegister(152, 0x0000);

        // set GRAM write direction and BGR = 1
        // I/D=00 (Horizontal : increment, Vertical : decrement)
        // AM=1 (address is updated in vertical writing direction)
        self.writeRegister(3, 0x1018);

        // 262K color and display ON
        self.writeRegister(7, 0x0173);

        // // Set the Cursor
        // try self.setCursor(0, 0);

        // // Prepare to write GRAM
        // self.prepareWriteGRAM();
    }

    pub fn powerOn(self: Self) void {
        
    }
    
    /// Disables the Power
    pub fn powerOff(self: Self) void {
        self.writeRegister(16, 0x0000); // SAP, BT[3:0], AP, DSTB, SLP, STB
        self.writeRegister(17, 0x0000); // DC1[2:0], DC0[2:0], VC[2:0]
        self.writeRegister(18, 0x0000); // VREG1OUT voltage
        self.writeRegister(19, 0x0000); // VDV[4:0] for VCOM amplitude

        self.writeRegister(41, 0x0000); // VCM[4:0] for VCOMH
    }
    
    /// Enables the Display
    pub fn displayOn(self: Self) void {
        // Power On sequence
        self.writeRegister(16, 0x0000); // SAP, BT[3:0], AP, DSTB, SLP, STB
        self.writeRegister(17, 0x0000); // DC1[2:0], DC0[2:0], VC[2:0]
        self.writeRegister(18, 0x0000); // VREG1OUT voltage
        self.writeRegister(19, 0x0000); // VDV[4:0] for VCOM amplitude

        self.writeRegister(16, 0x17B0); // SAP, BT[3:0], AP, DSTB, SLP, STB
        self.writeRegister(17, 0x0137); // DC1[2:0], DC0[2:0], VC[2:0]

        self.writeRegister(18, 0x0139); // VREG1OUT voltage

        self.writeRegister(19, 0x1d00); // VDV[4:0] for VCOM amplitude
        self.writeRegister(41, 0x0013); // VCM[4:0] for VCOMH

        // Display On
        self.writeRegister(7, 0x0133); // 262K color and display ON
    }

    /// Disables the Display
    pub fn displayOff(self: Self) void {
        self.powerOff();
        // Display Off
        self.writeRegister(7, 0x0000);
    }
    
};
