#!/usr/bin/env python3
"""Генератор иконки приложения (1024x1024 PNG, градиент + молния-щит).

Использование:
    python3 scripts/make_icons.py
Результат:
    ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-1024.png
"""
import math
import os
import struct
import zlib

SIZE = 1024


def write_png(path, pixels):
    """pixels: list of rows, each row — list of (r, g, b) tuples."""
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b""
    for row in pixels:
        raw += b"\x00" + bytes(v for px in row for v in px)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def lerp(a, b, t):
    return a + (b - a) * t


def clamp(v):
    return max(0, min(255, int(v)))


def in_rounded_rect(x, y, cx, cy, half, radius):
    dx = abs(x - cx) - (half - radius)
    dy = abs(y - cy) - (half - radius)
    if dx > 0 and dy > 0:
        return math.hypot(dx, dy) <= radius
    return abs(x - cx) <= half and abs(y - cy) <= half


def point_in_poly(x, y, poly):
    inside = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi):
            inside = not inside
        j = i
    return inside


def main():
    cx = cy = SIZE / 2

    # Молния (вписаны координаты в квадрат ~[-1,1])
    bolt = [
        (0.10, -0.62), (-0.38, 0.08), (-0.06, 0.08),
        (-0.16, 0.62), (0.36, -0.10), (0.04, -0.10),
    ]
    bolt_px = [(cx + x * 300, cy + y * 320) for x, y in bolt]

    # Щит (круг)
    shield_r = 300

    rows = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            # Фон: диагональный градиент (фиолетовый → синий → циановый)
            t = (x + y) / (2 * SIZE)
            r = lerp(0x7C, 0x18, t) * 0.55 + lerp(0x3A, 0x0C, t) * 0.45
            g = lerp(0x5C, 0x2A, t) * 0.55 + lerp(0x2A, 0x1E, t) * 0.45
            b = lerp(0xFF, 0xC8, t)

            dx = x - cx
            dy = y - cy
            dist = math.hypot(dx, dy)

            # Тёмный круг-щит
            if dist < shield_r:
                shade = 1 - dist / shield_r
                r = lerp(r, 0x12, 0.75 + 0.15 * shade)
                g = lerp(g, 0x18, 0.75 + 0.15 * shade)
                b = lerp(b, 0x30, 0.75 + 0.15 * shade)
                # Свечение по краю
                edge = abs(dist - shield_r + 26) / 26
                if edge < 1:
                    glow = (1 - edge) * 0.55
                    r = lerp(r, 0x7C, glow)
                    g = lerp(g, 0x5C, glow)
                    b = lerp(b, 0xFF, glow)

            # Молния
            if point_in_poly(x, y, bolt_px):
                # Градиент молнии
                bt = (y - (cy - 200)) / 420
                r = lerp(0x00, 0x2C, bt)
                g = lerp(0xC2, 0xE5, bt)
                b = lerp(0xFF, 0xA6, bt)

            row.append((clamp(r), clamp(g), clamp(b)))
        rows.append(row)

    out = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png",
    )
    os.makedirs(os.path.dirname(out), exist_ok=True)
    write_png(out, rows)
    print(f"Иконка записана: {out}")


if __name__ == "__main__":
    main()
