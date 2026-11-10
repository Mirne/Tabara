# Resource sites, walls and assault verification

This record covers Tabara: Last Hearth **0.4.0**, Android version code **4**.
[The v0.3 record](QA-v0.3.md), [v0.2 record](QA-v0.2.md) and
[v0.1 record](QA-v0.1.md) are historical. Their test durations do not certify
this revision.

## Runtime and package

- Runtime commit: `2a1da70677d2e7b02c53c9a7ee92ac5ca4fc64eb`.
- Godot 4.6.3 Compatibility renderer; package `com.tabara.lasthearth`.
- Android API 24 minimum, API 36 target; ARMv7, ARM64 and x86-64.
- APK: `builds/tabara-frontier-v0.4.apk`, **101,640,356 bytes**.
- SHA-256: `4f94744710c8547f265e1a802fd27eb3b8f02814b2939c0c9760e244f314c457`.
- APK v2/v3 signatures and ZIP CRC verified. No requested permissions.
- Same development signing certificate as v0.3; version code increases to 4.
- Private signing keys are excluded from source and package contents.

See [signature](verification/assault/apk-signature.txt) and
[package inspection](verification/assault/apk-package.txt).

## Functional checks

The model passed **3,236 checks, zero failures**. New coverage includes passive
resources, atomic whole-stroke wall costs, reused endpoints, live adjacency,
breaches and repairs, direct hall approach, destruction before passage, ignoring
side buildings, crowd separation, terrain routing around the lake, cached attack
target invalidation, and save version 3. Existing economy, level 100, combat,
victory/endless/defeat and restoration checks also pass. The normal-cost seed-11
campaign reaches 1,100 game seconds with 17 structures and 2,455 kills.

Version-2 frontier files migrate old road progress to actual enemy positions,
retaining building positions, resources and mission time. Version-3 JSON round
trips preserve deterministic continuation within floating-point precision.

The rendered interface passed **106 checks, zero failures**. Actual pointer and
native-style touch events cover passive resource art, one-image sites, dragging
wall previews without panning, separate confirmation, total stroke costs,
reused endpoints, corners and existing placement/repair/trade/lifecycle controls.
See the [combined local verification log](verification/assault/functional.log).

[GitHub source verification](https://github.com/Mirne/Tabara/actions/runs/42839388074)
also passed on the runtime commit above. Later documentation and test-comment
changes do not alter the packaged app.

## Campaign balance

**6 of 6 normal-cost seeded campaigns** reached the 15-minute victory and
remained alive at the **25-minute cutoff**. This is not a measured defeat time.
The bot performs at most one paid action each second, uses producers on matching
resource sites, pays public prices, repairs and upgrades. It receives no manual
resource gathering or grants. See [report](verification/assault/balance.json)
and [log](verification/assault/balance.log).

## Extreme fixture and performance scope

The explicit stress scene uses 512 structures, 1,000 high-health, low-damage
enemies, unlimited supplies and a 30 FPS cap. It is separate from balance.
Before collision/attack caching, mean model CPU cost was **62.97 ms** per sampled
frame. On the same fixture after caching it was **16.52 ms**; mean world draw
CPU cost was **11.89 ms**. The final 60.147-second run retained all 512 structures
and 1,000 enemies with a live simulation and 1,163 rendered entities.

Linux Mesa llvmpipe software rendering on the shared host averaged **12.632
sampled FPS**, minimum 8 after warm-up. This extreme scene is not a handset
benchmark or a claim of smooth 1,000-enemy play on the S23. Engine static
allocation peaked at 46,974,973 bytes; this is not total OS memory usage.
See [before](verification/assault/stress-before-cache.json) and
[after](verification/assault/stress-optimized.json).

## Rendered endurance

The committed runtime completed **1800.021 confirmed real seconds**
(30 minutes) in 1 uninterrupted segment. It recorded **29 actual disk
restorations**, **74 camera tours**, two campaigns and one victory. The first
settlement continued into endless play and was eventually defeated. The runner
then started a second settlement; the final mission clock of 97.75 game seconds
belongs to that fresh attempt. Defeat is an intended game outcome, rather than
a test invariant failure.
Resource, health, level, actual enemy-position, world-boundary, camera and
transient-state invariants remained valid. The full engine log contains no
script/shader errors or shutdown resource errors.

The report excludes **0.020 seconds** of frame gaps above two seconds;
these are not counted toward the 30 minutes. Testing used Linux Mesa llvmpipe
software rendering at 1280 × 720 with a 30 FPS cap, sharing the host with local
Android emulation for part of the run. Minimum sampled FPS after warm-up was
5; this is not a handset benchmark. Engine static allocation peaked at
40,408,634 bytes, a different measure from total OS memory.
See [report](verification/assault/endurance.json) and
[engine log](verification/assault/endurance.log).

## Native Android

The existing [Android 15/API 35 workflow](https://github.com/Mirne/Tabara/actions/runs/42840532877)
passed all 37 native checks on the runtime commit. This accelerated x86-64
emulator built its own APK from the same source; its report hash belongs to that
CI build, not the downloadable package. See [CI report](verification/assault/native-api35-ci.json).

The **exact downloadable APK hash above passed all 37 checks** on the local
Android 7/API 24 x86-64 software emulator in **1,112.43 real seconds**. Actual
Android touch input previewed each producer/tower without spending, confirmed
construction at the expected grid coordinates, dragged a three-section wall
without constructing on release, then confirmed all three connected sections.
Cold restart retained the seven structures, positions and levels. Camera drag
created no accidental building. Hardware Back, Home/background save and
foreground resumption passed. Captured diagnostics contained no script, shader
or fatal error. The final Back sequence advanced the saved clock from 91.50 to
96.75 game seconds and then held it fixed.

See [exact-APK report](verification/assault/native-android.json),
[native log](verification/assault/native-android.log),
[wall preview](screenshots/android-wall-preview.png) and
[confirmed wall](screenshots/android-wall-built.png).

ARMv7 and ARM64 are packaged; executed native tests here use x86-64. These
emulator results do not certify physical S23 performance. The same signing
certificate and higher version code permit an in-place update; existing
frontier-save migration is covered by the model tests above.

## Distribution

The owner approved source and APK publication to Mirne/Tabara. The isolated
`downloads/frontier-v0.4.0` branch contains only the APK and checksum. A fresh
public HTTPS download returned status 200 and all 101,640,356 bytes; its SHA-256
matched the exact native-tested package before handoff.
The release points to the source and QA record. Local video, private keys,
standalone build metadata and optional publication automation are not uploaded.

Screenshots show actual rendering: the initial settlement, compact resource
sites, wall preview and joined corner. The five-minute settlement capture uses
seed 11 and normal-cost bot actions; it is a visual check rather than additional
endurance time.
