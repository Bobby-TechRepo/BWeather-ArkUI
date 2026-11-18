#!/usr/bin/env python3
"""Rasterises the Flutter app's SVG artwork into PNG media resources.

    python3 tools/icons.py <path to bweatherflutter/files> entry/src/main/resources/base/media

Meteocons use <symbol>, <use> and gradients by reference, which ArkUI's SVG
renderer only partly supports, so they ship as 256 px PNGs (3x of ~85 vp).
"""
import re
import subprocess
import sys
from pathlib import Path

WEATHER = """clear-day-fill partly-cloudy-day-fill overcast-fill fog-day-fill partly-cloudy-day-drizzle-fill
overcast-day-drizzle-fill extreme-day-drizzle-fill overcast-drizzle-fill extreme-drizzle-fill partly-cloudy-day-rain-fill
overcast-day-rain-fill extreme-day-rain-fill overcast-rain-fill extreme-rain-fill snow-fill extreme-day-snow-fill
extreme-snow-fill drizzle-fill partly-cloudy-day-snow-fill thunderstorms-day-fill thunderstorms-day-overcast-fill
thunderstorms-day-extreme-fill clear-night-fill partly-cloudy-night-fill overcast-night-fill fog-night-fill
partly-cloudy-night-drizzle-fill extreme-night-drizzle-fill partly-cloudy-night-rain-fill overcast-night-rain-fill
extreme-night-rain-fill extreme-night-snow-fill partly-cloudy-night-snow-fill thunderstorms-night-fill
thunderstorms-night-overcast-fill thunderstorms-night-extreme-fill""".split()

DETAILS = {
    "det_compass": "noto--compass.svg",
    "det_wind": "fluent-emoji-flat--leaf-fluttering-in-wind.svg",
    "det_umbrella": "emojione--umbrella-with-rain-drops.svg",
    "det_pressure": "emojione--stopwatch.svg",
    "det_cloud": "emojione--sun-behind-cloud.svg",
    "det_droplet": "twemoji--droplet.svg",
}


def render(source, target, size):
    """Renders a still frame. Animated parts (rain drops, snowflakes) start at
    opacity 0 and are faded in by <animate>, so those are made visible."""
    svg = Path(source).read_text(encoding="utf-8")
    svg = re.sub(r"<animate(Transform)?\b[^>]*/>", "", svg)
    svg = svg.replace(' opacity="0"', "")
    subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), "-o", str(target)], input=svg.encode("utf-8"), check=True)


def main(files, media):
    media = Path(media)
    media.mkdir(parents=True, exist_ok=True)
    for name in WEATHER:
        render(Path(files) / "icons" / f"meteocons--{name}.svg", media / ("wx_" + name.replace("-", "_") + ".png"), 256)
    for name, file in DETAILS.items():
        render(Path(files) / file, media / f"{name}.png", 144)
    # Single-colour artwork, tinted in the app with fillColor().
    svg = (Path(files) / "cloud-bolt-rain.svg").read_text().replace("currentColor", "#000000")
    (media / "ic_rain_chance.svg").write_text(re.sub(r' width="1em" height="1em"', "", svg))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
