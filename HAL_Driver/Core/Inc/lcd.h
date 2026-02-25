#ifndef __LCD_FOR_C_H
#define __LCD_FOR_C_H

/**
 * 此文件由 AI 生成，用于实现 Zig 到 C 的头文件桥接
 */

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stddef.h>

/*============================================================================
 * Color Definitions (RGB565 format)
 *============================================================================*/
#define LCD_COLOR_BLACK       0x0000
#define LCD_COLOR_WHITE       0xFFFF
#define LCD_COLOR_GREY        0x7BEF
#define LCD_COLOR_BLUE        0x001F
#define LCD_COLOR_LIGHTBLUE   0x051F
#define LCD_COLOR_RED         0xF800
#define LCD_COLOR_MAGENTA     0xF81F
#define LCD_COLOR_GREEN       0x07E0
#define LCD_COLOR_CYAN        0x07FF
#define LCD_COLOR_YELLOW      0xFFE0

/*============================================================================
 * Line Definitions
 *============================================================================*/
#define LCD_LINE_0    0
#define LCD_LINE_1    24
#define LCD_LINE_2    48
#define LCD_LINE_3    72
#define LCD_LINE_4    96
#define LCD_LINE_5    120
#define LCD_LINE_6    144
#define LCD_LINE_7    168
#define LCD_LINE_8    192
#define LCD_LINE_9    216

/*============================================================================
 * Direction Definitions
 *============================================================================*/
#define LCD_DIRECTION_HORIZONTAL    0
#define LCD_DIRECTION_VERTICAL      1

/*============================================================================
 * Function Declarations
 *============================================================================*/

/**
 * @brief Initialize the LCD
 * @param bgColor Background color (RGB565)
 * @param textColor Text color (RGB565)
 */
void LCD_Init(uint16_t bgColor, uint16_t textColor);

/**
 * @brief Set text color
 * @param color RGB565 color value
 */
void LCD_SetTextColor(uint16_t color);

/**
 * @brief Set background color
 * @param color RGB565 color value
 */
void LCD_SetBackgroundColor(uint16_t color);

/**
 * @brief Clear the entire screen with a color
 * @param color RGB565 color value
 */
void LCD_Clear(uint16_t color);

/**
 * @brief Clear a specific line
 * @param line Line number (0-9)
 */
void LCD_ClearLine(uint8_t line);

/**
 * @brief Set cursor position
 * @param x X position (row, 0-239)
 * @param y Y position (column, 0-319)
 */
void LCD_SetCursor(uint8_t x, uint16_t y);

/**
 * @brief Display a character at specified position
 * @param x X position (row)
 * @param y Y position (column)
 * @param c Character to display (ASCII)
 */
void LCD_DisplayChar(uint8_t x, uint16_t y, uint8_t c);

/**
 * @brief Display a string at specified line
 * @param line Line number (0-9)
 * @param str Null-terminated string
 */
void LCD_DisplayStringLine(uint8_t line, const char* str);

/**
 * @brief Set display window
 * @param x Start X position
 * @param y Start Y position
 * @param height Window height
 * @param width Window width
 */
void LCD_SetDisplayWindow(uint8_t x, uint8_t y, uint8_t height, uint16_t width);

/**
 * @brief Disable window mode
 */
void LCD_WindowModeDisable(void);

/**
 * @brief Draw a line
 * @param x1 Start X position
 * @param y1 Start Y position
 * @param length Line length
 * @param direction 0 = horizontal, 1 = vertical
 */
void LCD_DrawLine(uint8_t x1, uint16_t y1, uint16_t length, uint8_t direction);

/**
 * @brief Draw a rectangle
 * @param x Top-left X position
 * @param y Top-left Y position
 * @param height Rectangle height
 * @param width Rectangle width
 */
void LCD_DrawRect(uint8_t x, uint16_t y, uint8_t height, uint16_t width);

/**
 * @brief Draw a circle
 * @param x Center X position
 * @param y Center Y position
 * @param radius Circle radius
 */
void LCD_DrawCircle(uint8_t x, uint16_t y, uint8_t radius);

/**
 * @brief Prepare for GRAM writing
 *        Call this before multiple writeGRAM calls
 */
void LCD_WriteGRAM_Prepare(void);

/**
 * @brief Write a single pixel to GRAM
 * @param color RGB565 color value
 */
void LCD_WriteGRAM(uint16_t color);

/**
 * @brief Read a pixel from GRAM
 * @return RGB565 color value
 */
uint16_t LCD_ReadGRAM(void);

/**
 * @brief Turn on display
 */
void LCD_DisplayOn(void);

/**
 * @brief Turn off display
 */
void LCD_DisplayOff(void);

/**
 * @brief Draw a monochrome picture (bitmap)
 *        Each bit represents a pixel: 0 = background color, 1 = text color
 * @param pict Pointer to u32 array (each u32 contains 32 pixels)
 * @param size Number of u32 elements in the array
 */
void LCD_DrawMonoPict(const uint32_t* pict, size_t size);

/**
 * @brief Draw a color picture (RGB565 format)
 * @param picture Pointer to u8 array (2 bytes per pixel)
 * @param size Number of bytes in the array
 */
void LCD_DrawPicture(const uint8_t* picture, size_t size);

/**
 * @brief Run LCD test function
 */
void LCD_FunctionTest(void);

#ifdef __cplusplus
}
#endif

#endif /* __LCD_FOR_C_H */