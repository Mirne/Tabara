# Elite

Stronger health/attack variant starting at wave five; every great horde guarantees
one. Preserve existing scaling, speed and reward. The owner explicitly rejected
cannon resistance and bonus arrow damage. All incoming damage stays ordinary.
Use [shared targeting](../targeting.md), including every exposed producer.

Health/damage/speed multipliers: 5.5 / 2 / 0.85. Reward: 8 gold. Chance min(20%, 3.5% + (wave-5)*0.6%); first spawn of every fifth wave is guaranteed elite.

Baseline HP = 50 × 1.06^(wave-1), attack = 12 × 1.06^(wave-1),
speed = 86 + min(34, wave×0.7). Exponents cap at 600. Attack period
1.15 game seconds; initial attack delay 0.5 seconds. Preserve these values.
