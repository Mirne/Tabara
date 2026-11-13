# Hearthvale Basin: Open Approach

## Direction and geography

One western entry pressures a freely built settlement. The gameplay reference is
**They Are Billions**; the art is original and this is a smaller, single-mission
game. Raster buildings, animated characters, connected woodland and limestone,
and a textured command deck establish the visual style.

The world is 8,192 × 5,120 units, with the hall at (4,800, 2,800). Two mountain
spines leave a 480-unit pass at y=2,560–3,040. Six wall sections at x=4,160 can
seal it. The continuous forest belts, low escarpments and eastern lake remain
from v0.7. Layout five has eight off-path resource sites, defined in
`assets/world/open-approach.json`: two wood and two stone inside the base, with two
of each exposed west of the pass. Legacy layouts 0–3 retain their 28 sites; layout four retains its original eight.

A shared 40-unit terrain grid governs placement, red cell overlays and enemy
navigation. Forests, resource cores, water and mountains are impassable. A matching
producer is the sole exception for construction on a resource core. Producer
foundations are at accessible forest margins. Canopy infill closes the previous
isolated working pockets; a flood fill seals remaining disconnected grass cells.
Every ordinary open cell in layout five can be reached from the hall.

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

The Workshop buys instant global levels, one paid button press per level, for
existing and future buildings. There is no timed job or queue. Levels start at
one and cap at 100. Costs remain twice the old per-building base price, scaled
by `1.15^(current level − 1)` and rounded up. Completed upgrades survive Workshop
destruction, and another operational Workshop is needed for further purchases.
Workshop building levels improve its own health.

Health scales by `1.085^(level − 1)`, damage by `1.10^(level − 1)`, and producer
output by `1.08^(level − 1)`. Range and attack-period improvements are bounded.
Upgrades preserve health percentages rather than granting free healing.

Regeneration is a separate global Workshop upgrade, initially level zero. Unlocking
costs 120 wood, 90 stone and 60 gold, scaling by `1.15^current level` and rounded
up. It caps at 100. Its healing fraction per second is zero while locked, otherwise
`0.003 + 0.00015 × (level − 1)` of each building's maximum health. Completed,
standing buildings heal continuously, including during combat. Construction and
destroyed structures do not heal. Completed Regeneration remains active after
Workshop destruction and applies to future buildings. Manual repair actions and
repair timers are removed.

Dismantling a standing building returns 25% of its base cost. The hall cannot be
dismantled; its destruction ends the mission.

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
confirmation. Blocked terrain is skipped. The first complete green foundation establishes the stroke lattice, and neighboring walls align subsequent rows. Only eligible, non-overlapping foundations are charged; affordability and capacity are checked before construction. Live endpoints are
reused without charging twice. Cardinal neighbors share textured stone faces,
wooden walkways and continuous UVs. Internal faces and parapets are omitted. Dense blocks share one continuous deck and only exterior corners have capstones. Destruction opens a breach; a newly built section
joins its neighbors and inherits global wall research.

A Warlord miniboss enters at each 300-second boundary, starting at 05:00 and
continuing at 10:00, 15:00, 20:00 and beyond. It has 26 times ordinary health,
4.5 times ordinary attack and 62% of ordinary speed, all on the usual wave growth
curve. It awards 60 gold and has no incoming-damage modifiers. It spawns at the
western entrance, follows the same routing and retaliation rules, and has its own
four-frame raster strip and permanent health bar. A saved interval counter avoids
duplicate spawns after reload; population-cap delays are retained until a slot
opens. The 15-minute Warlord enters as endless mode unlocks; the original timed
victory condition is unchanged.

## Rendering and mobile interaction

A macro ground painting and sharp raster materials are composed into a cached
4,096 × 2,560 ground target. Forest sprites retain native imported resolution
above it. Water is separately animated. Entities are culled and sorted by their
feet; workers, smoke, four-frame unit strips, projectiles and brief collapse FX
provide animation. The minimap is rendered from actual terrain. Layout three
retains its original overview, while layout four retains its v0.8 overview; layout five uses the current overview.

With nothing selected, the right rail shows seven large construction cards.
Selecting a tool or building replaces the catalogue. A tap previews, and a
separate confirmation spends resources. After confirmation the tool remains
active, the preview resets, and the new building is not selected. Fifteen towers
therefore use one tool selection and fifteen preview/confirm pairs. Done building
or Back exits placement. Unique buildings use the same controls and still enforce
their one-per-settlement limit.

Producer tools draw filled green tiles and an outer rectangle on matching sites.
Tower previews show range. Wall strokes ignore blocked cells and preview only
eligible sections with their actual total price. A neighboring wall supplies its
lattice to keep parallel rows aligned. Construction panels and previews clear
without selecting a just-built section, so additional rows are quick to place.
Selected buildings show health and the global Regeneration rate, with Workshop
navigation and dismantling. There are no manual repair controls. The Workshop's
Upgrades and Regen tabs provide instant global purchases; Building opens the
Workshop's own health/dismantling details. Paused controls cannot activate the
underlying gameplay buttons.

One finger pans except during wall strokes; two fingers pan and pinch during
placement. Hall and the minimap navigate quickly. Speed cycles 1×/2×/5×/10×.
Back cancels placement or toggles pause. Mouse, wheel and desktop hotkeys use the
same logical canvas. No Guide or mobile zoom buttons are shown.

## Saves and reproducibility

Format eight records global building levels, Regeneration, the miniboss interval
counter, trade cooldowns, terrain revision, structures, enemies, retaliation,
economy, mission time, random state, camera and zoom. No active research or manual
repair jobs are stored. Transient A* paths are rebuilt after load. JSON uses full
precision, validates fields, and is atomically renamed over the prior file.
Backgrounding pauses and saves; foregrounding requires resume.

Versions 2–7 preserve original terrain, positions and sites (layouts 0–4).
The highest surviving pre-global level per type becomes its global level. A paid
version-seven research order completes once on migration without another charge,
including if its Workshop is gone. Remaining paid local repair finishes once;
then its job is removed. Regeneration starts locked for legacy saves. The old
elapsed time seeds the miniboss interval counter so past bosses are not spawned
retroactively. Version-one fixed-plot files remain untouched and are not loaded.
A new settlement is required for relocated resource sites.

`tools/bake_world.gd` reproducibly stores six terrain/navigation fields. The five
legacy fields remain byte-for-byte equal to v0.8; its original minimap remains
available separately. Tests compare all caches to fresh geography and shortest
paths, exercise movement, all global levels through 100, miniboss boundaries,
Regeneration, destruction, migration, repeated construction and mobile/native
Android lifecycle handling. Balance uses paid player orders; explicitly labeled
visual and boundary fixtures isolate graphics or timing behavior.
