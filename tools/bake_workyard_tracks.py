"""Bake the local material mask for the two Hearthvale workyards.

The red channel reveals the map's earth texture, and green reveals its gravel.
The full map and all gameplay terrain masks remain independent of this patch.
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
LEGACY = "--legacy" in sys.argv
MAP_FILE = "workyards.json" if LEGACY else "back-workyards.json"
DATA = json.loads((ROOT / "assets/world" / MAP_FILE).read_text())
LEFT, TOP, WIDTH, HEIGHT = DATA["wear_bounds"]
UNITS_PER_PIXEL = 2
SIZE = WIDTH // UNITS_PER_PIXEL, HEIGHT // UNITS_PER_PIXEL


def pixel(point):
    return ((point[0] - LEFT) / UNITS_PER_PIXEL, (point[1] - TOP) / UNITS_PER_PIXEL)


def brushed(channel, points, width, strength, softness):
    stamp = Image.new("L", SIZE)
    brush = ImageDraw.Draw(stamp)
    positions = [pixel(point) for point in points]
    radius = width * 0.5 / UNITS_PER_PIXEL
    brush.line(positions, fill=strength, width=round(2 * radius), joint="curve")
    for x, y in positions:
        brush.ellipse((x - radius, y - radius, x + radius, y + radius), fill=strength)
    return ImageChops.lighter(channel, stamp.filter(ImageFilter.GaussianBlur(softness / UNITS_PER_PIXEL)))


def wheel_track(channel, route):
    # A soft bed joins the two ruts, with the original verge showing between them.
    channel = brushed(channel, route, 52, 128, 12)
    for side in (-1, 1):
        line = []
        for index, (x, y) in enumerate(route):
            prev_x, prev_y = route[max(0, index - 1)]
            next_x, next_y = route[min(len(route) - 1, index + 1)]
            dx, dy = next_x - prev_x, next_y - prev_y
            length = math.hypot(dx, dy)
            line.append((x - side * dy / length * 13, y + side * dx / length * 13))
        channel = brushed(channel, line, 12, 238, 3)
    return channel


def main():
    earth = Image.new("L", SIZE)
    gravel = Image.new("L", SIZE)
    for route in DATA["cart_tracks"]:
        earth = wheel_track(earth, route)
    for site in DATA["nodes"]:
        x, y = site["pos"]
        # The tracks fan out into working floors under the paid foundations.
        # A second pass reaches sideways to the actual log stack or rock face.
        if not LEGACY and site["kind"] == "wood":
            earth = brushed(earth, [(x - 39, y - 10), (x + 4, y + 8), (x + 42, y - 12)], 71, 210, 12)
            earth = brushed(earth, [(x + 7, y + 23), (x + 40, y - 15)], 44, 190, 11)
        elif not LEGACY:
            earth = brushed(earth, [(x - 44, y + 2), (x, y + 14), (x + 65, y - 11)], 82, 173, 15)
            gravel = brushed(gravel, [(x - 84, y - 62), (x - 19, y - 49), (x + 67, y - 27), (x + 123, y - 23)], 56, 162, 16)
            gravel = brushed(gravel, [(x - 46, y - 3), (x + 12, y + 16), (x + 63, y - 4)], 64, 175, 14)
        elif site["kind"] == "wood":
            earth = brushed(earth, [(x - 59, y - 8), (x + 4, y + 15), (x + 84, y + 9)], 78, 226, 17)
            earth = brushed(earth, [(x + 74, y + 3), (x + 121, y - 23)], 42, 165, 13)
        else:
            earth = brushed(earth, [(x - 90, y + 7), (x - 13, y + 21), (x + 52, y + 10)], 77, 205, 16)
            gravel = brushed(gravel, [(x - 145, y - 8), (x - 86, y - 11), (x - 40, y + 11)], 93, 211, 20)
            gravel = brushed(gravel, [(x - 61, y + 5), (x + 9, y + 18), (x + 46, y + 16)], 52, 137, 16)
    mask = Image.merge("RGB", (earth, gravel, Image.new("L", SIZE)))
    mask.save(ROOT / "assets/world" / ("workyard-wear.png" if LEGACY else "back-workyard-wear.png"), optimize=True)


if __name__ == "__main__":
    main()
