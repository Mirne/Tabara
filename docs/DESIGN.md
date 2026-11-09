# First mission design

## Intent

Pinewatch is a compact, readable settlement with one fixed enemy approach.
Production, construction, upgrades, and repairs compete for the same supplies.
The hall is useful from the beginning, allowing the player time to learn the
economy while enemies are already on screen.

## Rules

- Fixed simulation steps: 0.05 seconds. Larger external steps subdivide safely.
- Mission victory: 900 in-game seconds, while the main hall survives.
- Waves: every 30 seconds, including wave 1 at the start.
- Wave count: `min(36, 3 + floor(wave / 2))` enemies.
- Spawn spacing: `max(0.35, 18 / (3 + wave / 2))` seconds.
- Base enemy health: `38 × 1.085^(wave − 1)`.
- Base enemy damage: `10 × 1.065^(wave − 1)`.
- Runners start at wave 4, brutes at wave 7, occasional siege engines at wave 15.
- Buildings begin at level 1 and cap at level 100.
- Building maximum health scales by `1.11^(level − 1)`.
- Damage and production scale by `1.14^(level − 1)`.
- Upgrade prices scale by `1.13^(level − 1)` and round upward.
- Range increases gradually and caps at +55; firing speed improves by at most 50%.
- Upgrading preserves the building's current health percentage. It is not a free repair.
- Repair prices scale with missing health and `1.08^(level − 1)`.
- The main hall supplies 1.5 wood, 0.9 stone, and 0.45 gold per second.
- Resource caches replenish every 12 seconds and slowly increase yields over time.
- Enemies award gold when defeated; marketplaces provide stable gold income.
- A marketplace exchanges 60 timber or stone for 30–55 gold, depending on level.

## Layout

There are 13 plots: one main hall, two road checkpoints reserved for walls,
one pine-grove bonus plot, one quarry bonus plot, and eight flexible plots.
Every tower chooses the most advanced live enemy in range. Standing walls stop
enemies; ruins permit passage. Siege enemies can attack economic buildings from
the road. All enemies stay on the same approach route.

## Saves and lifecycle

The version-1 JSON snapshot stores the whole mission, including building ruins,
levels, health, enemies, random generator state, wave timing, resource cooldowns,
and victory acknowledgment. A temporary file is atomically renamed over the
previous save. Root fields, buildings, and enemy records are validated before
restoration. Invalid saves do not crash the main menu.

App focus loss pauses and saves. Resuming requires an explicit tap so that
enemies do not attack while the player is reading an external screen.

## Scope

This version includes one complete mission and its endless continuation. There
are no online services, campaign progression locks, purchases, or multiplayer.
Long-run survival depends on repair and economy decisions. Maximum-level
buildings do not make the settlement invulnerable: enemy pressure keeps rising.
