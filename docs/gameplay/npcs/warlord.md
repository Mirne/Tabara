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
