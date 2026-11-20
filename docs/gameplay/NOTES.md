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

## Requested after v0.10: attacks, facing, icon and boss victory

- Combat units need real attack animations, synchronized with building strikes.
- Mirror unit sprites horizontally when moving left; face their target while
  attacking. Preserve foot positions and existing movement/attack cadence.
- Replace the old vector launcher/startup icon with matching raster artwork.
- The final boss arrives at 15:00; reaching that time does not win or pause.
  Victory requires killing that specific boss while the Hall survives.
- Minibosses arrive every five game minutes and grow stronger each interval.
  The 15-minute boss is much stronger. Continue normal waves during the fight.
- Implementation values: regular Warlord HP multiplier over its existing wave
  baseline is 1 + 0.5*(interval-1); attack multiplier is 1 + 0.15*(interval-1).
  Final Warlord uses 4x the old same-wave boss HP and 2x its attack, so it is
  substantially stronger than the 10-minute miniboss. Speed, ordinary damage
  rules and kill rewards are preserved. These values implement the qualitative
  strength request; no unrelated enemy or economy values change.
- Save final-boss identity and completion so reloads neither duplicate the boss
  nor award victory merely because the clock passed 15:00. Existing completed
  endless saves retain their earned victory. Unfinished late legacy saves receive
  one final Warlord without replaying all past miniboss intervals.

- Owner follow-up: remove the menu footer text “SINGLE PLAYER / OFFLINE”.

## Requested after v0.11: single-cell walls and battlefield abilities

- Walls become 1x1 construction-grid cells and merge visually with cardinal
  neighbors, including corners and dense blocks. Retain drag confirmation, red
  terrain filtering, destruction, prices and global Workshop wall upgrades.
- Compatibility implementation: existing saved wall foundations remain intact.
  Old 80-unit walls are rendered from joined 40-unit tiles; new walls occupy one
  40-unit cell. Store each wall's footprint so future saves keep that distinction.
- Give the middle minibosses abilities so their encounters have more impact.
  Owner clarified: smash every 3 game seconds; war cry is passive and continuous.
  Apply both to Warlords; do not change unrelated
  ordinary enemy stats, resources, map geography or building upgrades.
- Add Rain of Arrows: arrows fall from the sky into a targeted battlefield circle.
  Mobile targeting uses a preview and explicit confirmation. Owner confirmed
  a free cast with **60 game seconds recharge**. Do not add tutorial/filler
  tooltips or cooldowns to existing buildings.

## Settlement ages requested after v0.12

The owner requested Wood, Stone and Iron followed by five more premodern ages at the Main hall. Advancing should visibly change buildings and Workshop research icons. Each tower type gets several distinct upgrades. New settlements have one of each resource building, improved locally, with deliberately placed sites. Use generated paintings and playtest the changing economy. The [rework plan](../AGE-REWORK.md) records the proposed age sequence, implementation work and verification goals.
