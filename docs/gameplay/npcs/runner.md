# Runner

Fast raider variant. Preserve current health, attack, speed and kill reward.
Use [shared targeting](../targeting.md), including all exposed resource producers
and the same impassable terrain rules. No weapon-specific resistance or bonus.

Health/damage/speed multipliers: 0.65 / 1 / 1.55. Reward: 3 gold. Eligible from wave 4, roll below 0.22 before elite selection.

Baseline HP = 50 × 1.06^(wave-1), attack = 12 × 1.06^(wave-1),
speed = 86 + min(34, wave×0.7). Exponents cap at 600. Attack period
1.15 game seconds; initial attack delay 0.5 seconds. Preserve these values.
