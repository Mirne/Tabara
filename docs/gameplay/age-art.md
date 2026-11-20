# Settlement age artwork

Each Main hall age gives the settlement a new set of painted buildings. Wood,
Stone, and Iron establish the progression. The five later medieval
architectural styles are Steel, Keep, Castle, Citadel, and Crown. Hall, woodcutter,
quarry, market, arrow tower, cannon tower, and Workshop each keep their function
recognizable as the materials, rooflines, and silhouettes develop. A visible stack
of sawn logs always identifies the woodcutter. Stone blocks and a hoist identify
the quarry. The arrow tower has an open firing gallery. The cannon tower has a
prominent bombard barrel. All buildings face the same direction and their feet
stay centered on the original foundations.

The art uses generated raster paintings with transparent surroundings and a
shared upper-left light. The catalogue, inspector, and age purchase preview
use the actual age's building paintings. Workshop tower upgrades have painted
icons with different subjects for damage, reach or blast radius, and cadence.
Their material and detailing reflect the current age.

Each of the eight original building sheets contains one illustration for each
building, including the wall catalogue image. Two further generated sheets
carry the eight saw sheds and eight lifting works used in the producer cells.
Four separately generated object sheets supply 48 research illustrations.
The arrow topics show an arrowhead,
a longbow and a quiver. The cannon topics show a bombard, a pile of shot and a
pair of loading tools. The connected wall in the world uses the corresponding
age's material over its joined geometry.

The runtime building atlases are 1,024 × 512 pixels. The research atlas has
six columns and eight rows of 96 × 96 pixels. Source sheets have uneven spacing.
The [packing script](../../tools/pack_age_art.py) follows each object's alpha
contour, includes detached details such as blocks suspended from cranes, and
records its source rectangle in the [bounds file](../../assets/ages/bounds.json).

At mobile Workshop sizes, the bow keeps a broad limb, a visible grip and a
nocked arrow. These painted details make the range project identifiable on the
dark research panel.

When a player pays to advance, the new building painting appears from the
foundation up to the roof. Both silhouettes use their normal footprint and
depth order. Completed structures participate in that purchase. Construction
previews and new construction show the current age immediately. Reduced
motion presents the finished artwork directly.

[Five frames from a Wood-to-Stone Hall purchase](../screenshots/age-advance-reveal.webp)

At phone zoom the two producers carry different working silhouettes through
all eight ages. The woodcutter has a low open-sided saw shed with visible log
ends and a saw bench. The quarry has an upright lifting frame and a bright
block suspended above dressed limestone. Both sit on the existing workyard
foundation. [Compare the Wood, Iron and Crown producers on the battlefield.](../screenshots/producer-works.webp)
