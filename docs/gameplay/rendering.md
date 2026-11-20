# Rendering

Preserve existing raster art, world geography, animation and building alignment.
Resource rocks must always draw below their associated quarry. Group their draw
calls at the producer's sort position. Equal Y sort keys must have a deterministic
tie-break so entity additions/removals cannot swap scenery and buildings.
Do not remove resources, redraw assets, or move sites to mask a layering defect.

Combat units use a separate raster attack atlas, matching their existing walking
art. Walking to the left mirrors the texture, not the world position. Attacking
units face their actual building target. Animation follows simulation time so
pause/speed/reload remain consistent; reduced motion uses a still pose.
Death effects retain the unit's last facing direction instead of snapping right.

The launcher and boot splash use a new raster icon matching the red-roof Hall,
warm windows, dark woodland palette and existing building artwork. Keep important
features within Android adaptive-icon safe bounds. Do not introduce new UI tips.

Remove the decorative “SINGLE PLAYER / OFFLINE” menu footer, as requested.

Warlord smash has a visible ground-circle wind-up and hammer strike, followed
by a dust/shockwave impact. War cry uses a subtle continuous aura and affected
enemies get a ground glow. These combat tells are not tutorial text.

Rain of Arrows shows a circle while targeting and many downward arrow shafts
landing inside it during the barrage. Active barrages render from simulation
state so pause, speed changes and reloads remain consistent. Keep the mobile
ability button outside the minimap and construction panel, with large confirm
and cancel controls. Use existing command-deck textures, not placeholder icons.

Single-cell walls keep the existing textured stone/wood materials and height.
Their dirt footprint, picking bounds and health bars match the smaller cell.
Legacy saved ramparts retain their old physical footprint and share the same
40-unit visual tiles, so new cells join their perimeter without internal rails.

## Settlement ages and Workshop presentation

The Hall opens its Age panel from the top bar or a tap on the building. Show the
current Hall and next Hall artwork, the next rank limit and newly available tower
research, and the three-resource price before advancing. Its Building tab keeps
local statistics and local upgrades available. At the final age, show the fully
advanced Hall and its current research limit.

Workshop Upgrades groups projects by tower, Wall and Regeneration. For a tower,
show its three individually selectable projects with painted icons from the
current age. Show the selected project's exact combat stat change, rank, price,
and next age requirement when applicable. Use one purchase action per project.
Building cards and placement previews match the age of the world sprites. Tower
range rings use the actual researched range. Keep panel controls touch-sized.

Confirming a Woodcutter, Stonemason or Marketplace returns directly to the
catalogue with no building selected. Walls and towers keep repeat placement.
Occupied Woodcutter and Stonemason catalogue cards open
the existing building and display its current level and resource yield. The
single Marketplace uses the same shortcut. Destruction of the last instance restores its build card.
