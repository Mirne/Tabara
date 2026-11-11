# Hearthvale Basin

## Direction

A freely built settlement faces increasing pressure from one western entry.
The player chooses positions and defensive lines rather than filling prescribed
plots. The gameplay reference is the colony-defense structure of **They Are
Billions**; the world and art are original, and this is a smaller single-mission
game, not a reproduction of that title.

The illustrated buildings remain recognizable from the first prototype. Raster
terrain materials, vegetation, unit animation and a restrained textured command
deck replace the original flat terrain, geometric people, resource symbols and
rounded dashboard panels.

## World and placement

The world is 8,192 × 5,120 units. The headquarters is at (4,800, 2,800), and an
authored trail network crosses the valley. The original road data remains for
legacy saves and the western spawn. Two mountain spines touch
the map boundaries and leave a 480-unit pass at y=2,560–3,040. Six wall
sections centred at x=4,160 can seal the pass. Attackers choose
a direct land route to the hall. Forest groves, quarries, gold
ore, four custom ridge formations, six unique landmarks, and an irregular eastern lake give the valley
geographic landmarks. Geography is deterministic and shared by rendering,
placement checks, production bonuses, and the minimap.

Placement snaps to a visible 40-unit grid. Rectangular foundations occupy whole
grid cells and may meet without overlapping. The same cached 40-unit terrain
mask drives placement, red grid cells and enemy navigation. Resource cores,
water, ridges, mountains and boundaries are impassable. A matching producer
is the one construction exception on its resource core. Standing structures
are red and physically block attackers until destroyed; ruins are amber and
allow passage. Each building has a footprint; collisions,
water, ridges, map boundaries and resource cores reject construction before any
materials are spent. There are no fixed defense pads or reserved wall checkpoints. Woodcutters and
stonemasons require matching deposits, one producer per deposit. Ruins retain
that claim; clearing releases it. Existing v0.2 producers retain their locations
and reserve the closest matching site.
There is one main hall and room for up to 512 structures. Clearing ruins reuses
storage slots and ground without growing the building array indefinitely.

Each forest and quarry is a compact, single raster image with no pale base mat. Resources have no tap
interaction, collection button or floating refill timer. A matching producer
occupies each site; resource cores remain protected from unrelated buildings.

The authored layout uses no random scenery scatter. Its 41 major objects have
deliberate positions and distinct atlas frames: 28 resource sites, four ridges,
three cliffs, and six landmarks. Old clearing cells remain bounded and preserved
for save compatibility. Every forest and quarry uses one compact custom object.

## Economy and progression

- The hall supplies 1.5 timber, 0.9 stone and 0.45 gold per second.
- Producers become operational after 2.5 seconds of construction.
- Woodcutters and stonemasons receive +25% output within 520 units of their
  respective resource grove or quarry.
- Resource sites cannot be manually collected. Producers, the hall, markets
  and kills supply the economy; old deposit timers remain only for save compatibility.
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

The model uses 0.05-second steps. The first enemy starts at progress zero on the
western path entrance; new games have no near-hall vanguard. The hall attacks
automatically once enemies reach its range. Waves arrive every 30 seconds. The wave
size grows from 10 toward 220; every fifth wave can reach 300 attackers. Runners,
armored brutes and occasional siege carts add different speeds and threats.

Base enemy health scales by `1.065^(wave − 1)` and damage by
`1.055^(wave − 1)`. Exponents are bounded to keep arithmetic finite; waves
continue increasing in number. A 2,400-enemy population bound protects memory.

Enemies have actual two-dimensional world positions. A shared reverse Dijkstra
field on the shared 40-unit grid routes around resources, water, cliffs and mountains; clear line of sight
allows a direct heading to the hall. Eight neighboring terrain cells participate,
with no diagonal corner cutting. Same-cell and adjacent-cell movement use
constant-time checks; larger debug moves retain a sampled fallback. Tight turns
can recenter within an open cell. Buildings do not divert the route: a swept
foundation test finds the first blocking structure and attackers destroy it
before advancing through its ruins. Nearby structures outside the route are
ignored. Siege carts attack from farther away.

Static terrain and Hall route fields are baked into `assets/world/hearthvale.json`
by `tools/bake_world.gd`. A terrain fingerprint guards the navigation cache. A
custom Hall destination or invalid cache falls back to a fresh search. Tests
compare baked and computed terrain, links and costs for every supported layout.

Local crowd separation is cached at five hertz and bounded to 40 nearby bodies
per search. Spatial indexes cache expanded building rectangles and attack
candidates. Stationary attackers reuse their target for 0.2 seconds while
checking that the same live structure still blocks them. Towers prioritize
threats near the hall; cannons damage groups.

Walls use 80-unit segments on the construction grid. A drag previews a Manhattan
stroke, with a maximum of 64 sections per confirmation. Existing live endpoints
are reused without charging twice. The complete stroke is validated before any
materials are spent. Cardinal neighbors share a textured prism footprint. Stone front/side faces,
wooden walkways, parapets and crenels produce the raised fortification. Hidden
internal end faces are omitted; straight interiors have no repeated end piers.
Corners and junctions have reinforced piers. Original masonry and plank textures
are sampled with continuous world-coordinate UVs instead of cropping wall strips.
Destroyed sections leave a breach; repairing them reconnects the course. Each
section retains its own health, level, upgrade and repair actions.

Kills award rounded gold based on wave, with higher rewards for brutes and
siege carts. Each death is paid once and carries a coin reward visual.

Victory occurs at 900 in-game seconds if the hall survives. The player can
continue into endless survival. The 1×/2×/5×/10× cycle changes simulation speed, so
victory is measured in game time.

## Rendering and controls

An original ground painting sets broad geography and color. Sharp raster ground
materials follow an offline surface mask for trails, meadow, rocky ground, wet
shore and the drier southwest. They are composed once into a 4,096 × 2,560 cached
texture. The irregular lake has a separate animated raster material clipped to
its bounds. The minimap is rendered from the actual authored world. Large
formations use unique images, each placed once. Scenery and entities are culled against
the camera and depth sorted by foot position. Four-frame character sprites,
workers, smoke, projectiles, brief death animations and building collapse provide
motion without geometric placeholder characters.

Ground shadows are batched together before units. Interface frames use native
nine-patch rendering, with a bounded cache of texture styles. The stress fixture
and renderer instrumentation distinguish simulation cost from draw-command cost.

The construction cards and inspector occupy the right rail. Selecting a card
shows the grid; a world tap previews a location without spending. The separate
Build confirmation revalidates resources, the foundation and deposit ownership.
A successful build exits placement mode. Cancel spends nothing. Tower
previews show a range circle at the proposed position. Upgrade and Repair
keep distinct, permanent price rows; damage cannot swap the displayed upgrade
price to a repair quote. Building sprites and dirt decals share the same
ground-centred anchor.

One-finger drag or mouse/WASD moves the camera, except that the wall tool uses
a world drag to draw a preview. Two-finger input pans and zooms during wall
placement and never confirms construction. Pinch or wheel input changes scale. The mobile +/− controls and Guide buttons
are removed. Hall sits in the top bar, and speed cycles 1×, 2×, 5× and 10×. The minimap and Hall button provide navigation. Tap release is
separated from dragging so panning does not place buildings. Two-finger input
suppresses tap placement. Desktop and Android use the same logical canvas.

## Saves and lifecycle

Save version 5 stores free building positions, ruins, levels, health, enemy
world positions, cached movement/attack state and explicit terrain revision,
wave state, random-generator state, resource cooldowns, cleared vegetation,
camera and zoom. Full-precision JSON reduces rounding; restoration validates
all fields before accepting the settlement. Versions 2–4 retain their compatible
terrain layout (0 or 1); existing buildings and enemies are not moved to the
new map. Version 2 converts road progress into actual enemy positions. Legacy
buildings crossing the old mountain pass retain the earlier ridge-free layout.
New settlements use revision 2, the authored basin. A new settlement is therefore
required to see the new geography. Enemies caught in an old blocked resource
cell recover to the nearest open cell on their next step. JSON numeric version
values are normalized before validation. Files are atomically renamed over
the previous save. JSON round trips are compared within floating-point precision.

The frontier uses `frontier-settlement.json`; version-1 fixed-plot saves are left
intact but are not loaded into the new map. Settings and best time persist.

App backgrounding pauses and saves. Foregrounding requires explicit resume and
refreshes the cached ground target. Actor and projectile animations pause with
the simulation. Back cancels construction or toggles pause, with automatic engine
quit-on-Back disabled.
