# Walls and battlefield abilities v0.12 verification

## Build identity

Runtime source: `e82801fbea5a361054d73bd51a96a86a371f68f8`.
Godot 4.6.3, app 0.12.0/code 12, save format 11, terrain revision 5.
APK: `tabara-frontier-v0.12.apk`, **104,036,306 bytes** (99.2 MiB).
SHA-256: `82e1915bb3bcb6873a3fb2fc4e9bee04e4ddb523fcf0835ea7f015b1067ad39e`.
Certificate SHA-256: `dbd0f5f2a2a56082d36b733d6467f28dc7dc166e82ffe41d0dc2c2fe42cd6ebb`.
Packaging preserves every uncompressed export payload and uses the published
v0.11 signing key. See [packaging record](verification/battlefield-skills/packaging.log).
The [v0.11 evidence](https://github.com/Mirne/Tabara/blob/v0.11.0/docs/QA.md)
remains available through its release tag.

## Source, gameplay and rendering

**1,877 existing model checks**, **61 battlefield-mechanic checks**, **81 terrain /
navigation checks**, **46 movement traces / 12,620 sampled positions**, **166
interface checks**, **85 combat-art checks**, and **24 battlefield-interface checks**
passed with zero failures. [Independent source CI](https://github.com/Mirne/Tabara/actions/runs/44530000990)
passed the frozen runtime. See [checks](verification/battlefield-skills/checks.log),
[movement](verification/battlefield-skills/movement.json), and
[CI identity](verification/battlefield-skills/source-ci.json).

Wall tests count the actual occupied terrain cells, test flush cardinal neighbors,
3×3 masses without interior rails, red-cell filtering, payment, destruction,
and serialization. A format-ten wall without new metadata retains its 80-unit
collision, level, HP and resources. A new 40-unit neighbor joins that old foundation;
destroying either opens only its own occupied cells.

Smash tests cover the warning before damage, neighboring structures inside the
circle, untouched structures outside, repeated three-second casts, no extra melee
hit during wind-up, reload during a warning, and cancellation on boss death.
War cry tests measure actual 30% faster movement, unchanged base stats, no stacking,
range limits and immediate removal when its bosses die.

Rain tests cover target rejection, no resource fee, recharge, first-hit delay,
circle damage, six captured-damage pulses, Arrow tower scaling, reload without
repeated pulses, ordinary kill gold and final-boss victory. A dedicated regression
saves exactly on the barrage-end frame. It caught a floating-point residue issue;
the final runtime clears that residue before serialization. A preparatory native
run was stopped so its APK could be rebuilt with that fix.

Rendered touch checks verify preview-before-cast, explicit confirmation, Back
cancellation, panning and pinch zoom without spending a cast, leaving wall mode,
paused-input isolation, real damage and falling arrows. Actual engine captures:
[wall mass](screenshots/battlefield-walls.png),
[filtered wall preview](screenshots/battlefield-wall-preview.png),
[war cry](screenshots/battlefield-war-cry.png),
[smash warning](screenshots/battlefield-smash-warning.png),
[impact](screenshots/battlefield-smash-impact.png),
[Rain preview](screenshots/battlefield-rain-preview.png), and
[falling arrows](screenshots/battlefield-rain-falling.png).
These fixtures grant supplies or use high-health enemies to isolate visuals;
they are not normal-cost campaign evidence.

## Signed Android update

The exact downloadable APK passed **44 native Android API 24 checks** in
**1,813.38 seconds**. Published v0.11 was installed first, wrote a format-ten
settlement, then received the signed v0.12 update without clearing data. The
complete old save survived installation; map, foundations, individual levels,
global upgrades, Regeneration, resources and mission progress survived loading.
See [native report](verification/battlefield-skills/native-update-and-abilities.json)
and [log](verification/battlefield-skills/native-update-and-abilities.log).

Actual touch confirmation placed a single-cell wall against the legacy rampart.
Five-minute arrival, left/right hammer animation, repeated three-second smashes,
damage to multiple walls, fifteen-minute arrival without timed victory, Rain
target preview, final-boss death, endless continuation and recharge after another
cold restart all passed. Native diagnostics contained no script, shader or fatal
error. Captures: [mixed walls](screenshots/android-battlefield-mixed-walls.png),
[left smash](screenshots/android-battlefield-smash-left.png),
[right smash](screenshots/android-battlefield-smash-right.png),
[Rain targeting](screenshots/android-battlefield-rain-preview.png), and
[Rain victory](screenshots/android-battlefield-rain-victory.png).

After the original economy migration checks, controlled encounter fixtures set
a 1,000-resource budget, advance clocks to 299.95/899.95, reinforce walls,
Workshop and quarry to level 100, and disable Regeneration. The posed miniboss
has 20,000 HP for repeated captures. The final boss has one HP and attacks the
quarry outside Hall/tower range, isolating Rain as its killing source. These are
transition tests, not paid campaigns. The pre-fixture migrated settlement was
restored afterward.

## Paid campaigns and limits

Three seeded paid-order defender campaigns reached 15:00 but **none killed the
final Warlord**. The Hall fell at **1,002.60, 979.25 and 993.00 game seconds**,
in waves 34, 33 and 34. No supplies were granted. The bot adapts its wall line to
twelve single cells and uses its previous upgrade priorities; it does not cast
Rain. This is a baseline strategy, not a winning-strategy or balance guarantee.
See [campaign record](verification/battlefield-skills/balance.json).
No new long-duration soak or extreme-load performance claim is made.

## Save compatibility

Existing map layouts 0–5, foundations, purchased levels, Regeneration and economy
are preserved. Old walls retain their 80-unit foundations; new construction uses
single 40-unit cells. New spells initialize ready, without a phantom active barrage.
Previously earned legacy endless victories remain earned; unfinished missions
still require the final Warlord's death while the Hall survives.

Native checks use emulators; no physical handset was available. The offline
sideload build supports ARM64/x86-64 and Android API 24+. Persistent owner rules
and individual specifications are in [gameplay notes](gameplay/NOTES.md) and
[the index](gameplay/INDEX.md).
