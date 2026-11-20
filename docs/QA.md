# Android v0.13.1

The Hall comparison was played at 1544×720. In a live settlement the player
browsed the Hall, Woodcutter and Stonemason, then spent 130 wood, 90 stone
and 50 gold to enter Stone while keeping the selected Stonemason preview.
A second opening bought both workyards, built an arrow tower and raised the
Woodcutter to 5.40 wood per second. The dedicated touch checks also cover lifting
off a purchase, a canceled Android gesture and keeping a second finger on the
panel outside a battlefield pinch.
[Hall at phone scale](screenshots/hall-age-preview.webp).

Both workyards passed paid construction, destruction and rebuilding checks at
1280×720 and 1544×720. A restored v0.12 settlement kept its paid foundations
and levels. Its older terrain matched the released rendering around both
workyards. Separate local purchases raised wood from 5.00 to 5.40 per second,
stone from 6.25 to 6.75 and market gold from 2.00 to 2.16.
[Workyards](screenshots/workyard-placement.webp) · [Producer upgrades](screenshots/producer-upgrade-panel.webp).

The Workshop comparison used normal opening funds to buy Arrowheads and Burst
shells in separate tower families. Arrowheads showed 33 → 36.3 tower damage
and 330 → 363 barrage damage at the pictured rank. The seven age transitions
were rendered across all eight building types. Checks covered pause, reduced
motion, rapid consecutive purchases and old-save reloads.
[Workshop](screenshots/workshop-projects.webp) · [Age paintings](screenshots/producer-works.webp).

# Settlement ages v0.13 verification

The released v0.13 APK uses Godot 4.6.3, Android version code 13, save format 12
and terrain layout 6. The signed APK is 104,006,410 bytes with SHA-256
`aa4fb07bdac02c3c328db720a32e5583e9da88c4a200a0c5639b61f0822ec8d5`.
Its signer certificate matches the published v0.12 certificate,
`dbd0f5f2a2a56082d36b733d6467f28dc7dc166e82ffe41d0dc2c2fe42cd6ebb`.
Packaging verified that every uncompressed payload matched the export.

## Age progression, research and saves

The source check for `ed491e0accc2256287dddbc2d7971e9a936a77f5` passed with
zero failures. It included 2,515 age and research checks, 432 age-art checks
and 63 age-interface checks. The terrain suite covered all seven layouts and
the movement suite checked 46 routes across 12,655 positions. The remaining
simulation, combat and interface suites also passed. [Source CI report](https://github.com/Mirne/Tabara/actions/runs/44774432606).

The tests exercise seven paid age advancements, the six tower projects and
their effects, rank limits and save/reload. The migration fixture was written
by v0.12 with four woodcutters, four quarries, paid tower research and
Regeneration. Loading it checks the original geography and purchased benefits.
[Fixture description](../tests/fixtures/README.md).

## Touch controls and presentation

Rendered gameplay passed 31 checks at 1280×720 and 32 at 1544×720 using window
pixel coordinates for touch. Both workyards fit in the opening camera with a
44×44 logical touch target clear of the HUD. Tapping the wrong resource spent
nothing. An edge tap snapped to the correct yard, confirmation charged for the
producer, and its catalogue card opened its local panel. Destroying the quarry
restored its build card and a paid rebuild returned it to level one. The wide
test also tapped the letterbox margin. These checks ran in the Godot renderer.
[16:9 run](verification/settlement-ages/touch-16-9.log) · [S23 Ultra aspect-ratio run](verification/settlement-ages/touch-wide.log).

The recorded touch opening paid for both producers, their local upgrades,
defenses, a Marketplace and a Workshop. It reached Stone at 78.15 game seconds
and Iron at 107.45. The gallery uses staged settlements to compare the same
workyards, towers and ramparts across ages. [Opening record](verification/settlement-ages/touch-opening.json) · [Age gallery](screenshots/age-gallery.webp) · [Design and playtest plan](AGE-REWORK.md).

## Campaign decisions at normal prices

An uninterrupted settlement on seed 2718 killed the full-strength final
Warlord at **16:23.75**. The Hall still had all 4,200 HP. It reached Iron,
raised the three arrow projects to rank 8 and supported its archers with
cannons and walls. The player cast Rain when the Warlord entered the road and
again at the fort after recharge. A fresh replay at the game's 50 ms tick
accepted all 125 normal-price inputs, reproduced 2,224 kills and continued
through the victory screen into wave 34. This was the first victory in 15
tactical trials across seven seeds. [Runs and winning inputs](verification/settlement-ages/clean-campaigns.json)

Nine fresh runs used three spending plans across three seeds. All three
age-first runs bought Castle at 7:54, killed the first miniboss and fell
between 8:35 and 8:53. All three fortification runs killed both minibosses and
reached the final Warlord, falling between 15:56 and 16:12. The balanced runs
lasted 14:48 to 15:15. These scripts bought at most one order per game second.
[Prices, seeds and results](verification/settlement-ages/paid-campaigns.json)

Two branches of a paid 11:40 opening reached Crown at 15:33 and 15:44. A
different branch purchased rank 12 Round shot at 15:37. Its roughly 314 damage
cleared an ordinary wave-31 raider in one shell, where rank 11 dealt roughly
285 against 287 HP. The closest of those sixteen branches left the final
Warlord with approximately 12,707 of 29,866 HP. They share a starting
settlement and count as strategy comparisons. [Late-game decision record](verification/settlement-ages/paid-late-strategies.json)

A separate desktop fixture rendered a Crown settlement for 65 seconds with
512 buildings, 1,000 durable enemies and all six research projects at rank
100. It checks rendering and state under load. The desktop software renderer
ran at low scheduling priority and its timings cannot establish handset FPS.
[Stress fixture](verification/settlement-ages/crown-stress.json) · [Age transition and rendering measurements](verification/settlement-ages/desktop-render-timing.json)

## Android update and touch tests

The same signed APK passed 37 update checks and 77 fresh-install checks on
each of Android 7.0 (API 24) and Android 15 (API 35). The old v0.12 app first
wrote the paid eight-site settlement. The update preserved its complete save,
its producers and its defensive research. A separate controlled budget then
exercised all seven Hall advances. The fresh-install checks bought the two
producers, built towers and walls, and used real Workshop and Hall controls.
[Android run](https://github.com/Mirne/Tabara/actions/runs/44776918637) · [Native Stone preview](screenshots/android-ages-stone-preview.webp) · [Native Crown Hall](screenshots/android-ages-crown-hall.webp)

Android 16 (API 36) passed 42 update and 86 fresh-install checks on a
1544×720 landscape display matching the S23 Ultra's proportions. The real
touch flow covered both workyards, repeated tower and wall placement,
Workshop research, Hall advancement, camera movement and Android's immersive
Back gesture. The wide screen had 132-pixel side margins around its centered 1280×720 game view. Tests used Android emulators. [Wide Hall screen](screenshots/android-ages-wide-stone.webp) · [Raster measurements](verification/settlement-ages/api36-raster.json). [Android 16 run](https://github.com/Mirne/Tabara/actions/runs/44788374002) · [Update checks](verification/settlement-ages/api36-upgrade.json) · [Fresh-install checks](verification/settlement-ages/api36-fresh.json)

A second paid campaign was saved after its last wall order at 16:26.00.
The Warlord had 261.98 of its original 29,866.15 HP. Loading that exact
settlement into the signed Android APK reproduced the kill at 16:26.45
without another battlefield order. Tapping Continue endless survival resumed
combat with the Hall at 4,200 HP. The test restored the emulator's original
saved settlement afterward. [Android fight record](verification/settlement-ages/api24-paid-finish.json) · [Victory on Android](screenshots/android-ages-normal-cost-victory.webp)

## Extended stability check

At the release checkpoint, the normal-speed automated playtest had measured 24,418.0 active seconds across 32 settlements and 386 on-disk save restores with zero invariant errors. The first 1,351.5 seconds used a development build. The remaining 23,066.5 seconds used the published rules and artwork. [Checkpoint](verification/settlement-ages/release-checkpoint.json)

---

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

The complete [public APK download](https://raw.githubusercontent.com/Mirne/Tabara/a60fb83bd341a60aad0a56449dab730806d72e47/builds/tabara-frontier-v0.12.apk)
was downloaded again and matched the tested size and SHA-256 exactly.
See [download verification](verification/battlefield-skills/public-download.json).

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

## Independent Android 15 fresh install

[API 35 CI](https://github.com/Mirne/Tabara/actions/runs/44537623656) passed
**76 checks** in **820.55 seconds** with a separately built and signed test APK.
This covers paid mobile construction, twelve-cell walls, upgrades, lifecycle,
boss transitions, tower-kill victory, Rain preview and real damage, and recharge
after a cold restart. The CI APK hash is recorded separately from the downloadable
APK in the [report](verification/battlefield-skills/android-api35.json) and
[run identity](verification/battlefield-skills/android-ci.json).

No resource grants were used in that run. Boss transition fixtures advance the
clock and use a one-HP final boss for the tower-kill check. Rain uses a 5,000-HP,
one-damage elite beside the quarry. Earlier fixture attempts aimed at a stale
saved position while the enemy moved away; the corrected harness pauses for a
fresh position before targeting. Only the test fixture changed. The successful
run observed two 55-damage pulses and 58.85 seconds of recharge after casting.
Its original native settlement was restored after the controlled checks.

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
