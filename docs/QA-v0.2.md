# Frontier revision verification

This record covers **Tabara: Last Hearth 0.2.0**, the large-world frontier revision.
The previous prototype's results are kept separately in [QA-v0.1.md](QA-v0.1.md)
and do not certify this revision.

## Build identity

- Runtime commit: `b97ef79028553b5a02ebc5a419ac48f0510f9ad9`.
- Godot: **4.6.3 stable**, Compatibility renderer.
- Package: `com.tabara.lasthearth`, version code **2**, version **0.2.0**.
- Android: minimum API **24**, target API **36**; ARMv7, ARM64 and x86-64.
- APK SHA-256: `fe0b8a6fe5540247735c6be329b57c78412b1c705991e02c215f02b2a3d5fd14`.
- APK signatures: **v2 and v3 verified**; the manifest requests no permissions.

The APK is signed with a local development key. The owner must configure a
release key and AAB export before a store submission. Private signing keys are
not included in the source archive.

The exported standalone Linux executable also completed a headless startup and
clean shutdown. Native Android verification passed as recorded below.

## Functional checks

The final `python3 tools/verify.py --ui` run passed **2,860 model checks** and
**77 rendered interface checks**, with no script/shader errors or shutdown
resource errors. Model coverage includes free placement, collisions, terrain
restrictions, all level-100 upgrades, injury-preserving upgrades, destroyed and
repaired buildings, clearing/reusing ground, persistent vegetation clearings,
market prices, save validation, crowd headway, invalidated cached targets,
15-minute victory, endless continuation and hall defeat.

Rendered checks use actual pointer and native-style touch events. They exercise
construction, camera transforms, drag suppression of placement, two-finger
pinch, minimap navigation, repair, confirmed demolition, replacing a foundation,
trading, resource gathering, settings, camera/model disk restoration, Android
Back notification handling, victory and defeat. Captures are inspected as part
of visual review; the verifier also rejects engine errors when exit status is 0.

## Campaign balance

All **12 of 12 seeded campaigns** reached the 15-minute victory and remained
alive at the **25-minute test cutoff** on the corrected runtime. This cutoff
is not a measured defeat time. The model suite also ran a normal-cost campaign
through 18.3 in-game minutes, with 17 structures and 2,420 defeated raiders.

The player bot gathers only nearby deposits, pays the public construction,
upgrade and repair prices, and performs at most one paid action per second.
It does not receive the stress fixture's resource grants.

## Extreme-load measurement

The final 90-second fixture simulated **512 structures and 1,000 enemies** at
1280 × 720 with a 30 FPS cap on a Linux virtual display using Mesa llvmpipe
software rendering. It grants resources and gives enemies very high health and
low damage; it is deliberately separate from campaign balance.

After the ten-second warmup, sampled FPS averaged **21.08**, with a minimum of
**11**. The final view drew **763 entities**; all 1,000 enemies remained in the
simulation. Mean measured simulation CPU time was **10.33 ms per rendered
frame**, and world draw-command generation averaged **8.23 ms**. These are host
measurements, not physical Android performance figures.

Earlier runs of the same extreme counts averaged 7.07 FPS, then 17.61 FPS after
spatial-target caching, batched ground shadows and native nine-patch UI drawing.
Physical crowd spacing then removed coincident piles of bodies. The earlier
reports are retained rather than claiming all runs rendered identical scenes.
Normal gameplay reached the 30 FPS cap in the initial 65-second soak, which also
performed one actual disk restoration. The long soak shares the host with build
and software-emulator work, so its timing counters include that contention.

## Extended stability run (historical, intentionally interrupted)

The corrected v0.2 run was intentionally stopped when the owner requested the
v0.3 mobile grid and deposit-bound construction changes. It confirmed
**7,251.514 seconds (2 hours, 51.5 seconds)** in one segment, with 119 actual disk
restorations, two campaign sessions, two victory events and no invariant errors.
It did **not** complete its planned four hours and does not certify v0.3.

The earlier pre-wave-correction 18-minute run also remains separate. Raw evidence
for the interrupted corrected run is in
[soak-v0.2-partial.json](verification/frontier/soak-v0.2-partial.json).

## Native Android

The **exact delivered APK hash above** passed **all 28 checks** in one unified
run on a disposable **Android 7/API 24 x86-64** emulator using software ANGLE
(`swangle`), without KVM acceleration. The run took **996.15 real seconds**.
It verified the illustrated menu, real touch placement, stored world coordinates,
advancing and paused clocks, hardware Back, cold restart, camera dragging without
construction, background persistence and successful foreground resumption.
Captured diagnostics contained no script error, shader error or fatal exception.

The second Back/foreground sequence advanced the saved clock from **47.15 to
52.10 seconds** and then held it fixed. This revision's observed native result
is a complete pass, rather than a combination of partial runs. A preliminary
pre-wave-correction APK also passed 28 checks, but that separate hash is not used
to certify the delivered file. See [native report](verification/frontier/native-android.json)
and [actual Android capture](screenshots/v0.2-android.png).

This emulator is intentionally slow; its virtual-device timing is not a
physical-phone performance benchmark. Only the x86-64 runtime was executed here;
ARMv7 and ARM64 were packaged and signing/manifest-checked.

There is no physical handset certification at this stage.

## Gameplay recording

`builds/tabara-frontier-preview.mp4` is a silent 40-second, 1280 × 720 H.264
desktop recording. It was visually reviewed at construction, demolition and
battle stages. It uses a saved normal-cost campaign at 24:12.95, followed by a
30-second normal-cost warmup and ordinary paid construction, upgrade and
demolition. No stress-fixture supplies or enemy statistics are used. The fixture
and reproducible tour helper are in `tests/fixtures/` and
`tests/record_preview.gd`; neither is included in the installed game.

The video's 30 FPS capture rate is a recording setting, not a physical Android
performance measurement.

## Reproduction and packaging

See the README for the model, rendered, soak, stress and native commands.
`tools/verify.py` fails on engine errors even if Godot returns exit code 0.
Raw temporary outputs live in the ignored `test-results/` directory; compact
final reports are copied into `docs/verification/frontier/` for the source ZIP.

The final source ZIP is generated from the final local Git commit, validated for
CRC and required project/art/evidence entries, and checked for excluded private
keys. `builds/FRONTIER_SHA256SUMS.txt` and `builds/FRONTIER_BUILD_INFO.json` identify
all delivered artifacts and their source.
