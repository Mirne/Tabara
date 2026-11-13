# Rendering

Preserve existing raster art, world geography, animation and building alignment.
Resource rocks must always draw below their associated quarry. Group their draw
calls at the producer's sort position. Equal Y sort keys must have a deterministic
tie-break so entity additions/removals cannot swap scenery and buildings.
Do not remove resources, redraw assets, or move sites to mask a layering defect.
