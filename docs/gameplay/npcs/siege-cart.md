# Siege cart

Existing siege enemy with longer attack reach. Preserve stats, reach and reward.
Use [shared targeting](../targeting.md), including all exposed resource producers.
Terrain and standing walls still block movement. Ordinary incoming damage.

Health/damage/speed multipliers: 7 / 3.5 / 0.55. Reward: 14 gold. Last spawn of a fifth wave from wave 14 onward; attack reach 220 world units.

Baseline HP = 50 × 1.06^(wave-1), attack = 12 × 1.06^(wave-1),
speed = 86 + min(34, wave×0.7). Exponents cap at 600. Attack period
1.15 game seconds; initial attack delay 0.5 seconds. Preserve these values.
