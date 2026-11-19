# Final Warlord v0.11 verification

## Build identity

Runtime source: `b489e8dae95acd317c1604bddcbf04866ca6a336`.
Godot 4.6.3, app 0.11.0/code 11, save format 10, terrain revision 5.
APK: `tabara-frontier-v0.11.apk`, **104,023,841 bytes** (99.2 MiB).
SHA-256: `aebb450fdcdd2c94cde0d48eee8ba50cbab2eeebee2c427b4ef2775dc9bba650`.
Certificate SHA-256: `dbd0f5f2a2a56082d36b733d6467f28dc7dc166e82ffe41d0dc2c2fe42cd6ebb`.
Packaging preserves every uncompressed export payload and uses the published
v0.10 signing key. See [packaging record](verification/final-warlord/packaging.log).
The [v0.10 evidence](https://github.com/Mirne/Tabara/blob/v0.10.0/docs/QA.md)
remains available through its release tag.

## Source, gameplay and rendering

**1,877 model checks**, **81 terrain/navigation checks**, **46 movement traces /
12,620 sampled positions**, **166 rendered interface checks**, and **85 combat-art
checks** passed with zero failures. [Independent source CI](https://github.com/Mirne/Tabara/actions/runs/44503676499)
passed the frozen runtime. See [checks](verification/final-warlord/checks.log),
[movement](verification/final-warlord/movement.json), and
[CI identity](verification/final-warlord/source-ci.json).

Boss checks cover increasing five-minute tiers, the stronger 15:00 profile,
continued combat at the deadline, the specific final boss's death, surviving Hall,
wrong-boss kills, same-tick Hall loss, population-cap priority, reload without
duplicates, unfinished late legacy saves and already-earned old endless victories.
Corrupt encounter/facing fields are rejected. Ordinary enemy attack cadence and
damage, map layouts 0–5, economy, local/global upgrades and passive Marketplace
behavior retain their existing regression checks.

Rendered tests compare actual left/right walking and attack sprites for all six
combat types, pose changes, foot anchors, source-cell boundaries, reduced motion,
and enemy strikes against walls. The attack showcase uses six level-100 walls
and granted supplies to isolate animation; it is not campaign evidence.
The [direction sheet](screenshots/final-warlord-directions.png),
[wall strikes](screenshots/final-warlord-attacks.png), and
[recovery poses](screenshots/final-warlord-recovery.png) are actual engine captures.
The launcher resources were extracted from the built APK and visually checked.
The menu no longer shows the SINGLE PLAYER / OFFLINE footer.

## Paid campaigns and limits

Three seeded campaigns using the unchanged normal-cost defender bot reached
15:00 but **none killed the final boss**. The Hall fell at **970.60, 982.20 and
984.35 game seconds**, all in wave 33. No supplies were granted. This demonstrates
that the old strategy no longer earns a timed win; it does not establish a winning
strategy or guarantee balance for human players. See [campaign record](verification/final-warlord/balance.json).
No new long-duration rendered soak or extreme-load performance claim is made
for this release.

## Native Android

The **exact signed download APK** passed **34 checks** on Android 7/API 24
in **1,200.31 real seconds**. It installs over published v0.10 without clearing
data, preserves the complete old file during installation, and migrates terrain,
foundations, local/global levels, Regeneration, economy, kills and mission time.
The native final encounter stays active past 15:00 with exactly one stronger
Warlord. Both target-facing attack directions accompany real wall damage, survive
restart without duplicating the final boss, and switch back correctly. A tower
kill opens victory only with the Hall alive; endless survival then advances.
Diagnostics contain no script, shader or fatal error. The pre-fixture migrated
settlement is restored afterward. See [native update report](verification/final-warlord/native-update-and-boss.json).

The attack fixture reinforces existing walls to level 100, disables Regeneration,
and repositions the final boss. The victory fixture lowers its HP to one for an
actual tower kill. No supplies are granted. These isolate animation and transitions;
they are not normal-cost campaign evidence. Two preparatory runs were stopped
for menu changes; one also encountered an Android system dialog. The final run
completed after those interruptions were resolved.

Native captures: [arrival](screenshots/android-final-warlord-arrival.png),
[left attack](screenshots/android-final-warlord-attack-left.png),
[right attack](screenshots/android-final-warlord-attack-right.png), and
[victory](screenshots/android-final-warlord-victory.png).

Independent [Android 15/API 35 CI](https://github.com/Mirne/Tabara/actions/runs/44503676937)
passed **63 checks** in **553.47 real seconds**. It exercises a fresh mission,
paid producers/towers/walls and upgrades, Regeneration, pause, Back, restart,
app switching, the five-minute miniboss, final-boss arrival without a timed win,
an actual tower kill and continued endless survival. This CI APK is separately
signed; its SHA-256 is `a3a2267a0b4a6e840ade9a1a5fcaba02ed84a1ed78b346b4ba275cc8c5ca055a`.
See [API 35 report](verification/final-warlord/android-api35.json) and
[CI identity](verification/final-warlord/android-ci.json).

The fresh mission uses paid orders. Encounter fixtures advance saved clocks to
299.95 and 899.95 seconds; the victory fixture repositions the final boss and
lowers its HP to one for a real tower kill. These fixtures test transitions rather
than normal campaign difficulty. The pre-fixture settlement is restored afterward.

The [native menu capture](screenshots/final-warlord-menu.png) shows the removed
SINGLE PLAYER / OFFLINE footer and the corrected final-boss objective.

## Save compatibility

Existing map layouts, foundations, purchased levels, Regeneration and economy
survive migration. Unfinished settlements use the new final-boss objective.
**Previously completed old endless saves retain their earned victory**; start a
new settlement to experience the revised objective after an old win. Living old
minibosses keep their existing stats and do not become the final boss.

Native verification uses emulators; no physical handset was available. This is
an offline development-signed sideload APK for ARM64/x86-64 and API 24+.
Persistent owner rules and individual behavior specifications are in
[gameplay notes](gameplay/NOTES.md) and [the index](gameplay/INDEX.md).
