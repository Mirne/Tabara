# Hearthvale Basin settlement ages

## Direction and geography

One western entry pressures a freely built settlement. The gameplay reference is
**They Are Billions**; the art is original and this is a smaller, single-mission
game. Raster buildings, animated characters, connected woodland and limestone,
and a textured command deck establish the visual style.

The world measures 8,192 × 5,120 units. The Hall stands at (4,800, 2,800).
Two mountain spines enclose a 480-unit pass at y=2,560–3,040. Twelve single-cell
wall sections at x=4,180 can seal the pass. Existing saved 80-unit walls keep
their original span.

Layout six defines two working sites in `assets/world/workyards.json`. The
timber yard at (4,800, 2,480) sits below the north canopy. The stone yard at
(4,680, 3,120) faces the southern limestone from the meadow's edge. Both
foundations sit off the traffic roads. Narrow cart tracks branch from the town
road to each apron. The timber stack, saw bench, cut blocks and stone sled belong
to their respective yard paintings. The opening camera frames both working sites
and the intervening Hall.

Layouts four and five keep their eight original sites and layouts zero through
three keep their 28 sites. A shared 40-unit terrain grid governs placement, red
cell overlays and navigation. Forest, rock, resources, water and mountain cells
block passage. A matching producer can occupy a resource foundation. Canopy
infill and a flood fill keep construction in the connected clearing.

A new settlement can build one Woodcutter, one Stonemason, one Marketplace and
one Workshop. Legacy settlements retain all paid producers, including several
of one type. Their positions, income and purchased levels survive loading. A
new producer of a given type can be built when its last standing instance falls.
It uses a matching site on that settlement's own map. All foundations occupy
whole cells. Defense buildings may meet at their edges. Destruction frees the
foundation and building slot. A settlement can support 512 standing structures.

## Economy and upgrades

Starting supplies are 450 wood, 320 stone and 180 gold. The hall supplies
0.8 wood, 0.45 stone and 0.1 gold per second. Producers have base output four
wood or five stone per second, with a 25% matching-site bonus. Ordinary buildings
finish construction in 2.5 game seconds; the Workshop takes six. The Marketplace
restores its earlier base output of two gold per game second, increased by its
own income upgrades. Buying/selling and trade cooldowns are removed. Kills also
provide gold.

The Main hall's Age panel advances the settlement through Wood, Stone, Iron,
Steel, Keep, Castle, Citadel and Crown. Every standing building, wall, build
preview and tower project icon follows that age. The Hall's Building panel
keeps its local health and weapon upgrade. The Age panel shows the next Hall
and the research ranks the purchase unlocks.

The Workshop sells separate arrow and cannon projects. Arrowheads improve arrow
damage, Bow limbs extend range and Quick nocking increases the firing rate.
Round shot improves shell damage, Burst shells enlarge the blast and Loading
crew shortens the reload. A purchased rank applies to standing and future towers
of its family. The purchase panel shows the exact projected stat and price.
Wall reinforcement and Regeneration remain settlement-wide Workshop purchases.
The [upgrade specification](gameplay/upgrades.md) defines rank gates and prices.

Woodcutters, quarries, the Hall, Marketplace and Workshop upgrade individually.
Replacements start at level one. Health scales by `1.085^(level − 1)` and
producer output by `1.08^(level − 1)`. Local prices scale by `1.15^(level − 1)`.
Upgrades preserve the building's health percentage.

Regeneration is a separate global Workshop upgrade, initially level zero. Unlocking
costs 120 wood, 90 stone and 60 gold, scaling by `1.15^current level` and rounded
up. It caps at 100. Its healing fraction per second is zero while locked, otherwise
`0.003 + (level - 1) × (0.20 - 0.003) / 99` of each building's maximum health, capped at 20% per game second. Completed,
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

Producers, including passive-gold Marketplaces, attract enemies within 1,600 world
units. Scans are staggered about one to two seconds apart. The nearest reachable
producer is approached using passable cells along its foundation perimeter;
resource cores remain solid. Destroying one producer allows acquisition of another.
Firing defenses can interrupt producer aggro. Existing wall collision remains in
force, so intervening walls are attacked before reaching the target.

Spatial indexes, five-hertz local crowd separation, bounded neighbor searches,
and short target caches limit per-step work. Towers prioritize threats near the
hall. Kill rewards vary by enemy type, are paid once, and show a coin
visual. The final Warlord enters at 900 game seconds. Victory requires killing
that specific boss while the Hall survives. Hall destruction takes precedence
if both fall in one simulation tick. Further waves continue during the encounter;
endless mode follows victory. Speed controls change game time.

New walls use one 40×40 terrain cell, centered inside it. Manhattan strokes
step by 40, skip blocked terrain and confirm at most 64 new sections. Only
eligible, non-overlapping cells are charged. Existing endpoints are reused.
Prices, HP and global wall levels remain unchanged. Cardinal neighbors share
continuous textured stone faces and wooden decks. Only the outer boundary has
vertical faces, parapets and corner caps; dense blocks have no interior rails.
Dirt patches, picking bounds and health bars match the actual footprint.

Old saved 80×80 walls keep their physical foundation, health and level. Each
renders as four joined 40-unit tiles; new cells can join its perimeter. It remains
one logical building, so migration does not change health, resources or the
512-structure capacity. Destruction opens its original footprint. New walls
store their 40-unit footprint explicitly.

A Warlord enters every 300 game seconds at the western entrance. Boss baseline
health is 26 times ordinary health, attack 4.5 times ordinary attack, and speed
62% of ordinary speed. Regular interval N further multiplies health by
`1 + 0.5 × (N - 1)` and damage by `1 + 0.15 × (N - 1)`. Boss wave growth uses at
least wave `N × 10 + 1`, avoiding floating-point boundary differences. The 15:00
final boss instead has four times the old same-wave boss health and twice its
damage: about 29,864 HP and 620 damage versus about 2,328 HP at 05:00 and 6,253 HP
at 10:00. Later regular bosses continue scaling. Incoming damage has no special
resistance or per-hit limits, and boss kills still award 60 gold.

The final boss is identified separately from other Warlords. Killing an earlier
miniboss after 15:00 cannot win. A saved interval counter and final-boss identity
prevent duplicate spawns after reload. At the population cap, the final boss has
priority over ordinary reinforcements as soon as a slot opens. Missed regular
intervals remain queued. The final boss follows normal navigation, blocking and
retaliation rules and has a persistent health bar.

Warlords have a **three-game-second smash cooldown**, starting when they wind
up. A 0.6-second red warning circle precedes twice their existing melee damage
to all building foundations within 160 units of the strike center. Movement
stops during the wind-up, and killing the boss cancels the pending hit. Normal
melee uses its existing cadence outside the special attack. The warning, hammer
animation, impact dust and shockwave follow actual simulation state.

War cry is a permanent, non-stacking aura. Non-boss enemies within 360 units move
30% faster while retaining their stored base speed, attack and health. The bonus
ends on leaving the aura or when its boss dies. A subtle ground aura and affected
unit glow show the effect. All Warlords, including later endless bosses, use both
abilities; spawn schedules and their existing strength curve are preserved.

Rain of Arrows is available from the start, with a free cast every **60 game
seconds**. A 220-unit circle receives six 50-damage pulses during a three-second
barrage. Damage scales with the existing Arrow tower research multiplier
`1.10^(level-1)` and is captured on casting. It damages enemies only and uses
normal kill gold and final-boss victory rules. Select the ability, tap a circle,
then confirm Release arrows. Cancelling or moving the camera spends nothing.
The right panel shows current damage, radius, duration and recharge. No new
building fee, research subject or tutorial popup is added.

## Rendering and mobile interaction

A macro ground painting and sharp raster materials are composed into a cached
4,096 × 2,560 ground target. Forest sprites retain native imported resolution
above it. Water is separately animated. Entities are culled and sorted by their
feet with a deterministic tie-break at equal Y positions. Occupied resource rocks
are drawn directly before their quarry in the same entity group; workers, smoke, four-frame unit strips, projectiles and brief collapse FX
provide animation. All six combat types use four painted attack poses, selected
from their actual attack state and existing 1.15-second damage cadence. Sprites
mirror from movement or target direction, retain that direction on death, and
keep their foot anchor between walk and attack sheets. Reduced motion uses a
stationary strike pose. The launcher and startup use a painted Hall emblem.
The minimap is an engine render of each layout. Layouts three through five keep
their previous overviews. Layout six uses the two-yard overview. A completed
producer's worker shuttles across its apron toward its stockpile or stone sled.

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
Selected buildings show health, current output/attack, next-level effects and
exact costs. Generic Workshop directions and tutorial toasts are removed. Purchase
buttons say Upgrade. Local upgrades are paid from the selected building panel.
The Workshop has Upgrades and Building tabs; Regeneration is one subject beside
Wall, Arrow tower and Cannon tower. Its own health upgrade is under Building.
Paused controls cannot activate underlying gameplay buttons.

One finger pans except during wall strokes; two fingers pan and pinch during
placement. Hall and the minimap navigate quickly. Speed cycles 1×/2×/5×/10×.
Back cancels placement or toggles pause. Mouse, wheel and desktop hotkeys use the
same logical canvas. No Guide or mobile zoom buttons are shown.

## Saves and reproducibility

Format twelve records settlement age, the six independent tower ranks, per-building local levels and global defense levels, Regeneration, the miniboss interval
counter, final-boss identity/defeat, earned victory, attack/facing state, smash warning/cooldown/center, Rain recharge and active
barrage pulse state, per-wall footprint, terrain revision, structures, enemies, retaliation,
economy, mission time, random state, camera and zoom. No trade cooldowns, active research or manual repair jobs are stored. Transient A* paths are rebuilt after load. JSON uses full
precision, validates fields, and is atomically renamed over the prior file.
Backgrounding pauses and saves; foregrounding requires resume. Rain and smash
clocks use game time and retain partial progress through reloads. Completed
barrage timers clamp floating-point residue before saving, including the exact
final-pulse frame; resuming never duplicates a damage pulse.

Versions 2–11 preserve terrain, positions and sites (layouts 0–5).
Standing non-defense buildings retain their old purchased levels as individual
levels; new replacements begin at one. Buildings keep their old defense grades. Arrow and cannon damage research inherits its old grade. Existing tower health, range and fire rate retain their purchased benefits. A paid
version-seven research order completes once on migration without another charge,
including if its Workshop is gone. Remaining paid local repair finishes once;
then its job is removed. Versions 2–7 initialize Regeneration locked; version-eight saves retain their
purchased Regeneration level. The old
elapsed time seeds the miniboss interval counter so past bosses are not spawned
retroactively. Version-one fixed-plot files remain untouched and are not loaded.
Completed old endless saves retain their earned victory. Unfinished old saves
require the new final boss, including late unfinished saves whose old miniboss
counter already reached three. Existing living old bosses retain their stats and
are not reclassified as the final encounter. The off-path sites originally added in
v0.9 remain specific to layout five; legacy maps remain unchanged.

`tools/bake_world.gd` reproducibly stores seven terrain/navigation fields. The six
legacy terrain and route fields match v0.12 exactly. Tests compare all caches to fresh geography and shortest
paths, exercise movement, all local/global levels through 100, miniboss boundaries,
Regeneration, destruction, migration, repeated construction and mobile/native
Android lifecycle handling. Balance uses paid player orders; explicitly labeled
visual and boundary fixtures isolate graphics or timing behavior.

Persistent owner decisions and the individual behavior contracts are recorded in
[gameplay notes](gameplay/NOTES.md) and [building/NPC specifications](gameplay/INDEX.md).
