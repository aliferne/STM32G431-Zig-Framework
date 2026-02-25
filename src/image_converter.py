#!/usr/bin/env python3
"""
此文件由 AI 生成
图片转换脚本
将 tux.png 转换为 STM32 LCD 所需的格式:
- output.bin: RGB565 彩色格式 (320x240)
- mono.bin: 单色位图格式 (320x240)
"""

from PIL import Image

# 配置
INPUT_FILE = "src/tux.png"
OUTPUT_COLOR = "src/output.bin"
OUTPUT_MONO = "src/mono.bin"

WIDTH = 160
HEIGHT = 128


def convert_to_rgb565(img: Image.Image) -> bytes:
    """将图片转换为 RGB565 格式"""
    # 转换为 RGB（去除 alpha 通道）
    if img.mode == "RGBA":
        background = Image.new("RGB", img.size, (255, 255, 255))
        background.paste(img, mask=img.split()[3])
        img = background
    elif img.mode != "RGB":
        img = img.convert("RGB")

    # 调整大小
    img = img.resize((WIDTH, HEIGHT))

    # 转换为 RGB565
    data = bytearray()
    for pixel in img.getdata():
        r, g, b = pixel
        rgb565 = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
        data.append(rgb565 & 0xFF)
        data.append((rgb565 >> 8) & 0xFF)

    return bytes(data)


def convert_to_mono(img: Image.Image) -> bytes:
    """将图片转换为单色位图"""
    # 转为灰度再转单色
    gray = img.convert("L")
    gray = gray.resize((WIDTH, HEIGHT))
    mono = gray.point(lambda x: 0 if x < 128 else 1, mode="1")

    # 每 32 位组成一个 u32（小端序）
    data = bytearray()
    pixels = list(mono.getdata())

    for i in range(0, len(pixels), 32):
        chunk = pixels[i:i+32]
        value = 0
        for j, pixel in enumerate(chunk):
            if pixel:
                value |= (1 << j)
        data.append(value & 0xFF)
        data.append((value >> 8) & 0xFF)
        data.append((value >> 16) & 0xFF)
        data.append((value >> 24) & 0xFF)

    return bytes(data)


def main():
    print(f"读取图片: {INPUT_FILE}")

    # 打开图片
    img = Image.open(INPUT_FILE)
    print(f"原始尺寸: {img.size}, 模式: {img.mode}")

    # 转换为 RGB565
    print("转换为 RGB565 格式...")
    rgb565_data = convert_to_rgb565(img)
    print(f"数据大小: {len(rgb565_data)} 字节 (期望: {WIDTH * HEIGHT * 2})")

    with open(OUTPUT_COLOR, "wb") as f:
        f.write(rgb565_data)
    print(f"已保存: {OUTPUT_COLOR}")

    # 转换为单色位图
    print("转换为单色位图格式...")
    mono_data = convert_to_mono(img)
    print(f"数据大小: {len(mono_data)} 字节 (期望: {WIDTH * HEIGHT // 8})")

    with open(OUTPUT_MONO, "wb") as f:
        f.write(mono_data)
    print(f"已保存: {OUTPUT_MONO}")

    print("转换完成!")


if __name__ == "__main__":
    main()
