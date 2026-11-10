# Verification record

This record applies to the development-signed Android build of **Tabara: Last
Hearth 0.1.0**. The game is playable offline; a store release still needs the
owner's release signing key and an Android App Bundle export.

## Build identity

- Godot: **4.6.3 stable**, Compatibility renderer.
- Package: `com.tabara.lasthearth`.
- Android: minimum API 24, target API 36; ARMv7, ARM64, and x86-64.
- APK SHA-256: `bd9d6f1f84f6a44530c9e62ced604ba0f1318cd26b5f714a26ad366a982728b6`.
- Runtime source commit: `7a400293e65cba2051ce6c634273d04644e2b298`.

Later source commits improve the test harness and documentation; the delivered
APK's runtime scripts, assets, scene, and project configuration are unchanged.
The APK's signatures were verified, and its manifest requests no permissions.

## Model, interface, and balance

The final `python3 tools/verify.py --ui` run passed **1,464 simulation checks**
and **33 rendered interface checks**, with no engine script errors. Coverage
includes construction, production, combat, level-100 upgrades, repairable ruins,
save validation, the 15-minute victory, endless continuation, menus, and pointer
interactions. The verifier treats engine script errors as failures even when
Godot exits with status zero.

The normal-cost player bot completed the first mission in **12 of 12 seeded
campaigns**. Each campaign then continued until defeat, between **17.7 and 22.9
in-game minutes** (median **19.95 minutes**). These are automated balance samples,
not a guarantee that every player strategy will win.

## Six-hour gameplay test

Completed on **10 November 2026**: **21,600.018 confirmed real seconds**,
**21,322 bot action cycles**, **18 observed victory events**, and **347 disk
save/restorations**, with **zero invariant failures**. The final report records
`complete: true` and an empty `errors` array.

Maximum engine-reported static allocation was **41,445,714 bytes (39.53 MiB)**.
This is Godot's static allocation metric, not total process resident memory.

This test uses the Linux game runtime on a virtual display, the Compatibility
renderer, and a 30 FPS cap. Native Android checks are recorded separately below.

The harness buys buildings and upgrades at normal prices, gathers resources,
repairs damage, accepts victory and continues into endless survival. It checks
resources, buildings, enemies, and bounded transient state; it also exercises
settings, pause, autosaves, and repeated disk save/restoration.

An infrastructure reconnect interrupted the first test segment. The resumed
test counts only **3,451.302 confirmed seconds** from that segment plus actual
running time in the second segment. Reconnect downtime is excluded. This is a
test across **two segments**, not an uninterrupted six-hour process. The raw
session counter can undercount one mission attempt at the interruption, so it
is not used as a campaign-count result.

Evidence: [final report](verification/soak-final.json),
[first-segment checkpoint](verification/soak-first-segment.json),
[first-segment log](verification/soak-first-segment.log), and
[resumed-segment log](verification/soak-resumed-segment.log).

## Native Android evidence

The Android 15/API 35 emulator in [this GitHub verification run](https://github.com/Mirne/Tabara/actions/runs/42730688110)
passed **22 core checks**: installation, launcher and menu rendering, real touch
construction, advancing and paused mission time, cold restart with retained
buildings and elapsed time, background save, and captured crash/script-error
diagnostics. A later dedicated Back-navigation check prompted the current
explicit Android Back handling; the core run predates that final change.

The exact delivered APK was also installed on a software-only Android 7/API 24
emulator using ANGLE. All **28 recorded functional steps** completed in one run,
including construction, save restoration, pause, and hardware Back. That full
harness run did **not** report an overall pass: its final unbounded log dump
timed out. A separate bounded diagnostic capture contained no script error or
fatal exception. The helper now bounds that capture.

A separate fresh-activity Back test passed **all five checks** on the delivered
APK. It confirmed visible menu/pause screens, a game-clock advance from **9.70
to 10.75 seconds** after hardware Back, a frozen clock after the next Back,
and clean captured native diagnostics.

Repeated unified runs on the software-only API 24 emulator sometimes stalled
the graphics surface after the app was backgrounded. Cold restart, persistence,
touch construction, and foreground Back were verified separately. The
background graphics-resume issue remains a compatibility limitation observed
in that emulator; it has not been certified or resolved on a physical device.
No claim is made that one unified API 24 smoke run passed end to end.

See the [native evidence summary](verification/native-summary.json),
[API 35 core report](verification/android-api35-core.json),
[API 24 functional report](verification/android-api24-functional.json),
[API 24 background-limit report](verification/android-api24-background-limitation.json),
[isolated Back report](verification/android-api24-back.json), and
[balance samples](verification/balance.json). The source includes reproducible
simulation, UI, soak, and native Android test scripts. Raw temporary test outputs
remain in the workspace's ignored `test-results/` directory.

## Delivery checks

The full source archive is generated from the final local Git commit, includes
the image-generated art and source tests, and excludes private signing keys and
generated build directories. Its ZIP CRC and required project entries are
checked. `builds/SHA256SUMS.txt` identifies the delivered APK, Linux executable,
and source ZIP; `builds/BUILD_INFO.json` connects them to source and test evidence.
