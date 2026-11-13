# Woodcutter

One per timber site, placed over the matching resource on the grid. Two sites
inside the base, two outside; resources cannot be clicked. Cost 60 wood/20 stone/
10 gold, HP 300, base production 4 wood/sec with matching-site multiplier 1.25.
Upgrade this individual building from its own panel, instantly, through level 100.
Upgrade production and HP; show current -> next values and the exact local cost.
Destroyed producers disappear; their site becomes available for a new level-one
producer. Standing producers keep their purchased levels across updates.
Exposed outside producers must all attract approaching enemies, not just one site.

Level-one upgrade price: 50 wood / 25 stone / 15 gold. Later upgrade
prices scale by 1.15^(current level - 1), rounded up per resource.
