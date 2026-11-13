# Owner rules and change notes

## Persistent instructions

The owner explicitly said: "STOP STOP STOP giving these absolutely useless tool
tips, WRITE THIS SOMEWHERE" and "PLEASE stop doing changes by yourself."
Do not add generic tutorial/tooltips to selected-building panels, purchase panels,
or routine placement notifications. In particular, remove "Upgrades are researched
for all buildings of this type at the Workshop", "Unlock Regeneration at the
Workshop to heal buildings", and "Instant · all current and future buildings".
Display current stats, exact next-level effects, resource prices, and real errors.
The purchase caption is **Upgrade**. Do not replace deleted copy with other filler.

Do not change unrelated behavior when implementing a request. Document explicit
owner decisions here and in each affected building/NPC file; read them before
coding. Work directly on main. Preserve older downloads and save compatibility.

## Current request after v0.9

- Fix quarry/resource layering so rocks never alternate in front of their quarry.
- Owner clarified: Marketplace produces gold passively again, with gold-income
  upgrades. Remove all buying/selling and trade cooldowns. Restore the previous
  2 gold/sec base production and existing 1.08 output scaling.
- Woodcutters and quarries get individual upgrades on their own building panels.
  They can be rebuilt after destruction. Only defenses retain type-wide upgrades.
- Put Regeneration in the Workshop's Upgrades list, alongside defense upgrades.
- Increase Regeneration growth to reach **20% maximum HP per game second** at
  level 100. Retain 0.3% at level one, then grow linearly to 20% at level 100,
  locked at level zero.
- Enemies must actively seek every exposed outside resource producer, with a
  larger detection radius; retain terrain collision and attack intervening walls.
- Keep all other combat, building costs, and map positions intact.

Marketplace clarification is now explicit: passive gold, upgraded income, no trade.
The remaining implementation assumption is to move non-defense upgrades to their individual building panels
to honor the requested defense-only Workshop. This is an interpretation of the
requested scope, not a separate owner-confirmed change. A later answer overrides it.
