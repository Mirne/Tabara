# Raider

Ordinary baseline enemy, spawned only at the west entrance. Existing wave-scaled
HP, attack, speed and kill gold are unchanged. Follow [targeting](../targeting.md):
seek exposed producers at longer range, break intervening walls, retaliate against
firing defenses, and return to the Main hall after local targets disappear.

Health/damage/speed multipliers: 1 / 1 / 1. Reward: 3 gold. Default wave enemy.

Baseline HP = 50 × 1.06^(wave-1), attack = 12 × 1.06^(wave-1),
speed = 86 + min(34, wave×0.7). Exponents cap at 600. Attack period
1.15 game seconds; initial attack delay 0.5 seconds. Preserve these values.
