# Assets and credits

## Building atlas

`assets/art/buildings.png` was generated specifically for Tabara using OpenAI
image generation on 2026-11-09. It contains seven isometric buildings and a pine
cluster, in a 4×2 transparent atlas. Rendering uses atlas regions directly;
the original generated image is preserved in the working environment.

Grid order: main hall, woodcutter, stonemason, arrow tower, wall, cannon tower,
marketplace, pines. Terrain, enemies, worker animation, shadows, smoke,
projectiles, gathering effects, icons, and interface panels are drawn by code.

## Audio and icon

All audio was synthesized for this project with the reproducible
`tools/generate_audio.py` script. No sampled commercial audio or external music
is included. `assets/icon.svg` is original vector artwork for this game.

## Fonts

The body font is **Noto Sans Regular**. The display font is **Noto Serif Display
Bold**. Both are distributed under the **SIL Open Font License 1.1**. See
`assets/fonts/OFL.txt` for the supplied license and copyright information.

## Engine

Godot is distributed under the MIT license. Exported binaries include Godot and
its third-party dependencies. Godot's license and third-party notices are
available at https://godotengine.org/license/ .
