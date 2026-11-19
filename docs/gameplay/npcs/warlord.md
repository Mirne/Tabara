# Warlord miniboss and final Warlord

Spawn at the west entrance every 300 game seconds, including endless mode.
Regular interval n scales the old same-wave boss HP by 1 + 0.5*(n-1), and attack
by 1 + 0.15*(n-1). The 15:00 encounter instead uses 4x the old same-wave boss HP
and 2x its attack. It is the final mission boss, identified separately in saves.

Old same-wave boss baseline: HP = 26*50*1.06^(wave-1), attack =
4.5*12*1.06^(wave-1), speed = 0.62*(86+min(34,wave*0.7)). Exponents cap at
600. Keep speed, 60 gold reward, ordinary incoming damage and the 1.15-second
attack cadence. No cannon resistance or arrow bonus.

Reaching 15:00 does not pause or complete the mission. Kill the final Warlord
while the Main hall survives to win; then endless survival is available. Other
waves continue during the final fight. Later 20-, 25-minute and subsequent
minibosses continue scaling. A full population delays a queued boss until a slot
is available; pending final boss has priority over normal reinforcements.

Save boss interval, final identity, kill/completion and facing/attack state.
Restore without duplicate bosses or false time-based victory. Completed legacy
endless settlements retain their previously earned win; unfinished late legacy
saves get one final boss without replaying old intervals.

Use [shared targeting](../targeting.md). Dedicated four-frame hammer attacks
show wind-up, impact, follow-through and recovery. Face the building during a
strike and horizontally mirror the same artwork for leftward movement/attacks.
Keep the feet anchored. Reduced motion uses a still attack pose.

## Abilities requested after v0.11

Owner clarification: use a smash on a **3-game-second cooldown**, not 12, and
make war cry a **continuous passive aura**, not a temporary timed activation.
All Warlords use both; normal melee damage/cadence outside the smash animation,
base stats, spawn schedule, rewards and final-boss objective stay unchanged.

Smash implementation: at building contact, warn a 160-unit ground circle for
0.6 game seconds, then deal twice this Warlord's existing melee damage to each
standing building whose foundation intersects the circle. Start the 3-second
cooldown when winding up. Freeze movement during wind-up; killing the boss
cancels its pending smash. Save cooldown, warning time and circle position so
reloads neither reset nor duplicate it. Use hammer wind-up/strike artwork and a
dust/shockwave impact. These geometric/damage values implement the requested
ability and scale through the existing Warlord damage; they are not separate
owner-specified balance numbers.

War cry continuously grants nearby non-boss enemies 30% extra movement speed
within 360 units. Auras do not stack. Preserve their stored base speed, health,
damage and attack cadence; the bonus ends when leaving range or the boss dies.
Show a subtle continuous aura and an affected-unit ground glow. The owner accepted
war cry and made it permanent; 30% was in the proposed ability, while 360 units
is the implementation radius.
