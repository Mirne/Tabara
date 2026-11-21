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

## Rear workyards

New maps show a single worn timber landing at the forest edge, where the cut
logs, cart ruts and eligible foundation meet. Remove the redundant trail into
the eastern side of that clearing, and join the canopy across the retired
trail tip. The new trees block passage and construction. Place the quarry
beyond the Hall with a continuous, grass-capped limestone ledge and a working apron off the back road.
Resource scenery shares its producer's draw order. Preserve the geography of
earlier paid settlements when loading their map revision.

## Settlement ages and Workshop presentation

The Hall opens its Age panel from the top bar or a tap on the building. Its
arrows browse all eight buildings with current and next age paintings on one
baseline. Show the next rank limit, newly available projects and their own
paintings, and the price before advancing. Its Building tab keeps local stats
and upgrades. At Crown the arrows browse the fully advanced buildings.

Touch controls activate when the player lifts their thumb over the original
control. Sliding off, interrupting the touch, or losing focus cancels it.
Only fingers that start on the battlefield can participate in a camera pinch.

An age purchase briefly reveals the new architecture on the battlefield while
the player keeps control of the settlement. The reveal pauses with the game,
uses real display time at each simulation speed and finishes immediately with
reduced motion. Reloaded settlements open in their saved age.

Workshop Upgrades groups projects by tower, Wall and Regeneration. For a tower,
show its three individually selectable projects with painted icons from the
current age. Display the three combat-stat comparisons together so the player
can choose a project directly. The selected row owns the price and purchase
action below it. Show its next age requirement when a rank is capped.
Use one purchase action per project.
Building cards and placement previews match the age of the world sprites. Tower
range rings use the actual researched range. Keep panel controls touch-sized.

Confirming a Woodcutter, Stonemason or Marketplace returns directly to the
catalogue with no building selected. Walls and towers keep repeat placement.
Occupied Woodcutter and Stonemason catalogue cards open
the existing building and display its current level and resource yield. The
single Marketplace uses the same shortcut. Destruction of the last instance restores its build card.
