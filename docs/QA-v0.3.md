# Mobile grid revision verification

This record covers Tabara: Last Hearth **0.3.0**, Android version code **3**.
[The preceding frontier record](QA-v0.2.md) and [v0.1 record](QA-v0.1.md) are
historical. Their measured durations are not added to this revision's testing.

## Runtime and APK

- Runtime commit: `311ffc322ad1d136bad0aa0b812e72108bf9be4c`.
- Godot 4.6.3 Compatibility renderer; package `com.tabara.lasthearth`.
- Android API 24 minimum, API 36 target; ARMv7, ARM64 and x86-64.
- APK: `builds/tabara-frontier-v0.3.apk`, 100,755,023 bytes.
- SHA-256: `46d640274dd684c5696b1b8704bf98dfdc90e83c9d50488915cd0aa3f8d8962b`.
- APK v2 and v3 signatures verified; no requested permissions.
- Development signed; private signing keys are excluded from source.

## Completed functional checks

The model passed **2,876 checks**, including level 100, combat, economy, wave
dispatch, victory/endless/defeat, saves, adjacent grid foundations, partial
foundation overlap, resource-site requirements, one producer per deposit,
reservation through ruins, release after clearing and gold paid once per kill.
A normal-cost campaign reached 18.3 game minutes with 17 paid structures.

The saved v0.2 campaign fixture restores without moving existing buildings or
losing progress. Legacy producers reserve their closest matching deposit; new
producers must occupy an available matching site. Save format remains version 2.

The rendered interface passed **97 checks** covering actual pointer and
native-style touch input, preview without spending, separate confirmation,
cancellation, disabled invalid placements, right-hand construction controls,
protected quarry scenery, camera drag/pinch/minimap, repairs, demolition,
trading, pause/Back, lifecycle, victory and defeat. The final marker verification also passed on the committed renderer.
See [model log](verification/mobile-grid/model.log) and
[rendered UI log](verification/mobile-grid/rendered-ui.log).

## Completed rendered endurance run

The committed v0.3 runtime completed **3600.021 confirmed real
seconds** (one hour) in one uninterrupted segment. The report records **zero
excluded stall seconds**, **58 actual disk restorations**, **145 camera tours**,
one campaign and one victory followed by endless play. Resource, health,
position, level, enemy, zoom, transient-effect and style-cache invariants remained
valid. The completed engine log contains no script/shader errors or shutdown
resource errors. See [report](verification/mobile-grid/endurance.json) and
[engine log](verification/mobile-grid/endurance.log).

This test used Linux Mesa llvmpipe software rendering at 1280 × 720 with a 30 FPS
cap while native emulation, balance sampling and packaging also used the host.
Its minimum sampled FPS was 3; this is not a physical S23 benchmark. Engine
static allocation at completion was 43.4 MiB. The largest sampled OS high-water RSS
was 359.8 MiB; these are different memory measurements.

The earlier v0.2 run was intentionally interrupted at 7,251.514 seconds for the
new mobile requirements. Its duration and victories are **not** added to this
v0.3 result. The owner's requested five-hour work minimum was also met before
this handoff.

## Campaign balance and source CI

All **12 of 12 normal-cost seeded campaigns** reached the 15-minute victory and
remained alive at the **25-minute cutoff**. This cutoff is not a measured defeat
time. The bot gathers only nearby available deposits, pays all public prices,
limits paid actions to one per second and reserves matching resource sites.
See [balance report](verification/mobile-grid/balance.json).

[GitHub source verification](https://github.com/Mirne/Tabara/actions/runs/42819986786)
passed on source commit `f784e34deae096db3a40e0a097de1770039fb6cd`, which contains
the unchanged runtime above plus documentation. Only documentation/evidence
changes follow that run; app runtime changes require fresh checks.

## Native Android result

The **exact APK hash above passed all 32 checks** in one unified Android 7/API 24
x86-64 software-emulator run. It took **1,131.03 real seconds**. Actual touch
preview followed by a forced save kept only the original hall; separate Build
confirmation created wood, stone and arrow buildings at their expected grid
positions. Cold restart retained kinds, positions and upgrades. Back, camera
dragging without accidental construction, Home/background save and foreground
resumption passed. Captured diagnostics had no script, shader or fatal error.

The final Back sequence advanced the saved clock from 43.80 to 47.65 game
seconds, then held it fixed. See [native report](verification/mobile-grid/native-android.json)
and [actual native preview](screenshots/android-v0.3.png).

The APK uses the same signing certificate as v0.2 and a higher version code,
allowing an in-place Android update. The v0.2 save fixture also passed model
restoration without relocating its structures. ARMv7 and ARM64 were packaged;
the native executed ABI here is x86-64. Physical S23 performance of v0.3 has not
been certified. The separate one-hour endurance result is recorded above.

## Evidence and distribution

Final v0.3 reports are saved under `docs/verification/mobile-grid/`. The owner
explicitly approved publishing the game source and APK to Mirne/Tabara. APK
hosting uses the isolated `downloads/frontier-v0.3.0` branch, containing only the
APK and its checksum. The public HTTPS link is downloaded again and compared
against the native-tested hash before being shared. The local
recording, standalone build metadata and optional publication automation are
not publicly uploaded. A final source archive can be downloaded from GitHub's
ordinary archive endpoint after the source branch is updated.
