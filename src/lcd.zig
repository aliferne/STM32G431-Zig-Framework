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
        @as([]const u16, @ptrCast(@alignCast(raw)))[0..(raw.len / 2)];
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
/// the origin is set to top left
pub const LCD = struct {
    /// self reference
    const Self = @This();
    pub const SupportedIds = [_]u16{ 0x9325, 0x9328 };
    pub const LineHeight = 24;
    pub const Height = 240;
    pub const Width = 320;
    pub const TotalPixels = Height * Width;
    pub const EmptyLine = "                    ";
    pub const Origin = .{ .x = @as(u8, 0), .y = @as(u16, 0) };
    pub const Color = enum(u16) {
        black = 0x0000,
        white = 0xFFFF,
        grey = 0x7BEF,
        blue = 0x001F,
        lightBlue = 0x051F,
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
        NotASupportedIdError,
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

    // though there's Color enum
    // `writeGRAM` should depend on a u16 value
    // but not to be limited in the enum values
    textColor: u16 = 0,
    bgColor: u16 = 0,

    pub fn init(self: *Self, bgColor: Color, textColor: Color) Err!void {
        self.ctrlLinesConfig();
        const readId: u16 = self.readRegister(0);

        // break with true if read result in support id
        const isSupported =
            for (SupportedIds) |id| {
                if (readId == id) break true;
            } else false;
        if (!isSupported) {
            return Err.NotASupportedIdError;
        }

        self.REG_932X_Init();
        self.displayOn();

        try self.clear(bgColor);
        self.setBackgroundColor(bgColor);
        self.setTextColor(textColor);
    }

    pub fn setTextColor(self: *Self, textColor: Color) void {
        self.textColor = @intFromEnum(textColor);
    }

    pub fn setBackgroundColor(self: *Self, bgColor: Color) void {
        self.bgColor = @intFromEnum(bgColor);
    }

    pub fn clearLine(self: Self, lineNumber: Line) Err!void {
        try self.displayStringLine(lineNumber, EmptyLine);
    }

    /// clear the screen with a specified color
    pub fn clear(self: Self, fillColor: Color) !void {
        try self.setCursor(0, 0);
        self.prepareWriteGRAM();
        for (0..TotalPixels) |_| {
            self.writeGRAM(@intFromEnum(fillColor));
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

    pub fn displayStringLine(self: Self, lineNumber: Line, string: []const u8) Err!void {
        const maxStrLen = Width / asciiFonts.fontSize;
        if (string.len > maxStrLen) {
            // Can't use since []const u8 is a runtime value
            // @compileError(
            //     \\ [in `displayStringLine`] string is too long,
            //     \\ it will be truncated to `maxStrLen` when running the program,
            //     \\ which may lead to undefined behavior.
            // );
            return Err.MaxStrLenError;
        }

        // 相较于 C，
        // 这里如果越界会先触发 Zig 内置的错误，
        // 告诉你 index out of range，然后触发 HardFault
        for (0..@min(string.len, maxStrLen)) |i| {
            const idx = @as(u16, @intCast(i));
            try self.displayChar(lineNumber, idx * asciiFonts.fontSize, string[idx]);
        }
    }
    /// Sets a display window
    pub fn setDisplayWindow(
        self: Self,
        xStart: u8,
        yStart: u16,
        height: u8,
        width: u16,
    ) !void {
        const xEnd = @min(xStart + height, Height) - 1;
        const yEnd = @min(yStart + width, Width) - 1;

        self.writeRegister(80, xStart);
        self.writeRegister(81, xEnd);

        self.writeRegister(82, yStart);
        self.writeRegister(83, yEnd);

        try self.setCursor(xStart, yStart);
    }

    /// Disables LCD Window mode
    pub fn windowModeDisable(self: Self) !void {
        try self.setDisplayWindow(0, 0, 240, 320);
        self.writeRegister(3, 0x1038);
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
        try self.drawLine((xStart + height - 1), yStart, width, Direction.horizontal);

        try self.drawLine(xStart, yStart, height, Direction.vertical);
        try self.drawLine(xStart, (yStart + width - 1), height, Direction.vertical);
    }

    /// Displays a circle using Bresenham's algorithm
    pub fn drawCircle(
        self: Self,
        xPos: u8,
        yPos: u16,
        radius: u16,
    ) !void {
        var D: i32 = 3 - (@as(i32, radius) << 1);
        var curX: u8 = 0;
        var curY: u16 = radius;

        while (curX <= curY) {
            try self.setCursor(xPos + curX, yPos + curY);
            self.prepareWriteGRAM();
            self.writeGRAM(self.textColor);

            try self.setCursor(xPos + curX, yPos - curY);
            self.prepareWriteGRAM();
            self.writeGRAM(self.textColor);

            try self.setCursor(xPos - curX, yPos + curY);
            self.prepareWriteGRAM();
            self.writeGRAM(self.textColor);

            try self.setCursor(xPos - curX, yPos - curY);
            self.prepareWriteGRAM();
            self.writeGRAM(self.textColor);

            try self.setCursor(xPos + @as(u8, @intCast(curY)), yPos + @as(u16, @intCast(curX)));
            self.prepareWriteGRAM();
            self.writeGRAM(self.textColor);

            try self.setCursor(xPos + @as(u8, @intCast(curY)), yPos - @as(u16, @intCast(curX)));
            self.prepareWriteGRAM();
            self.writeGRAM(self.textColor);

            try self.setCursor(xPos - @as(u8, @intCast(curY)), yPos + @as(u16, @intCast(curX)));
            self.prepareWriteGRAM();
            self.writeGRAM(self.textColor);

            try self.setCursor(xPos - @as(u8, @intCast(curY)), yPos - @as(u16, @intCast(curX)));
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

    /// read the binary file
    /// and turn it to `[]const u32` array
    /// for `drawMonoPict` to use
    /// set bgColor as the background color of the picture
    /// and fgColor as the foreground color of the picture
    pub fn readMonoPic(
        self: *Self,
        // should be a comptime-known value as `@embedFile` demands
        // then it'd be not avaliable to send command by serial
        // and let it show the picture you want
        comptime filename: []const u8,
        bgColor: Color,
        fgColor: Color,
    ) []const u32 {
        const data = @embedFile(filename);
        self.setBackgroundColor(bgColor);
        self.setTextColor(fgColor);
        return @as([]const u32, @ptrCast(@alignCast(data)));
    }

    /// Draw a monochrome picture (bitmap)
    /// Each bit represents a pixel: 0 = background color, 1 = text color
    /// pict: slice of u32 (each u32 contains 32 pixels)
    pub fn drawMonoPic(self: Self, pict: []const u32) !void {
        try self.setCursor(Origin.x, Origin.y);
        self.prepareWriteGRAM();

        const pixel_count = pict.len * 32;
        for (0..pixel_count) |i| {
            const word_index = i / 32;
            const bit_index = i % 32;
            if ((pict[word_index] & (@as(u32, 1) << @truncate(bit_index))) == 0) {
                self.writeGRAM(self.bgColor);
            } else {
                self.writeGRAM(self.textColor);
            }
        }
    }

    /// read the binary file
    /// and turn it to `[]const u8` array
    /// for `drawPicture` to use
    pub fn readPicture(
        _: Self,
        // should be a comptime-known value as `@embedFile` demands
        // then it'd be not avaliable to send command by serial
        // and let it show the picture you want
        comptime filename: []const u8,
    ) []const u8 {
        const data = @embedFile(filename);
        return @as([]const u8, @ptrCast(@alignCast(data)));
    }

    /// Displays a 16 color picture (RGB565 format)
    /// picture: raw RGB565 data (2 bytes per pixel)
    pub fn drawPicture(self: Self, picture: []const u8) !void {
        try self.setCursor(Origin.x, Origin.y);
        self.prepareWriteGRAM();

        const pixel_count = picture.len / 2;
        for (0..pixel_count) |index| {
            const pixel = (@as(u16, picture[2 * index + 1]) << 8) | picture[2 * index];
            self.writeGRAM(pixel);
        }
    }

    /// prepare for writing GRAM
    /// call this before call `writeGRAM`
    pub fn prepareWriteGRAM(self: Self) void {
        self.startTransmission();
        self.sendRegisterAddr(34);
        self.endTransmission();
    }

    pub fn writeGRAM(self: Self, pixelColor: u16) void {
        self.startTransmission();
        self.writeBusData(pixelColor, WriteMode.data);
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

    /// LCD 测试函数
    pub fn functionTest(self: *Self) !void {
        // 初始化 LCD
        try self.init(.blue, .white);

        // 画线 - 中心十字
        try self.drawLine(120, 0, 320, .horizontal);
        try self.drawLine(0, 160, 240, .vertical);
        hal.HAL_Delay(1000);
        try self.clear(.blue);

        // 画矩形
        try self.drawRect(70, 70, 100, 100);
        hal.HAL_Delay(1000);
        try self.clear(.blue);

        // 画圆
        try self.drawCircle(120, 160, 50);
        hal.HAL_Delay(1000);

        // 清屏并显示文字
        try self.clear(.blue);
        try self.displayStringLine(.line4, "Hello,world.");
        hal.HAL_Delay(1000);

        // 设置窗口大小
        try self.setDisplayWindow(20, 20, 60, 60);
        try self.clear(.yellow);
        self.setBackgroundColor(.yellow);
        self.setTextColor(.blue);
        try self.displayStringLine(.line1, "ABCDEFGHIJKLMNO");
        try self.windowModeDisable();
        hal.HAL_Delay(1000);

        // 逐行设置背景色并显示空行
        self.setBackgroundColor(.white);
        try self.displayStringLine(.line0, EmptyLine);

        self.setBackgroundColor(.black);
        try self.displayStringLine(.line1, EmptyLine);

        self.setBackgroundColor(.grey);
        try self.displayStringLine(.line2, EmptyLine);

        self.setBackgroundColor(.blue);
        try self.displayStringLine(.line3, EmptyLine);

        self.setBackgroundColor(.lightBlue);
        try self.displayStringLine(.line4, EmptyLine);

        self.setBackgroundColor(.red);
        try self.displayStringLine(.line5, EmptyLine);

        self.setBackgroundColor(.magenta);
        try self.displayStringLine(.line6, EmptyLine);

        self.setBackgroundColor(.green);
        try self.displayStringLine(.line7, EmptyLine);

        self.setBackgroundColor(.cyan);
        try self.displayStringLine(.line8, EmptyLine);

        self.setBackgroundColor(.yellow);
        try self.displayStringLine(.line9, EmptyLine);

        // NOTE: 由于加入图片测试会导致二进制文件膨胀，故此处不再纳入测试范畴
        // 在 Zig 下测试可用
        // hal.HAL_Delay(1000);
        // // 测试彩色图片
        // const pictureData = self.readPicture("output.bin");
        // try self.drawPicture(pictureData);
        // hal.HAL_Delay(1000);
        // // 测试单色位图
        // const monoData = self.readMonoPic("mono.bin", .black, .white);
        // try self.drawMonoPic(monoData);
    }

    /// times: number of nops to execute
    inline fn nops(times: u8) void {
        inline for (0..times) |_| {}
    }

    // ************ Hardware Initializations *********** //

    /// Initialize the ILI9325 LCD
    /// This function initializes the ILI9325 LCD controller
    pub fn REG_932X_Init(self: Self) void {
        // initialize ctrl line
        self.ctrlLinesConfig();
        // Start Initial Sequence
        self.configInitSettings();
        // Power On sequence
        self.powerOn();
        // Adjust the Gamma Curve (ILI9325)
        self.configGammaCurve();
        // Set GRAM area
        self.configGRAM();
        // Partial Display Control
        self.configPartialDisplay();
        // Panel Control
        self.configPanelControl();
    }
    pub fn powerOn(self: Self) void {
        self.powerOff(); // should call this to reset power

        self.writeRegister(16, 0x17B0); // SAP, BT[3:0], AP, DSTB, SLP, STB
        self.writeRegister(17, 0x0137); // DC1[2:0], DC0[2:0], VC[2:0]
        self.writeRegister(18, 0x0139); // VREG1OUT voltage
        self.writeRegister(19, 0x1d00); // VDV[4:0] for VCOM amplitude
        self.writeRegister(41, 0x0013); // VCM[4:0] for VCOMH
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
        self.powerOn();
        // Display On
        self.writeRegister(7, 0x0173); // 262K color and display ON
    }
    /// Disables the Display
    pub fn displayOff(self: Self) void {
        // power off sequence
        self.powerOff();
        // Display Off
        self.writeRegister(7, 0x0000);
    }

    fn configInitSettings(self: Self) void {
        self.writeRegister(1, 0x0000); // Set SS and SM bit, SS is related to the origin point
        self.writeRegister(2, 0x0700); // Set 1 line inversion
        // set GRAM write direction and BGR = 1
        // I/D=11 (Horizontal : increment, Vertical : increment)
        // AM=1 (address is updated in vertical writing direction)
        self.writeRegister(3, 0x1038);
        self.writeRegister(4, 0x0000); // Resize register
        self.writeRegister(8, 0x0202); // Set the back porch and front porch
        self.writeRegister(9, 0x0000); // Set non-display area refresh cycle ISC[3:0]
        self.writeRegister(10, 0x0000); // FMARK function
        self.writeRegister(12, 0x0000); // RGB interface setting
        self.writeRegister(13, 0x0000); // Frame marker Position
        self.writeRegister(15, 0x0000); // RGB interface polarity
    }

    fn configGammaCurve(self: Self) void {
        self.writeRegister(48, 0x0007);
        self.writeRegister(49, 0x0302);
        self.writeRegister(50, 0x0105);
        self.writeRegister(53, 0x0206);
        self.writeRegister(54, 0x0808);
        self.writeRegister(55, 0x0206);
        self.writeRegister(56, 0x0504);
        self.writeRegister(57, 0x0007);
        self.writeRegister(60, 0x0100); // (NL=1) total 16 lines
        self.writeRegister(61, 0x0000);
    }

    fn configGRAM(self: Self) void {
        self.writeRegister(32, 0x0000); // GRAM horizontal Address
        self.writeRegister(33, 0x0000); // GRAM Vertical Address
        self.writeRegister(80, 0x0000); // Horizontal GRAM Start Address
        self.writeRegister(81, 0x00EF); // Horizontal GRAM End Address
        self.writeRegister(82, 0x0000); // Vertical GRAM Start Address
        self.writeRegister(83, 0x013F); // Vertical GRAM End Address
        self.writeRegister(96, 0xA700); // Gate Scan Line
        self.writeRegister(97, 0x0001); // NDL,VLE, REV
        self.writeRegister(106, 0x0000); // set scrolling line
    }

    fn configPartialDisplay(self: Self) void {
        self.writeRegister(128, 0x0000);
        self.writeRegister(129, 0x0000);
        self.writeRegister(130, 0x0000);
        self.writeRegister(131, 0x0000);
        self.writeRegister(132, 0x0000);
        self.writeRegister(133, 0x0000);
    }

    fn configPanelControl(self: Self) void {
        self.writeRegister(144, 0x0010);
        self.writeRegister(146, 0x0000);
        self.writeRegister(147, 0x0003);
        self.writeRegister(149, 0x0110);
        self.writeRegister(151, 0x0000);
        self.writeRegister(152, 0x0000);
    }
    // ************ Hardware Initializations *********** //

    // ***************** ILI932X Communication Protocol **************** //
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
    // ***************** ILI932X Communication Protocol **************** //
};

// ============================================================================
// C-Compatible Wrapper Functions
// These functions can be called from C code
// ============================================================================

// Global LCD instance for C wrapper
var lcd_instance: LCD = .{};

// Color values (RGB565) - using LCD.Color enum values
pub const LCD_COLOR_BLACK: u16 = @intFromEnum(LCD.Color.black);
pub const LCD_COLOR_WHITE: u16 = @intFromEnum(LCD.Color.white);
pub const LCD_COLOR_GREY: u16 = @intFromEnum(LCD.Color.grey);
pub const LCD_COLOR_BLUE: u16 = @intFromEnum(LCD.Color.blue);
pub const LCD_COLOR_LIGHTBLUE: u16 = @intFromEnum(LCD.Color.lightBlue);
pub const LCD_COLOR_RED: u16 = @intFromEnum(LCD.Color.red);
pub const LCD_COLOR_MAGENTA: u16 = @intFromEnum(LCD.Color.magenta);
pub const LCD_COLOR_GREEN: u16 = @intFromEnum(LCD.Color.green);
pub const LCD_COLOR_CYAN: u16 = @intFromEnum(LCD.Color.cyan);
pub const LCD_COLOR_YELLOW: u16 = @intFromEnum(LCD.Color.yellow);

// Line definitions - using LCD.Line enum values
pub const LCD_LINE_0: u8 = @intFromEnum(LCD.Line.line0);
pub const LCD_LINE_1: u8 = @intFromEnum(LCD.Line.line1);
pub const LCD_LINE_2: u8 = @intFromEnum(LCD.Line.line2);
pub const LCD_LINE_3: u8 = @intFromEnum(LCD.Line.line3);
pub const LCD_LINE_4: u8 = @intFromEnum(LCD.Line.line4);
pub const LCD_LINE_5: u8 = @intFromEnum(LCD.Line.line5);
pub const LCD_LINE_6: u8 = @intFromEnum(LCD.Line.line6);
pub const LCD_LINE_7: u8 = @intFromEnum(LCD.Line.line7);
pub const LCD_LINE_8: u8 = @intFromEnum(LCD.Line.line8);
pub const LCD_LINE_9: u8 = @intFromEnum(LCD.Line.line9);

// Direction definitions - using LCD.Direction enum values
pub const LCD_DIRECTION_HORIZONTAL: u8 = @intFromEnum(LCD.Direction.horizontal);
pub const LCD_DIRECTION_VERTICAL: u8 = @intFromEnum(LCD.Direction.vertical);

/// Initialize the LCD
/// bgColor: background color (RGB565)
/// textColor: text color (RGB565)
export fn LCD_Init(bgColor: u16, textColor: u16) callconv(.c) void {
    lcd_instance.init(@enumFromInt(bgColor), @enumFromInt(textColor)) catch unreachable;
}

/// Set text color
/// color: RGB565 color value
export fn LCD_SetTextColor(color: u16) callconv(.c) void {
    lcd_instance.setTextColor(@enumFromInt(color));
}

/// Set background color
/// color: RGB565 color value
export fn LCD_SetBackgroundColor(color: u16) callconv(.c) void {
    lcd_instance.setBackgroundColor(@enumFromInt(color));
}

/// Clear the entire screen with a color
/// color: RGB565 color value
export fn LCD_Clear(color: u16) callconv(.c) void {
    lcd_instance.clear(@enumFromInt(color)) catch unreachable;
}

/// Clear a specific line
/// line: line number (0-9)
export fn LCD_ClearLine(line: u8) callconv(.c) void {
    lcd_instance.clearLine(@enumFromInt(line)) catch unreachable;
}

/// Set cursor position
/// x: X position (row, 0-239)
/// y: Y position (column, 0-319)
export fn LCD_SetCursor(x: u8, y: u16) callconv(.c) void {
    lcd_instance.setCursor(x, y) catch unreachable;
}

/// Display a character at specified position
/// x: X position (row)
/// y: Y position (column)
/// c: character to display (ASCII)
export fn LCD_DisplayChar(x: u8, y: u16, c: u8) callconv(.c) void {
    lcd_instance.displayChar(@enumFromInt(x), y, c) catch unreachable;
}

/// Display a string at specified line
/// line: line number (0-9)
/// str: null-terminated string
export fn LCD_DisplayStringLine(line: u8, str: [*]const u8) callconv(.c) void {
    // Convert C string to Zig string
    var len: usize = 0;
    while (str[len] != 0) : (len += 1) {}
    const zig_str: []const u8 = str[0..len];
    lcd_instance.displayStringLine(@enumFromInt(line), zig_str) catch unreachable;
}

/// Set display window
/// x: start X position
/// y: start Y position
/// height: window height
/// width: window width
export fn LCD_SetDisplayWindow(x: u8, y: u16, height: u8, width: u16) callconv(.c) void {
    lcd_instance.setDisplayWindow(x, y, height, width) catch unreachable;
}

/// Disable window mode
export fn LCD_WindowModeDisable() callconv(.c) void {
    lcd_instance.windowModeDisable() catch unreachable;
}

/// Draw a line
/// x1: start X position
/// y1: start Y position
/// length: line length
/// direction: 0 = horizontal, 1 = vertical
export fn LCD_DrawLine(x1: u8, y1: u16, length: u16, direction: u8) callconv(.c) void {
    const dir: LCD.Direction = if (direction == 0) .horizontal else .vertical;
    lcd_instance.drawLine(x1, y1, length, dir) catch unreachable;
}

/// Draw a rectangle
/// x: top-left X position
/// y: top-left Y position
/// height: rectangle height
/// width: rectangle width
export fn LCD_DrawRect(x: u8, y: u16, height: u8, width: u16) callconv(.c) void {
    lcd_instance.drawRect(x, y, height, width) catch unreachable;
}

/// Draw a circle
/// x: center X position
/// y: center Y position
/// radius: circle radius
export fn LCD_DrawCircle(x: u8, y: u16, radius: u8) callconv(.c) void {
    lcd_instance.drawCircle(x, y, radius) catch unreachable;
}

/// Prepare for GRAM writing
/// Call this before multiple writeGRAM calls
export fn LCD_WriteGRAM_Prepare() callconv(.c) void {
    lcd_instance.prepareWriteGRAM();
}

/// Write a single pixel to GRAM
/// color: RGB565 color value
export fn LCD_WriteGRAM(color: u16) callconv(.c) void {
    lcd_instance.writeGRAM(color);
}

/// Read a pixel from GRAM
/// Returns RGB565 color value
export fn LCD_ReadGRAM() callconv(.c) u16 {
    return lcd_instance.readGRAM();
}

/// Turn on display
export fn LCD_DisplayOn() callconv(.c) void {
    lcd_instance.displayOn();
}

/// Turn off display
export fn LCD_DisplayOff() callconv(.c) void {
    lcd_instance.displayOff();
}

/// Draw a monochrome picture (bitmap)
/// Each bit represents a pixel: 0 = background color, 1 = text color
/// pict: pointer to u32 array (each u32 contains 32 pixels)
/// size: number of u32 elements in the array
export fn LCD_DrawMonoPict(pict: [*]const u32, size: usize) callconv(.c) void {
    const slice: []const u32 = pict[0..size];
    lcd_instance.drawMonoPic(slice) catch unreachable;
}

/// Draw a color picture (RGB565 format)
/// picture: pointer to u8 array (2 bytes per pixel)
/// size: number of bytes in the array
export fn LCD_DrawPicture(picture: [*]const u8, size: usize) callconv(.c) void {
    const slice: []const u8 = picture[0..size];
    lcd_instance.drawPicture(slice) catch unreachable;
}

/// Run LCD test function
export fn LCD_FunctionTest() callconv(.c) void {
    lcd_instance.functionTest() catch unreachable;
}
