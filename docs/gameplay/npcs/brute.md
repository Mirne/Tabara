# Brute

Heavier raider variant. Preserve current wave-scaled stats and reward.
Use [shared targeting](../targeting.md), including larger producer detection,
defense retaliation and attacking walls that block the route. Ordinary damage.

Health/damage/speed multipliers: 2.8 / 1.9 / 0.75. Reward: 5 gold. Eligible from wave 7, roll above 0.78.

Baseline HP = 50 × 1.06^(wave-1), attack = 12 × 1.06^(wave-1),
speed = 86 + min(34, wave×0.7). Exponents cap at 600. Attack period
1.15 game seconds; initial attack delay 0.5 seconds. Preserve these values.
