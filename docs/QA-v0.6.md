# Hearthvale Basin v0.6 verification

This record applies to the authored-map and textured-rampart revision. Earlier
release evidence is archived in [QA-v0.5.md](QA-v0.5.md).

## Build identity

- Runtime: `939adaae7443afbf2dc7a1101d5bd473d14ec0f5`.
- Godot 4.6.3, app 0.6.0, Android version code 6, save format 5.
- Android API 24 minimum, API 36 target; ARM64 and x86-64 packaged.
- APK: `tabara-frontier-v0.6.apk`, **101,443,481 bytes**.
- SHA-256: `2014b3a0d4d4dc14784a94c6ddd17bd43e9bff605fd3f4772f489901be041afa`.
- Development certificate unchanged from v0.5: SHA-256
  `dbd0f5f2a2a56082d36b733d6467f28dc7dc166e82ffe41d0dc2c2fe42cd6ebb`.

## Functional and map checks

`python3 tools/verify.py --ui` completed with:

- **3,287 simulation checks**, zero failures.
- **82 authored-world checks**, zero failures.
- **119 rendered interface checks**, zero failures.

The authored-world suite compares every cell in all three supported terrain
layouts with a fresh bake. It compares every shortest-path cost and successor
with a fresh Dijkstra search, verifies safe descending routes with no diagonal
corner cutting, and checks every producer site. All 28 resource atlas assignments
are different. Four mountain images and six landmark frames are each assigned
once. Landmark foundations block both placement and enemy movement.

The other suites cover the complete mountain-pass barrier with a flood-fill
proof; actual forest avoidance and building destruction; mobile tap-preview
and separate confirmation; dragged wall strokes, endpoint reuse and corners;
independent repair/upgrade prices; tower attack ranges; all levels through 100;
gold rewards; immediate western spawning; victory/endless continuation;
1×/2×/5×/10× clocks; pinch; Hall navigation; Back and lifecycle behavior.

A further actual-movement fixture sent raiders from **48 stratified map origins**
to the Hall. All arrived, and all **15,407 sampled positions** remained on open
terrain. This exercises the production movement code around the irregular
geography; Hall fire and additional wave spawning are suppressed for the routing
fixture. It is not a balance measurement. See
[movement.json](verification/authored-basin/movement.json).

New settlements select terrain revision 2. Version-four saves retain revision
0/1, building and enemy positions, and resources. Version-five round trips
retain all three terrain revisions. Malformed revisions are rejected. The old
free-position fixture is still exercised by the main suite.

An isolated workspace rebuild also reproduced the complete terrain, navigation
and surface-mask JSON data exactly using the checked-in bake tool.

Visual review caught and corrected a landmark atlas grid mismatch before the
runtime was frozen. Reviewed actual-game captures include the pass, confirmed
wall line, L-shaped corner, blocked mountain preview, watchfort, chapel, and
irregular lake with its single jetty. The settlement capture uses normal costs:
seed 11, 93 game seconds, 12 structures, no resource grants.

## Native Android

The **exact download APK** passed all **37 native checks** on Android 7/API 24
in 1,628.594 real seconds. This covers confirmed resource/tower/wall construction,
saved grid positions, paused clocks, Back, cold restart, camera dragging and
background/foreground behavior. Captured diagnostics contained no script,
shader or fatal error. See the [exact-APK report](verification/authored-basin/native-android.json)
and [actual Android wall](screenshots/android-hearthvale-wall-built.png).

The local setup used software CPU emulation with swangle. Emulator boot raised
a system-process “Wait” dialog; after dismissing it, the complete test passed.

The independent [Android 15/API 35 workflow](https://github.com/Mirne/Tabara/actions/runs/42919555486)
built a second APK from the same runtime source and passed all **37 native
checks** in 269.193 seconds. That CI APK has SHA-256
`9a65b1086d9f1dc6b2c9c06d3eaaef45adea606a814973b779647c8fcbdf6c4e`.

The [source verification workflow](https://github.com/Mirne/Tabara/actions/runs/42927436525)
passed all **3,287 + 82 + 119** checks and the **48 actual movement routes** on a
clean checkout. Its test-tool commit is
`3263a3bcbe2fe55373d48d94e76b69a16d60f965`; application scripts, assets and export
settings match the runtime identified above.

An **actual v0.5-to-v0.6 installation test** then passed **16 checks** in
514.596 seconds. The published v0.5 APK loaded and wrote its version-four save;
v0.6 was installed over it without clearing app data. The complete save file
survived installation. Loading it migrated the format to version five while
preserving terrain revision 1, every building kind/position/level, resources,
mission time and kills. The test restored its authored-map fixture afterward.
Filtered Godot diagnostics contained no script, shader or fatal error. See the
[upgrade report](verification/authored-basin/native-upgrade.json) and
[updated legacy settlement](screenshots/android-updated-legacy.png).

## Campaign, endurance and stress

The extreme fixture completed 60.286 real seconds with all **512 structures and
1,000 high-health enemies** present. It grants unlimited supplies and does not
measure campaign balance. On shared Linux llvmpipe software rendering, the mean
sampled frame rate was 5.113 FPS (minimum 3); mean model CPU time was 63.585 ms
and mean world draw-command CPU time 28.151 ms. This is an extreme shared-host
measurement, not a phone benchmark. The report is in
[verification/authored-basin/stress.json](verification/authored-basin/stress.json).

All **six normal-cost campaigns** reached the 15-minute victory and survived
the 25-minute cutoff (wave 50), with 4,344–4,353 kills. No resources were granted.
The six-seed run took 445.076 real seconds; each campaign also exercised
periodic save round trips. See [balance.json](verification/authored-basin/balance.json).

The rendered endurance test completed **70.000 actual
minutes** across two game processes: a continuous 65-minute run followed by a
fresh-process load of its saved settlement and five more minutes of play. Both
segments use the same frozen runtime. The test exercised **3 settlements,
2 victories, endless continuation and defeat**, with **68 disk restorations**,
**4150 normal-cost action cycles**, and **173 camera tours**. No invariant,
script, shader or shutdown-resource errors were recorded.

The active-time counter excludes frame gaps beyond two seconds; total excluded
stall time was 0.000 seconds. Peak Godot-tracked static allocation was
44.21 MiB; this excludes driver/GPU allocations and is not total application
memory. The [first segment](verification/authored-basin/endurance-initial.json)
and [combined report](verification/authored-basin/endurance.json) preserve the
actual time and fresh-process resume evidence.

## Limits

The local host and emulator use software rendering. Their frame rates do not
measure the S23 Ultra. No physical handset was available for verification.
The APK is a development-signed sideload build, not a Play Store release.
The richer build requires a 64-bit device. Existing settlements preserve their
old terrain; start a new settlement to see the authored map.
