# Warlord miniboss

Spawn every 300 game seconds, including endless mode. Preserve its original
wave-scaled health (26x), attack (4.5x), speed (0.62x), 60 gold reward, animation,
health bar, and saved interval counter. Ordinary incoming damage, no resistances.
Use [shared targeting](../targeting.md), including every exposed producer.

Health/damage/speed multipliers: 26 / 4.5 / 0.62. Reward: 60 gold. Separate 300-second interval counter, including endless mode.

Baseline HP = 50 × 1.06^(wave-1), attack = 12 × 1.06^(wave-1),
speed = 86 + min(34, wave×0.7). Exponents cap at 600. Attack period
1.15 game seconds; initial attack delay 0.5 seconds. Preserve these values.
