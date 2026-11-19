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
