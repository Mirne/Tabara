# Arrow tower

Cost 140 wood/100 stone/60 gold. Base HP 650, damage 30, range 460, period 1 sec.
Fast single-target weapon; ordinary incoming damage for all enemies.
Type-wide upgrades remain in Workshop Upgrades, instant, through level 100.
Show actual current/next HP, damage, range and attack period, with exact price.
Replacement towers inherit the defense level. Preserve range previews and the
construction tool staying selected. Do not add enemy-specific damage bonuses.

Level-one upgrade price: 110 wood / 70 stone / 40 gold. Later upgrade
prices scale by 1.15^(current level - 1), rounded up per resource.

The new Rain of Arrows ability shares the existing Arrow tower damage research
multiplier. This does not change tower attacks, costs or the Workshop upgrade.
See [battlefield abilities](../abilities.md) for its proposed implementation.
