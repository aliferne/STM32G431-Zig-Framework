#!/usr/bin/env python3
"""
将 fonts.h 中的 ASCII_Table 转换为二进制文件

由 Minimax-m2.5 生成
"""

import re
import sys
from pathlib import Path


def remove_comments(content: str) -> str:
    """移除 C/C++ 注释"""
    # 移除 C++ 风格注释 //
    content = re.sub(r'//.*?$', '', content, flags=re.MULTILINE)
    # 移除 C 风格注释 /* */
    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    return content


def parse_fonts_h(input_file: str, output_file: str):
    """解析 fonts.h 文件并提取 ASCII_Table 数据"""

    # 读取文件
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 移除注释
    content = remove_comments(content)

    # 查找 ASCII_Table 数组的开始和结束
    # 格式: uc16 ASCII_Table[] = { ... };
    pattern = r'uc16 ASCII_Table\[\]\s*=\s*\{(.*?)\};'
    match = re.search(pattern, content, re.DOTALL)

    if not match:
        print("错误: 无法找到 ASCII_Table 数组")
        sys.exit(1)

    array_content = match.group(1)

    # 提取所有十六进制值（此时已不含注释）
    hex_values = re.findall(r'0x[0-9A-Fa-f]+', array_content)

    if not hex_values:
        print("错误: 无法提取任何十六进制值")
        sys.exit(1)

    print(f"找到 {len(hex_values)} 个十六进制值")

    # 转换为 u16 并写入二进制文件
    with open(output_file, 'wb') as f:
        for hex_str in hex_values:
            value = int(hex_str, 16) & 0xFFFF  # 确保是 16 位
            # 小端序写入 (little-endian)
            f.write(value.to_bytes(2, byteorder='little'))

    print(f"已写入 {len(hex_values)} 个 u16 值到 {output_file}")
    print(f"文件大小: {len(hex_values) * 2} 字节")


if __name__ == '__main__':
    input_file = Path(__file__).parent / 'fonts.h'
    output_file = Path(__file__).parent / 'fonts.bin'

    print(f"输入文件: {input_file}")
    print(f"输出文件: {output_file}")

    parse_fonts_h(str(input_file), str(output_file))
