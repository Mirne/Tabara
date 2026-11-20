# Upgrades and migration

## Buildings and walls

Local health/production upgrades are individual purchases at the Hall,
woodcutter, quarry, Marketplace and Workshop. A replacement starts at one.
Local building levels and the Workshop wall upgrade go through level 100.
Their quoted costs grow by 1.15 per level. HP grows by 1.085 and production
by 1.08. Ordinary upgrades preserve the current health fraction. Wall
upgrades apply to all standing and future wall sections.

Regeneration is available under Workshop Upgrades. Its 100 ranks heal
completed standing buildings at 0.3% of maximum HP per game second at rank
one, rising linearly to 20% at rank 100. Purchases are instant.

## Settlement ages

The Main hall advances through Wood, Stone, Iron, Steel, Keep, Castle,
Citadel and Crown. Age determines building artwork, Workshop illustrations,
available tower research and the maximum rank. The Hall's local health
and weapon upgrade is a separate purchase. Age advancement costs twice
the base Hall upgrade price at Wood. Each later age costs 1.5 times the
preceding base amount, rounded up independently for wood, stone and gold.

## Tower research

Each weapon has three branches. Damage is available in Wood, arrow reach
and cannon blast radius open in Stone, and firing speed opens in Iron.
Starting ranks are one. The age caps are 3, 5, 8, 9, 10, 11, 12 and 100.
Purchases are instant and affect the named weapon across the settlement,
including replacement towers. The Workshop must be standing and complete.

A damage rank multiplies arrow or shell damage by 1.10. The first reach
purchase adds 19.3 world units to arrow range and the first blast purchase
adds 11.6 units to shell radius. Later ranks add progressively less radius.
For r purchased ranks beyond rank one, the total range bonus is 20r / (1 +
0.035r) and the total blast bonus is 12r / (1 + 0.035r). Each cadence rank
adds 5% of the weapon's base firing rate.
Each branch uses its tower's original per-building upgrade price, scaled
by 1.15 per purchased rank. At rank one the prices are 55 wood, 35 stone,
20 gold for arrows and 65 wood, 75 stone, 35 gold for cannons. Prices
round up per resource. Rain uses the Arrowheads damage multiplier at cast.

## Saved settlements

Format 12 records the settlement age and six independent tower research
ranks. Older settlements begin at Wood. Purchased old grades preserve
HP, range, cadence and damage on standing and replacement towers. The
damage branch begins at the old paid level, even when that exceeds Wood's
rank cap. Other branches begin at one and improve the retained stat. Moving
between ages preserves the settlement, current health, local levels, global
wall and Regeneration ranks and damage already captured by a Rain cast.
