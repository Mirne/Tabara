# Marketplace

One per settlement. Cost 120 wood/80 stone/60 gold, base HP 450.
Owner clarification: restore passive gold production and remove buying/selling.
Restore the v0.7 base output of **2 gold per game second**, scaled by
`1.08^(level-1)` through level 100. Construction produces nothing until completed.
Upgrade locally; show actual current/next gold per second, HP and resource cost.
No trading screen, trade actions, buy/sell methods or trade cooldown exists.
Keep the current building cost, HP, one-per-settlement limit and purchased levels.
Destroyed buildings disappear; replacements start at level one.
An exposed Marketplace attracts enemies using the same producer detection range.

Level-one upgrade price: 55 wood / 40 stone / 25 gold. Later upgrade
prices scale by 1.15^(current level - 1), rounded up per resource.
