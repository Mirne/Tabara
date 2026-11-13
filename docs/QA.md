# Building rules v0.10 verification

## Build identity

Runtime source: `77fe2ab8458ea0f7b70c7a199e3547cfc14b80ff`.
Godot 4.6.3, app 0.10.0/code 10, save format 9, terrain revision 5.
APK: `tabara-frontier-v0.10.apk`, **96,105,778 bytes** (91.7 MiB).
SHA-256: `2895f181a5a705c4c053c4db769418e110b6457002a9adb032b3b1a0f4ce5844`.
Certificate SHA-256: `dbd0f5f2a2a56082d36b733d6467f28dc7dc166e82ffe41d0dc2c2fe42cd6ebb`.
Packaging preserves every uncompressed export payload and uses the v0.9 signing
key. See [packaging record](verification/building-rules/packaging.log).
The previous [v0.9 evidence](https://github.com/Mirne/Tabara/blob/v0.9.0/docs/QA.md)
remains available through its release tag.

## Source, gameplay and rendering

**1,830 model checks**, **81 terrain/navigation checks**, **46 movement traces /
12,620 sampled positions**, and **164 rendered interface checks** passed with
zero failures. [Independent source CI](https://github.com/Mirne/Tabara/actions/runs/43433625802)
passed the frozen runtime. See [checks](verification/building-rules/checks.log),
[movement](verification/building-rules/movement.json), and
[CI identity](verification/building-rules/source-ci.json).

Tests purchase all local and global levels through 100. They verify independent
producer levels, exact local payment, preserved damage fractions, level-one
replacements, and mixed-level save/load. An old format-eight producer retains
its purchased level while future producers start at one. Defense levels still
apply globally. Old paid research/repair migration remains checked.

Marketplace tests verify no output during construction, restored two-gold base
output, increased passive income after local upgrades, and actual gold credited
over time. Buy/sell methods, controls and cooldown storage are removed.
Regeneration keeps its 0.3% starting rate and reaches exactly 20% maximum HP/sec
at level 100. It does not resurrect destroyed buildings or heal construction.

Every one of the four outside resource sites is approached and attacked from
longer range without crossing blocked terrain. Destroying one outpost permits
retargeting to another; a firing defense can interrupt producer aggro.
Existing movement, defense retaliation, wall collision, miniboss boundaries and
fifteen-minute/endless rules remain checked. No other combat stats or map sites
are changed.

The rendered tests check local upgrade controls, the **Upgrade** caption, removal
of the separate Regen tab, defense-only Workshop subjects, passive Marketplace
upgrades, and absence of the construction tutorial toast. Sixteen equal-depth
entity additions leave the quarry/rock image region byte-identical. Repeated
construction, red-cell wall filtering, dense wall joins, camera, pause, Back,
and disk restoration also pass.

[Workshop](screenshots/building-rules-workshop.png),
[producer](screenshots/building-rules-producer.png),
[Marketplace](screenshots/building-rules-marketplace.png), and
[Regeneration](screenshots/building-rules-regeneration.png) are actual engine
captures. These UI fixtures grant supplies; they are not paid-order campaigns.
The [layering fixture](screenshots/building-rules-quarry-layering.png) deliberately
stacks unrelated same-depth towers outside the compared quarry region.

## Paid campaigns and rendered stability

Three seeded paid-order defender campaigns reached the fifteen-minute victory,
then fell at **987.05, 984.75 and 987.85 game seconds**, all in wave 33. No supplies
were granted. This is one tested strategy, not a guarantee for every player.
See [campaign record](verification/building-rules/balance.json).

A rendered run completed **120.024 real seconds**, two disk restores and five
camera tours with no invariant failures. See [soak](verification/building-rules/soak.json).
This run checks the changed early economy/targeting and save restoration; no
extreme-load or physical-phone performance claim is made.

## Native Android and version update

The **exact signed download APK** passed **27 checks** on Android
7/API 24 in 1058.40 real seconds. This includes installing the
published v0.9 APK, loading its old global-level fixture, updating without clearing
data, preserving the complete old file during installation, and migrating its map,
foundations, economy, levels and mission progress. Actual native input buys a local
producer upgrade, constructs another level-one producer, builds/upgrades the
passive Marketplace, measures its credited gold, purchases Regeneration from the
shared Upgrades list, and verifies a cold restart. See [native evidence](verification/building-rules/native-update-and-ui.json).

Independent [Android 15/API 35 CI](https://github.com/Mirne/Tabara/actions/runs/43434924935) passed
**55 checks** in 505.57 seconds. It exercises a fresh
mission, actual paid producers/towers, six-section red-endpoint wall dragging,
local upgrading before a Workshop exists, global defense upgrading, Regeneration,
Back, restart, app switching, and the five-minute miniboss fixture. This CI APK is
separately signed; its SHA-256 is `4802c5305c2ac497ca56a80271decf8e32e367ae201da1994720c3e13d3d161b`.
See [API 35 report](verification/building-rules/android-api35.json) and [CI identity](verification/building-rules/android-ci.json).


The native update fixture writes old global levels and a nonzero trade cooldown
using the published v0.9 app. Migration keeps its economy, map, foundations,
levels, kills and mission progress. Subsequent native UI checks explicitly grant
1,000 of each resource and clear attackers to inspect the changed controls.
They restore the migrated pre-grant settlement afterward. These checks are not
normal-cost campaign evidence.

The fresh Android mission tests use paid orders. Their lifecycle fixture clears
incoming attackers after construction to separate persistence from legitimate
combat destruction. The five-minute miniboss check uses a saved clock at 299.95
seconds and a damaged Hall; it restores the prior settlement afterward.

Native screenshots: [producer](screenshots/android-building-rules-local-producer.png), [Marketplace](screenshots/android-building-rules-passive-marketplace.png), and [Workshop](screenshots/android-building-rules-regeneration-in-upgrades.png).

## Scope and limits

No new settlement is required for v0.10. Existing buildings retain their levels;
new non-defense replacements begin at one. Existing defense levels and
Regeneration remain purchased. Terrain layouts 0–5 retain their geography.

Native verification uses emulators; no physical handset was available. This is
an offline development-signed sideload APK for ARM64/x86-64 and API 24+.
Persistent owner rules and individual behavior specifications are in
[gameplay notes](gameplay/NOTES.md) and [the index](gameplay/INDEX.md).
