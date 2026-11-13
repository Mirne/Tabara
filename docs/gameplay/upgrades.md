# Upgrades and migration

Levels cap at 100. Purchases are instant, pay once, and preserve the building's
health fraction; upgrades do not grant instant free healing.
Woodcutters and quarries upgrade independently at their own panels. Replacements
start at one. Keep current building levels when migrating an existing save.
Wall, Arrow tower and Cannon tower keep type-wide levels purchased at Workshop;
standing and future defenses inherit these levels.
Keep the existing 1.15 cost scaling, 1.085 HP growth, 1.08 producer output growth,
1.10 damage growth, and bounded range/period improvements. Local upgrades use the
existing per-building base price instead of the doubled global price.
Regeneration moves into Workshop Upgrades. Retain the starting rate of 0.3%
maximum HP/sec and grow linearly to 20% at level 100; costs stay unchanged. Store the
level, preserve existing purchases, and never heal construction or destroyed slots.
Hall, Marketplace and Workshop upgrades are local, keeping only defenses and
Regeneration in Workshop Upgrades. Preserve purchased levels on standing buildings;
replacement non-defense buildings begin at level one.
