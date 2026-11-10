# Art, audio and credits

## Original raster art

The building atlas was generated specifically for Tabara with OpenAI image
generation on **9 November 2026**. Its seven buildings remain part of the frontier
revision. The frontier terrain, units and interface art were generated on
**10 November 2026**. Original generated files remain in the working environment;
repository assets are copies of those outputs, sampled through atlas regions.

| File | Contents and use |
| --- | --- |
| `assets/art/buildings.png` | Main hall, woodcutter, stonemason, arrow tower, wall, cannon tower, marketplace, original pine cluster |
| `assets/frontier/terrain.png` | Four raster ground materials: meadow, dirt, limestone, forest floor |
| `assets/frontier/props.png` | Twelve transparent woodland, quarry, timber, ruin, cart and vegetation sprites |
| `assets/frontier/units.png` | Four walking frames each for raider, runner, brute, siege cart and worker |
| `assets/frontier/panel.png` | Blank textured iron, brass and leather nine-patch interface frame |
| `assets/frontier/icons.png` | Timber, stone, coins, tools, shield, clock, torch and map icons |
| `assets/frontier/menu.png` | Original illustrated frontier-valley menu landscape |
| `assets/frontier/water.png` | Tileable lake material used by the terrain and animated surface |
| `assets/frontier/earth.png` | Transparent irregular compacted-earth foundation decal |
| `assets/frontier/resource-sites.png` | Compact pine grove and limestone quarry; one raster image per producer site |
| `assets/frontier/wall-kit.png` | Complete short horizontal/north–south modules and junction pier; no angled sprite crop |
| `assets/frontier/mountains.png` | Transparent rugged mountain cluster used along impassable spines |

Version 0.5 regenerated the resource sites without pale ground mats, replaced
the wall atlas with complete orthographic short modules, and added mountains.
Repository PNGs are unchanged copies of the generated outputs. Runtime regions
include each complete wall sprite. Their mobile imports are limited to 1,024
pixels on the longest axis. Building pivots align visible ground footprints
with dirt-patch centres.

The gameplay reference **They Are Billions** informed the settlement-defense
structure, not the graphics. No art or screenshots from that game are included.

Animation, sprite transforms, terrain composition, soft shadows, smoke,
projectiles, deaths and collapse are implemented in code using these raster
assets. Interface text, health bars, selection/range guides and minimap markers
remain functional drawing primitives; the world and command deck do not use
geometric placeholder characters or flat vector terrain.

## Audio and app icon

Audio was synthesized for this project using the reproducible
`tools/generate_audio.py` script. No commercial samples or external music are
included. `assets/icon.svg` is the original Tabara app icon; it is distinct from
the raster game interface.

## Fonts

The fonts are **Noto Sans** and **Noto Serif Display**, distributed under the
**SIL Open Font License 1.1**. The supplied license and copyright information are
in `assets/fonts/OFL.txt` and the in-app credits.

## Engine

Godot is distributed under the MIT license. Exported binaries contain Godot and
its third-party dependencies. Engine and third-party notices are accessible in
the in-app credits and at <https://godotengine.org/license/>.
