# The Pinewatch Frontier

## Direction

A freely built settlement faces increasing pressure along one western approach.
The player chooses positions and defensive lines rather than filling prescribed
plots. The gameplay reference is the colony-defense structure of **They Are
Billions**; the world and art are original, and this is a smaller single-mission
game, not a reproduction of that title.

The illustrated buildings remain recognizable from the first prototype. Raster
terrain materials, vegetation, unit animation and a restrained textured command
deck replace the original flat terrain, geometric people, resource symbols and
rounded dashboard panels.

## World and placement

The world is 8,192 × 5,120 units. The headquarters is at (4,800, 2,800), and one
winding road connects the western boundary to it. Forest groves, quarries, gold
ore, ridges, scattered vegetation, and a large eastern lake give the valley
geographic landmarks. Geography is deterministic and shared by rendering,
placement checks, production bonuses, and the minimap.

Placement snaps to a fine 16-unit grid. Each building has a footprint; collisions,
water, ridges, map boundaries and resource cores reject construction before any
materials are spent. There are no fixed pads or reserved wall checkpoints.
There is one main hall and room for up to 512 structures. Clearing ruins reuses
storage slots and ground without growing the building array indefinitely.

Construction clears nearby decorative vegetation. A bounded 128 × 80 grid stores
those clearings, including after demolition and across save restoration.

## Economy and progression

- The hall supplies 1.5 timber, 0.9 stone and 0.45 gold per second.
- Producers become operational after 2.5 seconds of construction.
- Woodcutters and stonemasons receive +25% output within 520 units of their
  respective resource grove or quarry.
- Deposits refill every 12 seconds. Their yields slowly rise with mission time.
- Buildings start at level 1 and cap at 100.
- Maximum health scales by `1.11^(level − 1)`.
- Damage and production scale by `1.14^(level − 1)`.
- Upgrade costs scale by `1.13^(level − 1)` and round upward.
- Range rises gradually, capped at +55 units; attack periods improve by at most 50%.
- Upgrades preserve the building's health percentage, rather than healing it.
- Repair cost depends on missing health and `1.08^(level − 1)`.
- An active marketplace buys 60 wood or stone for 60 gold, and sells 60 supplies
  for 30–55 gold depending on level. The spread remains positive at level 100.

Ruins retain levels but stop attacks and production. Repair restores them;
confirmed clearing permanently removes them. Standing structures return 25% of
base construction materials when dismantled. The hall cannot be dismantled;
its destruction ends the mission.

## Combat

The model uses 0.05-second steps. Enemies are present from the first frame, and
the hall can attack them immediately. Waves arrive every 30 seconds. The wave
size grows from 10 toward 220; every fifth wave can reach 300 attackers. Runners,
armored brutes and occasional siege carts add different speeds and threats.

Base enemy health scales by `1.065^(wave − 1)` and damage by
`1.055^(wave − 1)`. Exponents are bounded to keep arithmetic finite; waves
continue increasing in number. A 2,400-enemy population bound protects memory.

The approach has nine loose crowd lanes with small positional variation. Bodies
maintain headway, so an army queues behind its frontline instead of stacking on
identical coordinates. Buildings and walls in reach are attacked. Standing walls
stop that part of the approach; ruined walls permit passage. Siege carts can
attack from farther away. Arrow towers focus individuals; cannons damage groups.

Spatial indexes limit target searches to nearby cells. Positions are cached
within each step, idle defenses search less often, and enemy target refreshes run
at five hertz with immediate invalidation of destroyed or removed targets.

Victory occurs at 900 in-game seconds if the hall survives. The player can
continue into endless survival. The 1×/2× option changes simulation speed, so
victory is measured in game time.

## Rendering and controls

Ground materials are composed once into a 4,096 × 2,560 cached texture. The lake
has a separate animated raster material. Scenery and entities are culled against
the camera and depth sorted by foot position. Four-frame character sprites,
workers, smoke, projectiles, brief death animations and building collapse provide
motion without geometric placeholder characters.

Ground shadows are batched together before units. Interface frames use native
nine-patch rendering, with a bounded cache of texture styles. The stress fixture
and renderer instrumentation distinguish simulation cost from draw-command cost.

One-finger drag or mouse/WASD moves the camera; pinch, wheel or zoom buttons
change scale. The minimap and Hall button provide navigation. Tap release is
separated from dragging so panning does not place buildings. Two-finger input
suppresses tap placement. Desktop and Android use the same logical canvas.

## Saves and lifecycle

Save version 2 stores free building positions, ruins, levels, health, enemies,
wave state, random-generator state, resource cooldowns, cleared vegetation,
camera and zoom. Full-precision JSON reduces rounding; restoration validates
all fields before accepting the settlement. Files are atomically renamed over
the previous save. JSON round trips are compared within floating-point precision.

The frontier uses `frontier-settlement.json`; version-1 fixed-plot saves are left
intact but are not loaded into the new map. Settings and best time persist.

App backgrounding pauses and saves. Foregrounding requires explicit resume and
refreshes the cached ground target. Actor and projectile animations pause with
the simulation. Back cancels construction or toggles pause, with automatic engine
quit-on-Back disabled.
