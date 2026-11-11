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

## Authored world artwork (v0.6)

New scenery and materials were generated specifically for this revision on
10 November 2026. These PNGs are unchanged copies of the original generated
outputs. Atlas regions select whole objects, with transparent padding.

| File | Contents and use |
| --- | --- |
| `assets/world/resources-a.png` through `resources-d.png` | Four different woodland objects and two quarries per sheet; 14 woodland and eight quarry frames are used, each once |
| `assets/world/ores.png` | Six different ore formations, each assigned once |
| `assets/world/landmarks.png` | Six complete objects in a 3-column × 2-row atlas: ruined watchfort, broken wagon, jetty/boat, chapel, windmill and stone arch |
| `assets/world/cliffs.png` | Three distinct cliff formations, one per cliff site |
| `assets/world/north_crown.png` | One northern boundary ridge |
| `assets/world/north_gate.png` | One mountain formation overlooking the north side of the pass |
| `assets/world/south_gate.png` | One southern pass formation |
| `assets/world/south_buttress.png` | One southern boundary formation |
| `assets/world/ground.png` | Full-map ground painting guided by the authored geography and paths |
| `assets/world/wall-stone.png` | Tileable granite masonry for textured wall faces and parapets |
| `assets/world/wall-walk.png` | Tileable weathered oak planks for wall walkways |

These files describe the previous v0.6 map. Its landmark and ridge art remains for compatible old settlements. The former resource atlases are excluded from current exports; producer scenery now uses the shared woodland atlas.

## Connected woodland artwork (v0.7)

Original images generated on 11 November 2026 follow a single composition study:
muted olive pine and oak, mossy grey limestone, overhead view and upper-left light.
`assets/woodland/` contains continuous canopy sections fitted to the authored
forest belts, four matching low escarpment images, and `sites.png` (2 columns ×
3 rows: three small legacy groves, then three related limestone outcrops).
New settlements render timber working pockets in the continuous forest; they do
not add isolated grove images on top. Stone and ore sites reuse the same geology.
The source PNGs are unchanged image-generation outputs. Reference screenshots
remain outside the repository and game.

The layout and protected clearings are in `assets/world/woodland.json`. `tools/bake_canopy.py` reads source-image alpha to fit forest collision to the visible canopy without modifying any image. The
terrain bake stores woodland cells in the same authoritative field as all other
obstacles. Forest artwork is rendered at native imported resolution above the
cached floor; linear sampling and disabled edge wrapping avoid seams. New
woodland textures use ETC2/S3TC compression, a 2,048-pixel limit and no mipmaps.

`assets/world/overview.png` and `wall-icon.png` are **game-engine renders**, not
additional generated paintings: `tools/capture_authored.gd` renders the actual
world and the textured wall geometry. The minimap therefore follows the same
layout as the game. The original ground-material atlas supplies sharp close-up
detail over the macro painting. Original generated PNGs have not been retouched
with image-processing scripts.

Earlier mobile artwork uses VRAM compression and mipmaps, with a 2,048-pixel import limit.
Runtime atlas regions include each complete selected object. Transparent-corner
checks and actual-game views were reviewed for opaque pale background patches.
Building pivots and centered dirt decals retain the v0.5 ground alignment.
Legacy mountain artwork remains for existing save layouts.

The **They Are Billions** reference informed settlement-defense play and the relationship between dense terrain, clearings and chokepoints. The visual style and all game assets are original. No art or screenshots from that game are included.

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
