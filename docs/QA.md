# Stronghold v0.8 verification

## Build identity

Runtime source: `2e86fcbc9016296c8cd77f15eb9fe21c2e95c6bc`.
Godot 4.6.3, app 0.8.0/code 8, save format 7, new terrain revision 4.
ARM64 and x86-64, Android API 24 minimum. Legacy saves retain layouts 0–3.

APK: `tabara-frontier-v0.8.apk`, 95,138,609 bytes (90.7 MiB).
SHA-256: `e1aca8a5c8b7fd36419e04d5c5f86e48eec8809ca070bfb1dde3e45ee85a0ee6`.
Certificate SHA-256: `dbd0f5f2a2a56082d36b733d6467f28dc7dc166e82ffe41d0dc2c2fe42cd6ebb`.
Previous evidence remains in [the v0.7 release](https://github.com/Mirne/Tabara/blob/v0.7.0/docs/QA.md).

## Model, geography and mobile interface

Local verification passed 1,689 model checks, 59 terrain/navigation checks and
93 rendered interface checks with zero failures. Actual movement completed 46
routes and sampled 12,741 positions without a blocked-cell entry or failed arrival.
See [checks](verification/stronghold/checks.log) and [movement traces](verification/stronghold/movement.json).
Independent [source CI](https://github.com/Mirne/Tabara/actions/runs/43248730435)
checks the frozen implementation, including its final briefing text.

All five cached terrain fields equal freshly computed geography; all five cached
navigation fields equal fresh shortest-path searches. Layout four closes isolated
forest hollows and verifies that every ordinary open cell reaches the hall.
All eight resource sites accept their matching producer and refuse duplicate
claims. The outside sites lie west of the pass. Old layouts and their 28 producer
sites remain available to saved settlements.

Model checks exercise global research across current and future buildings,
all eight types through level 100, slower paid research, pause/resume on Workshop
destruction, local timed repair, permanent destruction and foundation reuse,
retaliation through blocking walls, and adjacent attacks on exposed producers.
Elite health lets a fresh elite survive a base cannon shell while the exact
ordinary cannon damage is still applied. No weapon-specific resistance or bonus
is used. Save round trips validate research, repairs and legacy migration.

Rendered controls exercise large catalogue cards, catalogue replacement,
green producer tiles, separate preview/confirmation, joined wall strokes,
Workshop subjects and queue, local repair, pinch, speed controls, pause, saves,
Android-style Back and mission/endless screens. Current screenshots were captured
from the actual game. The catalogue starts with the real budget; the more developed
Workshop/research/elite/outpost visual fixtures explicitly grant supplies and are
not examples of normal-cost campaign balance.

## Difficulty and stability

Three seeded campaigns using paid player orders reached 15-minute victory and
lost at 964.90, 966.05 and 965.60 game seconds, all at wave 33. The bot repairs,
researches, completes a defensive line, and spends surplus on a second wall line
and more towers. It receives no resource grants. This is a small deterministic
sample, not a claim about every player strategy. See [balance evidence](verification/stronghold/balance.json).

A rendered normal-cost soak completed 300.03 confirmed real seconds, with 4 disk save/restores, 12 camera tours and no invariant failures. Long stalls excluded from active time totaled 0.00 seconds. See [soak evidence](verification/stronghold/soak.json).

The extreme fixture actually created 512 structures and 1,000 high-health,
low-damage enemies, with unlimited supplies explicitly labeled. It completed
65.09 real seconds without a script failure, but averaged only 3.86 sampled FPS
on the local software renderer while the Android emulator was running. Mean
simulation CPU time was 106.69 ms and world drawing 36.98 ms. This establishes a
performance limit, not mobile performance certification. See [stress evidence](verification/stronghold/stress.json).

## Android package and compatibility

The **exact download APK** passed all **45 native checks** on Android
7/API 24 in 1265.42 real seconds. The native defender pays normal costs and waits for production and combat gold. Actual touch construction,
green producer tiles, six joined wall sections, timed Workshop research, pause,
Back, cold restart, panning and app switching passed. Captured diagnostics contain
no script, shader or fatal error. See [native report](verification/stronghold/native-android.json),
[Android walls](screenshots/android-stronghold-wall-built.png) and
[Workshop research](screenshots/android-stronghold-workshop-research.png).

Independent [Android 15/API 35 CI](https://github.com/Mirne/Tabara/actions/runs/43248731001)
passed all 45 checks in 360.16 seconds using its separately signed
CI APK, SHA-256 `9fab5d9717c3c30ae366e0c247d534ec99c0d843c7b45be7ee53d161e9d9f4d9`.
See [API 35 report](verification/stronghold/android-api35.json).

The actual **v0.7-to-v0.8 install** passed all **17 checks** in
386.22 seconds. The published v0.7 app restored and wrote a version-six,
layout-three fixture with unequal individual arrow levels. Android retained the
complete file during installation; v0.8 migrated it to version seven, retained
all foundations, economy and mission progress, kept 28 legacy sites, and converted
the highest surviving arrow level to global level three. The eight-site fixture
was restored to the disposable emulator afterward. See [update report](verification/stronghold/native-upgrade.json)
and [updated legacy settlement](screenshots/android-stronghold-updated-legacy.png).

Packaging losslessly compresses texture ZIP entries, checks every uncompressed
payload against the Godot export, aligns native libraries, and signs with the same
development certificate as v0.7. Scripts and texture pixels are unchanged.
See [packaging evidence](verification/stronghold/packaging.log). No signing key
is stored in the repository.

## Limits

No physical handset was available. Local Linux and Android use software rendering
and CPU emulation; their speed does not predict S23 Ultra performance. This is a
development-signed sideload build. Start a new settlement for the eight-site map;
installing as an update preserves existing terrain and foundations. Older
per-building levels migrate to the highest surviving level per type globally;
old destroyed non-hall ruins disappear.
