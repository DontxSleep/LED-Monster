#!/usr/bin/env python3
"""Create the extension's small PNG icons without external dependencies."""

from pathlib import Path
import struct
import zlib


ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "icons"
MASTER_SIZE = 512


def chunk(tag: bytes, data: bytes) -> bytes:
    body = tag + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def in_round_rect(x: float, y: float, left: float, top: float, right: float, bottom: float, radius: float) -> bool:
    cx = min(max(x, left + radius), right - radius)
    cy = min(max(y, top + radius), bottom - radius)
    return (x - cx) ** 2 + (y - cy) ** 2 <= radius**2


def pixel_color(x: float, y: float) -> tuple[int, int, int, int]:
    inset = 8
    radius = 105
    if in_round_rect(x, y, inset, inset, MASTER_SIZE - inset, MASTER_SIZE - inset, radius):
        color = (21, 95, 75, 255)
    else:
        color = (0, 0, 0, 0)

    bar_centers = [171, 214, 256, 298, 341]
    bar_heights = [78, 144, 202, 144, 78]
    width = 24
    bar_color = (198, 242, 121, 255)
    for center, height in zip(bar_centers, bar_heights):
        top = (MASTER_SIZE - height) / 2
        bottom = top + height
        if in_round_rect(x, y, center - width / 2, top, center + width / 2, bottom, width / 2):
            color = bar_color
    return color


def write_png(path: Path) -> None:
    rows = bytearray()
    for y in range(MASTER_SIZE):
        rows.append(0)
        for x in range(MASTER_SIZE):
            rows.extend(pixel_color(x + 0.5, y + 0.5))
    header = struct.pack(">IIBBBBB", MASTER_SIZE, MASTER_SIZE, 8, 6, 0, 0, 0)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
    path.write_bytes(data)


if __name__ == "__main__":
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    write_png(ICON_DIR / "icon-master.png")
