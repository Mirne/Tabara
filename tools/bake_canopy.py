"""Read source canopy alpha to fit gameplay collision to the visible forest.

Writes JSON collision cells only. Source artwork is never modified. Run before
bake_world.gd after replacing canopy art or moving a forest region. Requires Pillow.
"""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'assets/world/woodland.json'
data = json.loads(path.read_text())
width, height, cell = 205, 128, 40
blocked = set()
offsets = [(0, 0), (-11, -11), (11, -11), (-11, 11), (11, 11), (0, -14), (0, 14)]
for region in data['regions']:
    x, y, w, h = region['rect']
    image = Image.open(ROOT / region['texture'].removeprefix('res://')).convert('RGBA')
    alpha = image.getchannel('A')
    for gy in range(max(0, int(y // cell)), min(height, int((y + h) // cell) + 1)):
        for gx in range(max(0, int(x // cell)), min(width, int((x + w) // cell) + 1)):
            for dx, dy in offsets:
                u = int(((gx + .5) * cell + dx - x) / w * image.width)
                v = int(((gy + .5) * cell + dy - y) / h * image.height)
                if 0 <= u < image.width and 0 <= v < image.height and alpha.getpixel((u, v)) >= 96:
                    blocked.add(gy * width + gx)
                    break
# Fill sub-cell canopy gaps surrounded by trees; never expand the outer edge.
closed = set(blocked)
for gy in range(1, height - 1):
    for gx in range(1, width - 1):
        key = gy * width + gx
        if key not in blocked and sum((gy + dy) * width + gx + dx in blocked for dy in [-1, 0, 1] for dx in [-1, 0, 1]) >= 7:
            closed.add(key)
data['forest_cells'] = sorted(closed)
path.write_text(json.dumps(data, separators=(',', ':'), sort_keys=True))
print(f'Canopy alpha analyzed: {len(closed)} collision cells; source PNGs unchanged')
