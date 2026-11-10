# Tabara: Last Hearth

An offline, landscape Android settlement-defense game built with **Godot 4.6.3**.
Build Pinewatch, gather supplies, and defend its single road. Survive **15 in-game
minutes** to win the first mission, then continue against endless escalating waves.

![Pinewatch gameplay](docs/screenshots/gameplay.png)

## Play

Open `project.godot` in Godot 4.6.3 and press **F6/F5**, or install the test APK
from the build output. Android 7.0/API 24 or later with OpenGL ES 3.0 is required.
The build has no advertising, analytics, accounts, purchases, or runtime network
requirement. The game is in English.

1. Start the mission from the main menu. Enemies enter the western road immediately.
2. Tap the round resource caches to gather **wood, stone, and gold**. Caches refill
   every 12 seconds. The main hall supplies a modest passive income.
3. Select a building in the bottom bar, then tap an empty plot. You can also
   select a plot first. Walls can only occupy the two road checkpoints.
4. Select a building to **upgrade** or **repair** it. Every building supports
   levels **1–100**, with scaled health, attacks, or production and rising costs.
5. Keep the main hall standing until **15:00**. Choose **Continue in endless
   survival** after victory. Losing the hall ends the run.

The game saves every 10 seconds, when paused, and when you return to the menu.
Switching apps pauses gameplay. **Continue settlement** restores the current run.
Starting over requires confirmation while a live save exists. Best survival time
and settings persist across runs.

### Buildings

| Building | Role |
| --- | --- |
| Main hall | Starts built; automatically attacks enemies and anchors the settlement |
| Woodcutter | Produces wood; +25% production on the pine-grove plot |
| Stonemason | Produces stone; +25% production on the quarry plot |
| Arrow tower | Fast single-target arrows |
| Wall | Stops enemies at a road checkpoint until ruined |
| Cannon tower | Slow shells that damage all enemies in the blast area |
| Marketplace | Produces gold; buy supplies or sell surplus wood and stone |

Ruined buildings retain their plot and upgrade level. They stop operating until
repaired. Repairs restore full health and cost wood and stone; you can repair
during combat. A ruined main hall ends the mission rather than disappearing.

New waves begin every 30 seconds. Raiders are followed by fast runners, armored
brutes, and occasional siege engines. Siege engines can bombard buildings from
farther along the same road. Enemy health, damage, and numbers increase over time.

### Controls

Android: tap to interact; system Back cancels construction or opens/closes pause.
Desktop: mouse; **1–6** choose buildings, **U** upgrades, **R** repairs,
**Space** pauses/resumes, and **Esc** goes back. The **1×/2×** button changes game
speed. Victory uses in-game time. Music, effects, and reduced motion are configurable.

## Build Android

Install Godot **4.6.3** and its matching export templates. Install an Android SDK
with platform-tools and **build-tools 36.0.0**; use OpenJDK 17 or 21. Configure
the SDK and Java directories in Godot's **Editor Settings → Export → Android**.
Enable ETC2/ASTC texture imports (already set in `project.godot`).

```sh
godot --headless --editor --path . --import --quit
mkdir -p builds
godot --headless --path . --export-debug Android builds/tabara-last-hearth.apk
```

The Android preset includes ARMv7, ARM64, and x86-64. Debug exports use a local
development signing key, which is intentionally excluded from source control.
For a Play Store release, configure your own release keystore and a Gradle AAB
export. No production signing key is included in this repository.

A Linux preset is also included for local testing:

```sh
godot --headless --path . --export-release Linux builds/tabara-last-hearth.x86_64
```

## Verify

```sh
# Economy, construction, combat, level 100, repair, saves, victory, and campaign.
godot --headless --path . --script res://tests/test_simulation.gd

# Actual rendered menus and pointer interactions; needs a graphical display.
mkdir -p test-results
godot --path . --script res://tests/test_ui.gd

# Six actual hours of rendered gameplay, normal-cost bot actions, autosaves,
# repeated cold restores, pause/settings cycles, and bounded-state checks.
godot --path . --max-fps 30 --script res://tests/soak.gd -- --seconds=21600
```

Use a separate Godot user-data directory for automated UI/soak tests: they start
and save test settlements. On Linux, set `XDG_DATA_HOME` to a temporary directory.
The soak report is written to `test-results/soak.json`, which is excluded from
exports and Git. A short smoke run can use `--seconds=65`.

After an infrastructure interruption, pass `--resume` with the same report name
and user-data directory. The harness restores the saved settlement and counts
only previously confirmed running time plus the new segment. Its report records
the segment count and excludes downtime.

`python3 tools/verify.py --ui` runs syntax, simulation, and rendered checks and
fails on engine script errors even if the engine returns a zero exit code.
The GitHub verification workflow runs this suite and retains screenshots.

`tests/android_smoke.py` installs the APK on a disposable emulator and checks
native launcher startup, real touch construction, pause, app switching, and
cold save restoration. Set `ANDROID_ADB`, `ANDROID_SERIAL`, and
`ANDROID_ADB_PORT` if needed. It clears the game's data on that test device.
The manually triggered **Verify native Android** workflow builds and exercises
the APK on a hardware-accelerated Android 15 emulator and prints the check report.

## Project structure

- `scripts/simulation.gd`: deterministic settlement model, waves, combat, economy,
  progression, validation, and versioned snapshots.
- `scripts/game.gd`: animated 2.5D canvas, touch/mouse controls, all screens, audio,
  atomic local saves, lifecycle handling, and settings.
- `assets/art/buildings.png`: original image-generated isometric sprite atlas.
- `assets/audio/`: original synthesized sound effects and a looping ambient track.
- `tests/`: simulation, rendered UI, fair-cost player bot, and stability harness.
- `tools/generate_audio.py`: reproducible audio synthesis; uses Python and FFmpeg.

See [asset credits](docs/ASSETS.md) and [design/balance notes](docs/DESIGN.md).
