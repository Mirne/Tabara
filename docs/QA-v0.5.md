# Mountain pass and mobile HUD verification

This record covers Tabara: Last Hearth **0.5.0**, Android version code **5**.
[Version 0.4](QA-v0.4.md) and earlier QA records are historical. Their measured
durations and prototype results do not certify this revision.

## Final runtime and package

- Runtime commit: `60185b7466be142ba1fdf2f396f7da2858630c8d`.
- Godot 4.6.3 Compatibility renderer; package `com.tabara.lasthearth`.
- Android API 24 minimum, API 36 target; ARMv7, ARM64 and x86-64 packaged.
- APK: `builds/tabara-frontier-v0.5.apk`, **102,123,893 bytes**.
- SHA-256: `583c6ae49ffe8dfe8f92ba760ed9559cc3bcd8c8fd97e21d1447b730465b3355`.
- ZIP CRC and APK v2/v3 signatures verified; no requested permissions.
- Same development signing certificate as v0.4, with a higher version code.
- Private signing keys are excluded from source and package contents.

See [signature](verification/mountain-pass/apk-signature.txt) and
[package inspection](verification/mountain-pass/apk-package.txt).

## Functional and rendered checks

The final model passed **3,240 checks with zero failures**. New tests compare
all terrain grid cells against navigation, route actual enemies around a
forest, check standing walls stop movement, and verify attackers advance after
breaking a wall. A flood-fill test proves that the mountain spines plus a
six-section pass wall separate the western entry from the main hall: attackers
cannot bypass the sealed pass around the map edges. Existing combat, economy,
level 100, repair/ruins, save, victory/endless/defeat and campaign checks pass.
The seed-11 normal-cost campaign reached 1,100 game seconds with 17 structures
and 2,445 kills.

The rendered interface passed **118 checks with zero failures**. Coverage
includes footprint/dirt centring, passive resource images, both tower range
previews, wall dragging and corners, red invalid placement, permanent separate
cost rows, and actual simulation-clock advancement at 1×, 2×, 5× and 10×.
Taking damage leaves the rendered upgrade-price row unchanged. Hall is in the
top bar; HUD branding, Guide and +/− controls are absent. Pinch, camera movement,
confirmation/cancellation, trading, repairs and lifecycle checks still pass.
See [combined verification log](verification/mountain-pass/functional.log).

[Source CI](https://github.com/Mirne/Tabara/actions/runs/42853543736): passed on the final runtime commit.

## Terrain and save compatibility

Construction and enemy movement use one cached **40-unit terrain mask**.
Resource cores, water, ridges, mountains and boundaries are impassable. A
producer may be built on its matching resource site; this does not make the
resource core traversable. Standing buildings are red and must be destroyed
before passage; traversable ruins are amber. Type-specific placement errors or
an unaffordable preview do not create new physical obstacles on clear ground.

Save version 4 preserves building positions, levels, economy and mission time
from version-2/3 frontier saves. Existing settlements receive the pass unless
a foundation intersects a new ridge; those settlements keep the earlier
mountain layout. Legacy enemies inside blocked resource cells recover to the
nearest open cell when movement resumes. Both layout choices survive saving.

## Campaign balance

All **6 of 6 normal-cost seeded campaigns** reached the 15-minute victory and
remained alive at the **25-minute cutoff**. This cutoff is not a measured defeat
time. The bot uses the public prices, at most one paid action per second, no
resource grants and no manual resource gathering. It builds matching producers,
repairs and upgrades. See [report](verification/mountain-pass/balance.json) and
[log](verification/mountain-pass/balance.log).

## Native Android

The existing [Android 15/API 35 workflow](https://github.com/Mirne/Tabara/actions/runs/42853546058)
passed all **37 native checks** on the final runtime source in **279.25 seconds**.
This accelerated x86-64 emulator built its own APK. Its report hash belongs to
that CI build, rather than the downloadable package. See
[CI report](verification/mountain-pass/native-api35-ci.json).

The **exact downloadable APK hash above passed all 37 checks** in one local
Android 7/API 24 x86-64 software-emulator run, lasting **1301.38 real seconds**.
Actual Android input confirmed producer/tower grid positions and a three-piece
wall stroke. Releasing a drag preview spent nothing; a separate confirmation
created all sections. Cold restart kept positions and upgrades. Camera dragging
created no accidental building. Back, Home/background save and foreground
resumption passed. The final Back sequence advanced the saved clock from
80.60 to 88.20 game seconds, then held it fixed. Captured diagnostics contained
no script, shader or fatal error.

See [exact-APK report](verification/mountain-pass/native-android.json),
[engine/test log](verification/mountain-pass/native-android.log),
[actual wall preview](screenshots/android-wall-preview.png) and
[confirmed wall](screenshots/android-wall-built.png).

ARMv7 and ARM64 are packaged; the executed native ABI here is x86-64.
These emulator results do not certify physical S23 performance. The signature
and higher version code allow an in-place update; model tests cover legacy
save migration.

## Rendered endurance

The final committed runtime completed **1200.031 confirmed real
seconds** (20 minutes), in 1 uninterrupted segment. It recorded **19 actual disk
restorations**, **49 camera tours**, 1 campaign and 1 victory, followed by
endless play. The final mission clock was 1194.65 game seconds.
Resource, building, actual enemy-position, world-boundary, level, health,
camera and transient-state invariants remained valid. The full engine log has
no script/shader errors or shutdown resource errors.

The report excludes **0.000 seconds** of frame gaps over two seconds;
these are not counted toward the 20 minutes. The run used Linux llvmpipe
software rendering at 1280 × 720 with a 30 FPS cap, sharing CPU time with native
emulation, export and campaign sampling. Minimum sampled FPS after warm-up
was 2; peak engine static allocation was 39,401,002 bytes.
These measurements are not physical S23 benchmarks or total OS memory usage.
See [report](verification/mountain-pass/endurance.json) and
[engine log](verification/mountain-pass/endurance.log).

An earlier prototype segment was intentionally stopped for the final short-wall
art and terrain-check changes. Its duration is not added to this final result.

## Extreme fixture and limits

The explicit stress scene retains **512 structures and 1,000 high-health,
low-damage enemies**, with unlimited supplies and a live simulation. The final
60.166-second sample used Linux llvmpipe software rendering on the shared host
while Android emulation, export and campaign checks also used CPU time.
Mean sampled FPS after warm-up was **4.379**, minimum 1. Mean sampled model CPU
cost was **72.39 ms/frame** and world draw CPU cost **31.96 ms/frame**. It rendered
1,188 entities and peaked at 47,056,353 bytes of engine static allocation.
These figures are an extreme software-rendered fixture, not a physical S23
benchmark or a smooth-1,000-enemy claim. They are not directly comparable to
v0.4's different terrain and art workload. See [report](verification/mountain-pass/stress.json)
and [engine log](verification/mountain-pass/stress.log).

## Art and distribution

Resource-site sprites were regenerated without the pale base mats. Horizontal
and vertical wall modules retain their complete silhouettes; the renderer no
longer shears a slice from an oblique wall image. Building sprites and dirt
patches share a ground-centred pivot. A normal-cost seed-11 capture at 93 game
seconds shows 12 paid/prebuilt structures and the sealed mountain pass. It is
a visual check, not extra endurance time. See [settlement](screenshots/v0.5/gameplay.png),
[blocked mountain and range preview](screenshots/blocked-terrain.png),
[separate costs](screenshots/separate-action-costs.png) and
[joined corner](screenshots/joined-walls.png).

The owner approved publishing the game source and APK to Mirne/Tabara. The
isolated `downloads/frontier-v0.5.0` branch contains only the APK and checksum.
A fresh public HTTPS download returned status 200 and all 102,123,893 bytes.
Its SHA-256 matched the exact native-tested APK before handoff.
Local videos, private keys, standalone build metadata and optional publication
automation are not uploaded.
