# Battlefield abilities

Rain of Arrows sends arrows down from the sky into a player-targeted battlefield
circle. On mobile: select the ability, tap to place/move its circle, then confirm.
Selecting or previewing never spends a cast. Cancel/Back exits targeting; camera
panning, pinch zoom and minimap navigation remain available. Do not add tutorial
toasts. Show actual radius, damage, duration and remaining cooldown.

Owner confirmed a **60-game-second recharge** for the free cast. Do not add
cooldowns to existing buildings.

Implementation values: 220-unit radius, three-second barrage, six damage pulses
50 damage each. Total damage is 300 at Arrow tower research level one, scaling
by the existing 1.10 damage multiplier per Arrow tower level. These are proposed
implementation values for the new ability, not separate owner-specified numbers.
No separate ability research, building requirement, resource fee or friendly
fire is introduced. Existing weapon damage and upgrade prices stay unchanged.

Cooldown starts only when confirming a valid battlefield target. Pause freezes
cooldown and barrage time; speed changes advance both in game seconds. Damage
comes from the simulation and pays ordinary kill gold exactly once. Persist
remaining cooldown, active circle, pulse count/timing and captured cast damage.
Reload must neither repeat a pulse nor reset the recharge. Death of the Main
hall stops combat; killing the final Warlord still uses the existing victory rule.
