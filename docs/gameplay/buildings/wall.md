# Wall

Cost 25 wood/55 stone/10 gold, base HP 2000. Existing drag/grid behavior remains:
skip blocked/red sections; charge eligible sections only. Rows share a deck and
outer parapet; no internal junction towers. Destruction opens a breach.
Type-wide HP upgrades remain in Workshop Upgrades, instant, through level 100.
Existing and replacement walls inherit the purchased defense level.
Panel shows health and the actual HP change/price; purchase caption is Upgrade.

Level-one upgrade price: 40 wood / 110 stone / 20 gold. Later upgrade
prices scale by 1.15^(current level - 1), rounded up per resource.

New walls occupy exactly one 40x40 terrain-grid cell, centered in that cell.
Cardinal neighbors merge into a continuous textured deck with only outer faces,
parapets and corner caps. Three-by-three masses have no interior rails or towers.
Drag strokes step by 40 and retain confirmation, blocked-cell skipping and the
64-new-section limit. Each new cell keeps the existing price, HP and upgrades.

Preserve old saved foundations: legacy 80x80 walls keep their collision, levels
and HP, and render as four joined 40x40 tiles. New single-cell walls join their
outer edges correctly. Save the footprint; do not split old logical buildings or
spend resources during migration. Destruction opens the actual occupied cells.

The Main hall's selected age determines the appearance of the standing rampart,
wall placement preview and catalogue icon. Its exposed face progresses from
timber stakes to carved medieval masonry. All cells in a connected stretch
share the same materials, deck elevation and exterior parapet profile. The
appearance also applies to the visual tiles of older 80×80 foundations.
During a Hall advancement connected standing sections rise together to the
next profile and take on its material. Their footprint stays fixed.
