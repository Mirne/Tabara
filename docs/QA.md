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

## Additional checks in progress

A fresh **one-hour** rendered endurance test is running on the runtime commit
above. It performs normal-cost play, world tours, settings/pause and actual disk
restoration every minute. It is separate from the intentionally interrupted
v0.2 two-hour run. Final counters will be recorded when this test finishes.

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
and [actual native preview](screenshots/android.png).

The APK uses the same signing certificate as v0.2 and a higher version code,
allowing an in-place Android update. The v0.2 save fixture also passed model
restoration without relocating its structures. ARMv7 and ARM64 were packaged;
the native executed ABI here is x86-64. Physical S23 performance of v0.3 has not
been certified. Multi-seed balance sampling and the one-hour endurance run are
still in progress; they are not counted as passes yet.

## Evidence and distribution

Final v0.3 reports are saved under `docs/verification/mobile-grid/`. The owner
explicitly approved publishing the game source and APK to Mirne/Tabara. APK
hosting uses the isolated `downloads/frontier-v0.3.0` branch, containing only the
APK and its checksum. The public HTTPS link is downloaded again and compared
against the native-tested hash before being shared. The local
recording, standalone build metadata and optional publication automation are
not publicly uploaded. A final source archive can be downloaded from GitHub's
ordinary archive endpoint after the source branch is updated.
