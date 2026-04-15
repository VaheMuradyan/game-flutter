#!/usr/bin/env python3
"""Generate PixelMatch launcher icons as PNG using only the standard library.

Writes under pixel_match/assets/brand/:
  icon.png      — 1024x1024 master (framed heart on navy, cyan border)
  icon_fg.png   — 1024x1024 Android adaptive foreground (heart on transparent)
  splash.png    — 1024x1024 splash logo (heart on navy, no frame)

Usage:
  python3 tool/gen_icon.py
Then regenerate platform launcher artifacts with:
  flutter pub run flutter_launcher_icons
  flutter pub run flutter_native_splash:create
"""
import os
import struct
import zlib

OUT_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "assets", "brand")
)

# Brand colors (R, G, B) — kept in sync with lib/theme/app_colors.dart.
NAVY = (0x0B, 0x0B, 0x1A)
SURFACE = (0x16, 0x16, 0x2A)
PINK = (0xFF, 0x6B, 0x6B)        # coral, matches brandPink
PINK_SHADOW = (0xD9, 0x4A, 0x4A)  # brandPinkDark, used for 1-cell pixel shading
CYAN = (0x4E, 0xCD, 0xC4)
WHITE = (0xFF, 0xFF, 0xFF)

SIZE = 1024
CELL = 64  # 16x16 pixel grid scaled 64x

# 16x16 pixel heart mask (# = filled body, * = highlight, . = empty).
# The heart is symmetric around the axis between columns 7 and 8. Highlights
# sit on the upper-left lobe to give the flat pink shape a hint of volume
# without breaking the pixel aesthetic.
HEART = [
    "................",
    "..###.....###...",
    ".#####...#####..",
    "################",
    "################",
    "################",
    "################",
    ".##############.",
    "..############..",
    "...##########...",
    "....########....",
    ".....######.....",
    "......####......",
    ".......##.......",
    "................",
    "................",
]

# Highlight cells — (col, row), painted in a lighter tint to give the flat
# pink shape a hint of volume on the upper-left lobe. Keep this set small;
# too many lit cells ruin the solid-color pixel-sticker read at tiny sizes.
HEART_HIGHLIGHT = {
    (2, 1), (3, 1),        # crown of left lobe
    (1, 2), (2, 2),        # upper-left face
    (1, 3), (2, 3),        # left-face shine column
    (1, 4),                # tail of the shine
}


def write_png(path: str, pixels: bytearray, size: int, has_alpha: bool = False) -> None:
    """Encode a raw pixel buffer to a PNG file (stdlib only)."""
    color_type = 6 if has_alpha else 2  # RGBA or RGB
    bytes_per_pixel = 4 if has_alpha else 3
    stride = size * bytes_per_pixel

    # Prefix each scanline with filter byte 0 (None).
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        raw.extend(pixels[y * stride:(y + 1) * stride])
    compressed = zlib.compress(bytes(raw), 9)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", size, size, 8, color_type, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def fill(pixels: bytearray, color, has_alpha: bool) -> None:
    bpp = 4 if has_alpha else 3
    px = bytes(color) + (b"\xff" if has_alpha else b"")
    for i in range(SIZE * SIZE):
        pixels[i * bpp:(i + 1) * bpp] = px


def put_rect(pixels: bytearray, x: int, y: int, w: int, h: int, color, has_alpha: bool) -> None:
    bpp = 4 if has_alpha else 3
    px = bytes(color) + (b"\xff" if has_alpha else b"")
    for yy in range(y, y + h):
        if yy < 0 or yy >= SIZE:
            continue
        row_off = yy * SIZE * bpp
        for xx in range(x, x + w):
            if xx < 0 or xx >= SIZE:
                continue
            off = row_off + xx * bpp
            pixels[off:off + bpp] = px


def rounded_rect(pixels: bytearray, x: int, y: int, w: int, h: int, r: int, color, has_alpha: bool) -> None:
    bpp = 4 if has_alpha else 3
    px = bytes(color) + (b"\xff" if has_alpha else b"")
    for yy in range(y, y + h):
        if yy < 0 or yy >= SIZE:
            continue
        # Horizontal extent at this row — carve the four corners.
        dy_top = (y + r) - yy
        dy_bot = yy - (y + h - 1 - r)
        dy = max(dy_top, dy_bot, 0)
        if dy >= r:
            continue
        if dy == 0:
            x_off = 0
        else:
            # circle equation: x^2 + dy^2 <= r^2
            x_off = r - int((r * r - dy * dy) ** 0.5)
        row_off = yy * SIZE * bpp
        for xx in range(x + x_off, x + w - x_off):
            if xx < 0 or xx >= SIZE:
                continue
            off = row_off + xx * bpp
            pixels[off:off + bpp] = px


def _lighten(color, amount: float = 0.35):
    """Lerp `color` toward white by `amount`."""
    return tuple(int(c + (0xFF - c) * amount) for c in color)


def draw_heart(pixels: bytearray, origin_x: int, origin_y: int, color, has_alpha: bool) -> None:
    highlight = _lighten(color, 0.45)
    for row, line in enumerate(HEART):
        for col, ch in enumerate(line):
            if ch != "#":
                continue
            fill_color = highlight if (col, row) in HEART_HIGHLIGHT else color
            put_rect(
                pixels,
                origin_x + col * CELL,
                origin_y + row * CELL,
                CELL,
                CELL,
                fill_color,
                has_alpha,
            )


def draw_heart_scaled(pixels: bytearray, ox: int, oy: int, cell: int, color, has_alpha: bool) -> None:
    highlight = _lighten(color, 0.45)
    for row, line in enumerate(HEART):
        for col, ch in enumerate(line):
            if ch != "#":
                continue
            fill_color = highlight if (col, row) in HEART_HIGHLIGHT else color
            put_rect(pixels, ox + col * cell, oy + row * cell, cell, cell, fill_color, has_alpha)


def build_icon() -> bytearray:
    pixels = bytearray(SIZE * SIZE * 3)
    fill(pixels, NAVY, has_alpha=False)
    # Cyan frame (drawn as rounded rect, then surface rounded inset by 12).
    rounded_rect(pixels, 48, 48, SIZE - 96, SIZE - 96, 184, CYAN, has_alpha=False)
    rounded_rect(pixels, 60, 60, SIZE - 120, SIZE - 120, 172, SURFACE, has_alpha=False)
    # Heart sized to comfortably fit inside the frame with padding.
    cell = 44
    heart_px = 16 * cell
    x = (SIZE - heart_px) // 2
    y = (SIZE - heart_px) // 2 + 8
    draw_heart_scaled(pixels, x, y, cell, PINK, has_alpha=False)
    return pixels


def build_adaptive_fg() -> bytearray:
    pixels = bytearray(SIZE * SIZE * 4)  # transparent
    # Android adaptive icon foreground: target inner 66% to stay inside
    # safe zone after the launcher applies its mask.
    cell = 36
    heart_px = 16 * cell
    x = (SIZE - heart_px) // 2
    y = (SIZE - heart_px) // 2 + 8
    draw_heart_scaled(pixels, x, y, cell, PINK, has_alpha=True)
    return pixels


def build_splash() -> bytearray:
    pixels = bytearray(SIZE * SIZE * 3)
    fill(pixels, NAVY, has_alpha=False)
    cell = 48
    # re-draw heart at smaller cell size for a splash that leaves room for text later
    x0 = (SIZE - 16 * cell) // 2
    y0 = (SIZE - 16 * cell) // 2 - 32
    draw_heart_scaled(pixels, x0, y0, cell, PINK, has_alpha=False)
    return pixels


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    write_png(os.path.join(OUT_DIR, "icon.png"), build_icon(), SIZE, has_alpha=False)
    write_png(os.path.join(OUT_DIR, "icon_fg.png"), build_adaptive_fg(), SIZE, has_alpha=True)
    write_png(os.path.join(OUT_DIR, "splash.png"), build_splash(), SIZE, has_alpha=False)
    print("wrote", OUT_DIR)


if __name__ == "__main__":
    main()
