# Open Approach v0.9 verification

## Build identity

Runtime source: `1ba5226e6e3e9d9a240190092385005342ef8d83`.
Godot 4.6.3, app 0.9.0/code 9, save format 8, new terrain revision 5.
ARM64 and x86-64; Android API 24 minimum. Existing saves retain layouts 0–4.

APK: `tabara-frontier-v0.9.apk`, 96,109,874 bytes (91.7 MiB).
SHA-256: `cd4781dc551b53dcd356fc9ec43cc77496c37670676e8dcc16d6d0921a34e66b`.
Certificate SHA-256: `dbd0f5f2a2a56082d36b733d6467f28dc7dc166e82ffe41d0dc2c2fe42cd6ebb`.
Previous verification remains in [v0.8](https://github.com/Mirne/Tabara/blob/v0.8.0/docs/QA.md).

## Gameplay, terrain and controls

Local combined verification passed **1,801 model checks**, **81 terrain/navigation
checks**, and **146 rendered interface checks**, with zero failures. Actual
movement completed **46 traces and 12,620 sampled positions** without a blocked
cell entry or failed arrival. See [checks](verification/open-approach/checks.log)
and [movement](verification/open-approach/movement.json). Independent
[source CI](https://github.com/Mirne/Tabara/actions/runs/43422901457) passed.

All six cached terrain fields equal fresh geography, and all six navigation
fields equal fresh shortest-path searches. A separate comparison to v0.8 confirms
its five terrain/navigation fields are unchanged, and its original minimap is
preserved byte for byte. Every ordinary open cell in the new layout connects to
the hall. All eight producers fit their matching sites. Their centres stay at
least 220 world units from every painted trail and 300 from the pass opening.
The former near-pass logging foundation accepts walls.

Model checks exercise instant upgrades through level 100 for all eight building
types, payment, future inheritance and preservation of damage fractions. Automatic
Regeneration is purchased once, heals completed standing buildings over time,
persists after Workshop destruction, caps at 100 and never resurrects a destroyed
structure. Old paid research and local repair remainder finish once on migration;
new saves contain neither timer. Miniboss tests cover exact 5-, 10-, 15- and
20-minute boundaries and reload without duplicate spawning. Elites and minibosses
use ordinary incoming weapon damage.

Rendered interaction tests place fifteen towers with one tool selection and
fifteen preview/confirm pairs, keeping the tool active and selection empty after
each build. They cover instant repeated global upgrades, Regeneration, removal of
manual repair controls, trading, speed, pinch, pause, saves, Back and endless mode.
Three wall strokes make a complete 3×3 block; its interior has no parapets and its
perimeter has twelve exposed edges. A drag beginning and ending inside red
mountains builds exactly the six valid sections across the pass, charging only
those sections. Completed screenshots show a single shared deck and outside
parapet instead of nine junction towers.

Screenshots are actual engine renders. The initial catalogue has the real budget;
developed visual fixtures explicitly grant supplies and place a Warlord near the
settlement to review its art. They are not normal-cost campaign evidence.

## Difficulty and stability

Three seeded campaigns using paid player orders reached the 15-minute victory,
then fell at 946.15, 945.95 and 946.65 game seconds (wave 32). The defender uses the
new instant global levels and Regeneration; it buys an early cannon before sealing
the pass, then adds defenses and replacements. No resources are granted. This is
a small sample of one strategy, not a guarantee for every player. See
[balance evidence](verification/open-approach/balance.json).

A rendered normal-cost soak completed 360.03 confirmed real seconds,
with 5 disk restores, 14 camera tours and no invariant failures.
It crosses the first natural miniboss boundary. See [soak evidence](verification/open-approach/soak.json).
No extreme-load performance claim is carried over from v0.8; its stress evidence
remains in that release.

## Native Android and update compatibility

The **exact signed download APK** passed all **61 native checks** on
Android 7/API 24 across two segments after an environment outage. The resumed segment took 683.07 seconds; the earlier segment's active duration was not retained. Its 34 completed checks are preserved in the [prior log](verification/open-approach/native-previous-segment.log). The installed package SHA-256 was checked against the signed download before resuming. Actual input constructed
both producers, two towers without reopening their catalogue, and the six-section
wall from red endpoints. Instant global levels, paid automatic Regeneration,
pause, Back, cold restart, panning and app switching passed. Captured diagnostics
contain no script, shader or fatal error. See [native report](verification/open-approach/native-android.json)
and [paused native boundary fixture](screenshots/android-open-approach-miniboss-and-regeneration.png).

Independent [Android 15/API 35 CI](https://github.com/Mirne/Tabara/actions/runs/43422902952) passed all
54 checks in 480.47 seconds. Its separately signed APK has
SHA-256 `290de793684e628e1345f161ef310acb8827ff30a82c0aad1faa327291225972`. See [API 35 evidence](verification/open-approach/android-api35.json).

The actual **v0.8-to-v0.9 install** passed all **20 checks** in
326.31 seconds. The published v0.8 app restored and wrote a format-seven,
terrain-four fixture containing a paid global arrow upgrade and local repair
progress. Android retained the complete save file during installation. v0.9 kept
foundations, economy, mission progress and the old eight sites, completed the paid
arrow upgrade without charging again, retained the remaining repair health and
removed both kinds of timers. Regeneration remains locked for that legacy save.
See [update evidence](verification/open-approach/native-upgrade.json) and
[updated legacy settlement](screenshots/android-open-approach-updated-legacy.png).

The persistence/lifecycle fixture may clear incoming attackers after paid
construction to isolate restoration from legitimate combat destruction; this
grants no resources. The exact fixtures used are disclosed in the native reports.

The native miniboss check uses an explicit saved-clock boundary fixture at
299.95 seconds and a damaged Hall. It grants no supplies, verifies one Warlord
enters from the western entrance and the Hall heals automatically, then restores
the original native settlement. This is a timing/rendering fixture, not a claim
of five minutes of uninterrupted native campaign play.

Packaging losslessly compresses texture ZIP entries, verifies each uncompressed
payload against the Godot export, aligns native libraries and signs with the same
development key used by v0.8. Scripts and texture pixels are unchanged by packaging.
See [packaging evidence](verification/open-approach/packaging.log). Signing keys
are excluded from Git.

## Limits

No physical handset was available. Local Linux/Android use software rendering and
CPU emulation; their timing does not predict S23 Ultra performance. This is a
development-signed sideload build. Start a new settlement for the relocated
resources; updating preserves the terrain and positions of an existing settlement.
All other gameplay and control changes apply to loaded settlements.
