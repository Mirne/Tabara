# Hearthvale Basin: Stronghold

## Direction and geography

One western entry pressures a freely built settlement. The gameplay reference is
**They Are Billions**; the art is original and this is a smaller, single-mission
game. Raster buildings, animated characters, connected woodland and limestone,
and a textured command deck establish the visual style.

The world is 8,192 × 5,120 units, with the hall at (4,800, 2,800). Two mountain
spines leave a 480-unit pass at y=2,560–3,040. Six wall sections at x=4,160 can
seal it. The continuous forest belts, low escarpments and eastern lake remain
from v0.7. New layout four has only eight resource sites, defined in
`assets/world/stronghold.json`: two wood and two stone inside the base, with two
of each exposed west of the pass. Legacy layouts 0–3 retain their 28 sites.

A shared 40-unit terrain grid governs placement, red cell overlays and enemy
navigation. Forests, resource cores, water and mountains are impassable. A matching
producer is the sole exception for construction on a resource core. Producer
foundations are at accessible forest margins. Canopy infill closes the previous
isolated working pockets; a flood fill seals remaining disconnected grass cells.
Every ordinary open cell in layout four can be reached from the hall.

Foundations occupy whole grid cells. Defense buildings may meet without overlap;
producers require their matching site, one per site. There is one main hall and
at most one Marketplace and Workshop. Up to 512 standing structures are supported.
Destroyed non-hall structures become null slots immediately and release their
foundation/site. New construction reuses free slots. No repairable ruins remain.

## Economy and research

Starting supplies are 450 wood, 320 stone and 180 gold. The hall supplies
0.8 wood, 0.45 stone and 0.1 gold per second. Producers have base output four
wood or five stone per second, with a 25% matching-site bonus. Ordinary buildings
finish construction in 2.5 game seconds; the Workshop takes six. The Marketplace
has no passive gold income: it buys 60 supplies for 90 gold with an eight-second
cooldown, or sells 60 for 30–55 gold with a six-second cooldown. Kills provide gold.

The Workshop researches one building type at a time. Completion updates all
existing buildings of that type; future buildings inherit the level. Global
levels start at one and cap at 100. Base duration is `35 + 8 × (current level − 1)`
seconds. Workshop levels increase research speed by 2% per level. Costs are twice
the old per-building base price, scaled by `1.15^(current level − 1)` and rounded
up. Losing the Workshop pauses an order; a replacement resumes it. Completed
research survives destruction and dismantling.

Health scales by `1.085^(level − 1)`, damage by `1.10^(level − 1)`, and producer
output by `1.08^(level − 1)`. Range and attack-period improvements are bounded.
Research preserves the current health percentage and adjusts any active repair
rate, preventing upgrades from acting as free healing. Local repairs charge a
missing-health quote once, then heal over eight seconds. Repeated taps cannot
create duplicate repair jobs. Dismantling a standing building returns 25% of its
base cost. The hall cannot be dismantled; its destruction ends the mission.

## Combat

Simulation uses 0.05-second steps. The first attacker spawns immediately at the
western entrance; new games contain no near-hall vanguard. Waves arrive every
30 seconds. Their count grows from ten toward 220; every fifth wave is doubled,
up to 300. Base enemy health is `50 × 1.06^(wave − 1)`, damage is
`12 × 1.06^(wave − 1)`. Exponents and population are bounded for numerical safety.
Runners, brutes and siege carts retain distinct speed/health/attack profiles.

Elites start at wave five. Every great horde guarantees one, and their random
share gradually rises to 20%. They have 5.5 times ordinary health, twice the
attack and 85% of ordinary speed. **All incoming damage remains ordinary**:
no splash resistance, armor reduction, per-hit cap, or arrow bonus. Base arrow
towers fire 30 damage every second. Cannons deal 110 area damage every three
seconds in a 140-unit radius. A fresh elite survives several base cannon shells.

Attackers use a cached reverse Dijkstra field to approach the hall, with direct
movement on clear terrain and no diagonal corner cutting. Shots provoke their
victims; arrow impacts can also alert nearby witnesses. A reachable firing defense
within 850 units becomes a temporary target for seven seconds, refreshed by
attacks. A cached AStarGrid2D path routes around static terrain; excessive detours
are rejected. Dynamic structures still block that path and are attacked first.
Adjacent exposed buildings, including producers beside resource cores, can also
be attacked. Enemies do not cross red terrain or pass through standing walls.

Spatial indexes, five-hertz local crowd separation, bounded neighbor searches,
and short target caches limit per-step work. Towers prioritize threats near the
hall. Kill rewards vary by enemy type, are paid once, and show a coin
visual. Victory occurs at 900 game seconds, then the player may continue endlessly.
Speed controls change game time, not the victory threshold.

Walls use 80-unit sections, Manhattan drag strokes, and at most 64 sections per
confirmation. Validation of the full stroke precedes payment. Live endpoints are
reused without charging twice. Cardinal neighbors share textured stone faces,
wooden walkways and continuous UVs. Internal end faces are omitted; corners and
junctions have reinforced piers. Destruction opens a breach; a newly built section
joins its neighbors and inherits global wall research.

## Rendering and mobile interaction

A macro ground painting and sharp raster materials are composed into a cached
4,096 × 2,560 ground target. Forest sprites retain native imported resolution
above it. Water is separately animated. Entities are culled and sorted by their
feet; workers, smoke, four-frame unit strips, projectiles and brief collapse FX
provide animation. The minimap is rendered from actual terrain. Layout three
retains its original overview, while layout four uses the revised overview.

With nothing selected, the right rail shows seven large construction cards.
Selecting a tool or structure hides the whole catalogue. The full rail becomes a
placement, building or Workshop panel. Preview and confirmation are separate;
Cancel never spends supplies. Producer tools draw bright green tiles and an outer
rectangle on available matching sites. Tower previews include their range.
Building panels offer local repair with its own fixed price row and navigation to
the Workshop, never a per-building upgrade. Workshop tabs separate global
research from maintenance of the Workshop itself. Paused controls cannot activate
underlying gameplay buttons.

One finger pans except during wall strokes; two fingers pan and pinch during
placement. Hall and the minimap navigate quickly. Speed cycles 1×/2×/5×/10×.
Back cancels placement or toggles pause. Mouse, wheel and desktop hotkeys use the
same logical canvas. No Guide or mobile zoom buttons are shown.

## Saves and reproducibility

Format seven records global levels, paid research progress, local repair jobs,
trade cooldowns, terrain revision, structures, enemies, retaliation targets,
economy, mission time, random state, camera and zoom. Transient A* routes are
rebuilt rather than serialized. JSON uses full precision, validates fields, and
is atomically renamed over the prior save. Backgrounding pauses and saves;
foregrounding requires resume.

Versions 2–6 preserve their original terrain (layouts 0–3), positions and producer
sites. The highest surviving legacy level per type becomes its global research
level; health fractions are normalized to current stats. Old non-hall ruins are
removed. Version-one fixed-plot files remain untouched and are not loaded.
A new settlement is required for the eight-site map.

`tools/bake_world.gd` reproducibly stores all five terrain/navigation fields.
Tests compare each cache against fresh geography and shortest-path searches,
exercise actual movement, research through level 100, saves, damage, destruction,
mobile controls and native Android lifecycle handling. Balance uses paid player
orders; explicitly labeled stress and visual fixtures may grant resources.
