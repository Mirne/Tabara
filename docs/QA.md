# Woodland Basin v0.7 verification

This revision rebuilds the environment as one woodland basin. Connected pine and
oak canopy belts enclose meadow, the quarry and ridge artwork share mossy grey
limestone, and the eastern forest follows the lake. The unrelated landmark gallery
is absent from new settlements. Actual full-map and play-scale captures were
reviewed; the composition study is not used as a substitute for game screenshots.

## Build identity

Runtime source: `ec493311cb94bfa7568a3874dc3f20e378274df2`.
Godot 4.6.3, app 0.7.0/code 7, save format 6, new terrain revision 3.
ARM64 and x86-64, Android API 24 minimum. Existing saves retain layouts 0–2.

APK: `tabara-frontier-v0.7.apk`, 92,946,314 bytes (88.6 MiB).
SHA-256: `950159db7817c55c61074a113be02b9c1eb61fcb76db013a62200822710832fa`.
Certificate SHA-256: `dbd0f5f2a2a56082d36b733d6467f28dc7dc166e82ffe41d0dc2c2fe42cd6ebb`.
Previous release evidence remains in [QA-v0.6.md](QA-v0.6.md).

Local verification completed with 3,314 model checks, 68 world checks and 119
rendered interface checks, zero failures. Actual movement completed 29 routes
and sampled 7,941 open positions, without a blocked-cell entry or failed arrival.
The [source CI run](https://github.com/Mirne/Tabara/actions/runs/42992139290)
passed on the frozen runtime. Independent [Android 15/API 35 CI](https://github.com/Mirne/Tabara/actions/runs/42992179412)
passed all 37 native checks in 281.878 seconds. Its separately signed CI APK has
SHA-256 `f00b6c211e8df90fe7d6349bf9bc611378ff9ba576c50e811bb787819f5e091b`.
The **exact download APK** passed all **37 native checks** on Android 7/API 24
in 963.572 real seconds. Confirmed structures, three joined wall pieces, pause,
Back, cold restart, camera dragging and app switching passed. Captured Godot
logs contained no script, shader or fatal error. See [native report](verification/woodland-basin/native-android.json)
and the [actual Android wall](screenshots/android-woodland-wall.png).
The local emulator used software CPU emulation with swangle; this is not a phone
performance measurement.

## Map and interaction verification

The terrain suite compares all four cached collision fields with fresh geography
and all four navigation fields with fresh Dijkstra searches. It verifies producer
sites, the western approach, mountain pass, expansion meadow and eastern shore.
Canopy collision comes from source-image alpha analysis followed by the shared
terrain bake. No source PNG is modified by the analysis tool.

The construction and movement masks share the same authoritative cells. Actual
raider walks exercise the movement code around forests, water and rock. Enclosed
logging hollows and small gaps between trees are not all reachable from the Hall;
the playable approach, pass and main meadows are connected. This is a designed
single-entry mission, not a procedurally generated map.

Rendered interface checks cover tap-preview/confirmation, wall dragging and joined
corners, tower range, independent repair and upgrade prices, speed controls, Hall
navigation, pinch, Back and saves. All three normal-cost campaigns reached victory at fifteen minutes and survived the twenty-five-minute cutoff (wave 50), without resource grants.

## Actual update compatibility

The actual **v0.6-to-v0.7 install** passed all **16 checks** in 349.776 seconds.
The published v0.6 APK loaded and wrote its version-five settlement before v0.7
was installed over it. Android retained the complete file. The new app migrated
the save to version six while preserving terrain revision 2, building kinds,
positions and levels, resources, mission time and kills. The disposable device's
woodland fixture was restored afterward. See the [upgrade report](verification/woodland-basin/native-upgrade.json)
and [updated legacy settlement](screenshots/android-woodland-updated-legacy.png).

## APK packaging

`tools/package_android.py` applies lossless ZIP compression to texture containers,
checks every uncompressed payload against the Godot export, aligns the package
for native libraries, then signs with the same development certificate used by
v0.6. Texture pixels and scripts are unchanged by packaging. The source contains
no signing key. Android tests exercise the final repackaged APK.

## Limits

The local Android device and Linux renderer are software emulators. Their speed
does not represent the S23 Ultra. No physical handset was available. This is a
development-signed sideload build. Start a new settlement to see the new terrain;
installing the update preserves the terrain of an existing settlement.
