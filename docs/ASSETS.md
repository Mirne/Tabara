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
| `assets/frontier/mountains.png` | Transparent rugged mountain cluster used along impassable spines |

## Authored world artwork (v0.6)

New scenery and materials were generated specifically for this revision on
10 November 2026. These PNGs are unchanged copies of the original generated
outputs. Atlas regions select whole objects, with transparent padding.

| File | Contents and use |
| --- | --- |
| `assets/world/landmarks.png` | Six complete objects in a 3-column × 2-row atlas: ruined watchfort, broken wagon, jetty/boat, chapel, windmill and stone arch |
| `assets/world/cliffs.png` | Three distinct cliff formations, one per cliff site |
| `assets/world/north_crown.png` | One northern boundary ridge |
| `assets/world/north_gate.png` | One mountain formation overlooking the north side of the pass |
| `assets/world/south_gate.png` | One southern pass formation |
| `assets/world/south_buttress.png` | One southern boundary formation |
| `assets/world/ground.png` | Full-map ground painting guided by the authored geography and paths |
| `assets/world/wall-stone.png` | Tileable granite masonry for textured wall faces and parapets |
| `assets/world/wall-walk.png` | Tileable weathered oak planks for wall walkways |

These files remain for compatible old settlements and shared ground/wall materials. Producer scenery uses the woodland atlas. Superseded resource sheets and wall-kit art have been removed from main; their originals remain in the [v0.6 source](https://github.com/Mirne/Tabara/tree/v0.6.0/assets).

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

`assets/world/overview.png`, `overview-v07.png` and `wall-icon.png` are **game-engine renders**, not
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

## Stronghold artwork (v0.8)

Generated on 12 November 2026, using the existing woodland and building palette:

| File | Contents and use |
| --- | --- |
| `assets/art/workshop.png` | Transparent limestone/timber Workshop, red tile roof and two chimneys |
| `assets/frontier/elites.png` | Four walking frames of a larger iron-clad raider with crimson cloth |
| `assets/woodland/canopy-infill.png` | Continuous pine/oak canopy patch closing old isolated logging hollows |
| `assets/world/overview-v07.png` | Preserved engine-rendered overview for legacy layout three |
| `assets/world/stronghold.json` | Authored eight resource sites and base bounds; data, not image art |

The three generated PNGs are unchanged copies of image-generation outputs. They
use compressed texture imports, no mipmaps and a 2,048-pixel limit. Infill sprites
are placed only within the existing forest composition; their visible crown edges
participate in collision. The new overview is rendered by the engine from layout
four. Helmeted elite artwork does not imply a damage resistance mechanic.

## Open Approach artwork (v0.9)

`assets/frontier/miniboss.png` was generated on 13 November 2026 with the elite
strip as the style reference. It contains four equal-width walking frames of an
original hammer-wielding Warlord, with a ridged iron crown, grey beard and crimson
cloak. The source PNG is an unchanged image-generation output. Texture import
uses VRAM compression, a 2,048-pixel limit and no mipmaps.

`assets/world/overview-v08.png` preserves the original v0.8 minimap. The current
`overview.png` and wall icon are fresh game-engine renders. The eight revised
resource coordinates are authored in `open-approach.json`; previous map data stays
available for legacy saves. New wall geometry uses the existing stone/plank
textures: one raised deck across touching rows and parapets only on the outside.
No source PNG was retouched to achieve the wall joins or resource relocation.

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
