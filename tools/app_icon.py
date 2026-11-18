#!/usr/bin/env python3
"""Builds the layered app icon (sky gradient + Meteocons partly-cloudy sun) and the start icon.

    python3 tools/app_icon.py <path to bweatherflutter/files>
"""
import io
import subprocess
import sys
from pathlib import Path

from PIL import Image

TOP, BOTTOM = (0x1F, 0x6F, 0xBF), (0x4E, 0x9A, 0xDB)


def svg_png(path, size):
    svg = Path(path).read_text(encoding="utf-8")
    data = subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size)], input=svg.encode(), capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(data)).convert("RGBA")


def main(files):
    icon = Path(files) / "icons" / "meteocons--partly-cloudy-day-fill.svg"
    background = Image.new("RGBA", (1024, 1024))
    for y in range(1024):
        t = y / 1023
        color = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)) + (255,)
        background.paste(color, (0, y, 1024, y + 1))
    foreground = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    art = svg_png(icon, 720)
    foreground.alpha_composite(art, (152, 160))
    start = svg_png(icon, 288)
    for folder in ["AppScope/resources/base/media", "entry/src/main/resources/base/media"]:
        background.save(Path(folder) / "background.png", optimize=True)
        foreground.save(Path(folder) / "foreground.png", optimize=True)
    start.save("entry/src/main/resources/base/media/startIcon.png", optimize=True)


if __name__ == "__main__":
    main(sys.argv[1])
