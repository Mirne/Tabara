"""Pack the eight building paintings and four research paintings for a settlement.

Pass the directory holding the original transparent sheets as the first argument.
The building originals are named after their ages. Research originals are named
icons-arrow-a.png through icons-cannon-b.png. Requires Pillow, NumPy and SciPy.
"""
from pathlib import Path
import argparse
import json

import numpy as np
from PIL import Image
from scipy import ndimage

AGES = ("wood", "stone", "iron", "steel", "keep", "castle", "citadel", "crown")
BUILDINGS = ("hall", "wood", "stone", "market", "arrow", "cannon", "workshop", "wall")
ROOT = Path(__file__).resolve().parents[1]


def objects(source, columns, rows):
    """Separate paintings using their alpha contours, including thin ornaments."""
    with Image.open(source) as sheet:
        if sheet.mode != "RGBA":
            raise ValueError(f"{source} must have an alpha channel")
        rgba = np.array(sheet)

    alpha = rgba[:, :, 3]
    count = rows * columns
    labels, total = ndimage.label(alpha > 96, structure=np.ones((3, 3)))
    sizes = np.bincount(labels.ravel())[1:]
    if total < count:
        raise ValueError(f"{source} has fewer than {count} distinct sprites")
    main = np.argsort(sizes)[-count:] + 1
    centers = ndimage.center_of_mass(alpha, labels, main)
    sprites = sorted(zip(centers, main), key=lambda item: item[0][0])
    order = []
    for start in range(0, count, columns):
        row = sorted(sprites[start:start + columns], key=lambda item: item[0][1])
        order.extend(int(label) for _, label in row)

    # Assign antialiasing and detached details to the closest opaque sprite.
    # A moving banner or overhanging crane can legally cross the sheet's grid.
    core = np.isin(labels, main)
    nearest = ndimage.distance_transform_edt(~core, return_distances=False,
                                            return_indices=True)
    owner = labels[tuple(nearest)]
    for label in order:
        mask = (owner == label) & (alpha >= 5)
        ys, xs = np.nonzero(mask)
        box = np.s_[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        cut = rgba[box].copy()
        cut[~mask[box]] = 0
        yield Image.fromarray(cut)


def mobile_bow(sprite):
    # Preserve small painted limbs and strings through the second downsample
    # from the 96px atlas to the 52px mobile control. Extend the existing
    # edge pigment by a fraction of a pixel, leaving the open silhouette intact.
    pixels = np.asarray(sprite, dtype=np.float32)
    alpha = pixels[:, :, 3]
    outer = ndimage.maximum_filter(alpha, size=3)
    added = (outer - alpha) * 0.7
    nearest = ndimage.distance_transform_edt(alpha < 128, return_distances=False,
                                            return_indices=True)
    edge_color = pixels[tuple(nearest)][:, :, :3]
    color = pixels[:, :, :3] * alpha[:, :, None] + edge_color * added[:, :, None]
    final_alpha = alpha + added
    result = np.empty_like(pixels)
    result[:, :, :3] = color / np.maximum(final_alpha, 1)[:, :, None]
    result[:, :, 3] = final_alpha
    return Image.fromarray(np.uint8(np.clip(result, 0, 255)))


def paste_fitted(sheet, sprite, column, row, cell, align_bottom, bow=False):
    margin = 2 if bow else 5
    sprite.thumbnail((cell - margin * 2, cell - margin * 2), Image.Resampling.LANCZOS)
    if bow:
        sprite = mobile_bow(sprite)
    left = column * cell + (cell - sprite.width) // 2
    top = row * cell + (cell - sprite.height - margin if align_bottom
                        else (cell - sprite.height) // 2)
    sheet.paste(sprite, (left, top))
    return [left, top, sprite.width, sprite.height]


def write_webp(sheet, destination, quality):
    # Godot may watch the directory while an atlas is being encoded.
    temporary = destination.with_suffix(".webp.tmp")
    sheet.save(temporary, format="WEBP", quality=quality, method=6, alpha_quality=100)
    temporary.replace(destination)


def pack(source, destination):
    destination.mkdir(parents=True, exist_ok=True)
    bounds = {}
    for age in AGES:
        sheet = Image.new("RGBA", (1024, 512))
        bounds[age] = {}
        for i, (name, sprite) in enumerate(zip(BUILDINGS, objects(source / f"{age}.png", 4, 2))):
            bounds[age][name] = paste_fitted(sheet, sprite, i % 4, i // 4, 256, True)
        write_webp(sheet, destination / f"{age}.webp", 87)

    (destination / "bounds.json").write_text(json.dumps(bounds, indent=2) + "\n")
    pack_research(source, destination)


def pack_research(source, destination):
    sheet = Image.new("RGBA", (576, 768))
    for weapon, column in (("arrow", 0), ("cannon", 3)):
        for suffix, row in (("a", 0), ("b", 4)):
            original = source / f"icons-{weapon}-{suffix}.png"
            for i, sprite in enumerate(objects(original, 3, 4)):
                paste_fitted(sheet, sprite, column + i % 3, row + i // 3, 96, False,
                            bow=weapon == "arrow" and i % 3 == 1)
    write_webp(sheet, destination / "research.webp", 91)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "assets/ages")
    args = parser.parse_args()
    pack(args.source, args.output)
