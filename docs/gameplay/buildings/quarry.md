# Quarry / Stonemason

One per stone site; two inside, two outside. Cost 70 wood/15 stone/15 gold,
HP 380, base production 5 stone/sec with matching-site multiplier 1.25.
Upgrade this individual building from its own panel, instantly, through level 100.
Upgrade production and HP; show current -> next values and exact local price.
Destroyed producers disappear and free their sites; replacements begin at level
one. Preserve levels already purchased on existing buildings during migration.
The resource and quarry form one stable drawing group: rocks below the quarry,
independent of nearby enemies, construction, destruction, or equal Y positions.
Exposed outside quarries must attract approaching enemies just like woodcutters.

Level-one upgrade price: 45 wood / 40 stone / 15 gold. Later upgrade
prices scale by 1.15^(current level - 1), rounded up per resource.
