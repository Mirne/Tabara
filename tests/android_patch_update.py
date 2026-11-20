"""Exercise the signed v0.13.0 → v0.13.1 update on a disposable rooted AOSP emulator.

The public v0.13.0 app pays for the entire opening through native taps. No save
fixture or extra resources are used. The test retains any preexisting game save.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import time
from PIL import ImageChops, ImageStat

import android_smoke as device

PREVIOUS = Path(os.environ.get("ANDROID_PREVIOUS_APK", device.ROOT / "builds/tabara-frontier-v0.13.apk"))
V013_DIGEST = "aa4fb07bdac02c3c328db720a32e5583e9da88c4a200a0c5639b61f0822ec8d5"
HALL = (1194, 43)
PAUSE = (1338, 43)
BUY = (1273, 678)
CATALOGUE = (1273, 763)
YARDS = {"wood": (4800, 2480), "stone": (4680, 3120)}
WORKSHOP = (5200, 2800)


def stop():
    device.adb("shell", "am", "force-stop", device.PACKAGE)


def install(apk, expected):
    result = device.adb("install", "--no-incremental", "-r", "-d", apk, timeout=360)
    device.check("Success" in result, f"Android accepts the signed {expected} APK")
    package = device.adb("shell", "dumpsys", "package", device.PACKAGE)
    device.check(re.search(r"\bversionName=" + re.escape(expected) + r"(?:\s|$)", package) is not None,
                 f"The installed package reports version {expected}")


def show_menu():
    device.launch()
    device.wait_menu()


def building(data, kind):
    return next(b for b in data["buildings"] if b and b["kind"] == kind)


def build(card, position, camera):
    device.tap(*card)
    device.tap(*device.world_point(*position, camera))
    device.tap(1273, 685)


def foundation_signature(data):
    return [(b["kind"], b["pos"], b["level"], b.get("wall_size")) if b else None
            for b in data["buildings"]]


def paid_opening():
    show_menu()
    device.tap(260, 462)  # Fresh settlement
    device.tap(805, 650)  # Establish a settlement
    opening = device.save()
    camera = opening["camera"]
    build((1194, 218), YARDS["wood"], camera)
    build((1352, 218), YARDS["stone"], camera)
    build((1273, 692), WORKSHOP, camera)
    device.tap(*CATALOGUE)
    device.tap(*HALL)
    device.tap(*BUY)  # Actual Stone age advancement
    device.tap(*PAUSE)
    stone = device.save()
    device.check(stone["settlement_age"] == 2 and stone["version"] == 12,
                 "The original APK advanced to Stone with supplies earned in game")
    for kind, pos in YARDS.items():
        device.check(tuple(building(stone, kind)["pos"]) == pos, f"The original APK built its one {kind} yard")

    # The Workshop takes six game seconds. Check construction while paused so
    # captures and variable emulator speed do not steal time from the settlement.
    deadline = time.monotonic() + 90
    while building(stone, "workshop")["age"] < 6:
        if time.monotonic() >= deadline:
            raise TimeoutError("The original Workshop did not finish construction")
        device.resume_with_touch()
        time.sleep(7)
        device.tap(*PAUSE)
        stone = device.save()
    stone = device.wait_supplies(stone, {"wood": 105, "stone": 60, "gold": 35})
    device.resume_with_touch()
    time.sleep(device.TAP_DELAY)
    device.tap(*CATALOGUE)
    device.tap(*device.world_point(*WORKSHOP, stone["camera"]))
    device.tap(1194, 250)  # Archery in v0.13.0
    device.tap(*BUY)      # Arrowheads rank two
    device.tap(*CATALOGUE)
    device.tap(1194, 218)  # Select the standing woodcutter, recentering the camera
    device.tap(1273, 584)  # Local level two
    device.tap(*PAUSE)
    paid = device.save()
    device.check(paid["tower_tracks"]["arrow_damage"] == 2, "The public v0.13.0 Workshop bought Arrowheads rank two")
    device.check(building(paid, "wood")["level"] == 2, "The public v0.13.0 woodcutter bought its second level")
    device.check(paid["camera"] != camera, "Selecting the paid woodcutter saved a nondefault view")
    return paid


def run():
    started = time.monotonic()
    device.OUT.mkdir(parents=True, exist_ok=True)
    original = None
    error = None
    paid = {}
    try:
        device.check(device.ROOTED_EMULATOR, "Release APK save inspection uses a disposable rooted emulator")
        with PREVIOUS.open("rb") as apk:
            old_digest = hashlib.file_digest(apk, "sha256").hexdigest()
        device.check(old_digest == V013_DIGEST,
                     "Upgrade starts with the exact public v0.13.0 APK")
        stop()
        if device.adb("shell", f"if test -f {device.SAVE_FILE}; then echo present; fi") == "present":
            original = device.adb("exec-out", "cat", device.SAVE_FILE, binary=True)
            device.adb("shell", "rm", device.SAVE_FILE)
        install(PREVIOUS, "0.13.0")
        paid = paid_opening()
        stop()
        prior_bytes = device.adb("exec-out", "cat", device.SAVE_FILE, binary=True)
        before = json.loads(prior_bytes)
        device.check(foundation_signature(before) == foundation_signature(paid),
                     "The old app closed with every paid foundation intact")
        install(device.APK, "0.13.1")
        package_path = device.adb("shell", "pm", "path", device.PACKAGE).splitlines()[0].removeprefix("package:")
        installed_digest = hashlib.sha256(device.adb("exec-out", "cat", package_path, binary=True, timeout=300)).hexdigest()
        device.check(installed_digest == device.APK_SHA256, "The installed patch matches the downloadable file byte for byte")
        device.check(device.adb("exec-out", "cat", device.SAVE_FILE, binary=True) == prior_bytes,
                     "Installing v0.13.1 preserves every byte of the v0.13.0 save")

        device.adb("logcat", "-c")
        show_menu()
        device.tap(260, 462)  # Continue the paid Stone settlement
        device.tap(*PAUSE)
        restored = device.save()
        device.check(restored["version"] == 12 and restored["settlement_age"] == 2
                     and restored["terrain_revision"] == 6, "The updated app resumed Stone on its original terrain")
        device.check(restored["camera"] == before["camera"], "Cold launch restored the player’s exact camera")
        device.check(restored["tower_tracks"] == before["tower_tracks"], "All six Workshop research ranks survived")
        device.check(all(restored["resources"][kind] >= stock for kind, stock in before["resources"].items()),
                     "Resuming the settlement retained its earned wood, stone and gold")
        device.check(restored["deposits"] == before["deposits"] and
                     foundation_signature(restored) == foundation_signature(before),
                     "Cold launch retained both yards and every paid foundation, position and local level")
        device.resume_with_touch()
        time.sleep(device.TAP_DELAY)
        device.tap(*HALL)
        device.screen("01-stone-hall")
        device.tap(*CATALOGUE)
        hall_view = [*building(restored, "hall")["pos"], restored["camera"][2]]
        device.tap(*device.world_point(*WORKSHOP, hall_view))
        arrow_panel = device.screen()
        device.tap(1352, 246)  # Cannon projects in v0.13.1
        device.tap(1273, 480)  # Burst shells
        cannon_panel = device.screen("02-stone-workshop")
        project_cards = (1120, 350, 1426, 600)
        changed = ImageChops.difference(arrow_panel.crop(project_cards), cannon_panel.crop(project_cards))
        device.check(sum(ImageStat.Stat(changed).mean) / 3 > 2,
                     "Touching Cannon and Burst shells changes the research project cards")
        device.tap(1273, 555)  # Loading crew unlocks at Iron
        device.screen("03-stone-locked-loading-crew")
        device.tap(*PAUSE)
        upgrade_result = device.save()
        device.check(upgrade_result["elapsed"] > restored["elapsed"] and not upgrade_result["victory"],
                     "The upgraded settlement continued its live battle")
        log = device.adb("logcat", "-d", "-t", "2000", "-v", "brief")
        (device.OUT / "logcat.txt").write_text(log)
        device.check(not any(flag in log for flag in ("FATAL EXCEPTION", "SCRIPT ERROR:", "Shader compilation failed")),
                     "The native patch session has no fatal, script or shader diagnostic")
    except Exception as exc:
        error = str(exc)
        print("PATCH ERROR:", error, flush=True)
        try:
            device.screen("failed-state")
        except Exception:
            pass
    finally:
        if original is not None:
            try:
                stop()
                device.write_save(original)
            except Exception as exc:
                error = error or str(exc)
    report = {"passed": error is None, "error": error, "checks": device.checks,
              "seconds": round(time.monotonic()-started, 2), "apk_sha256": device.APK_SHA256,
              "previous_apk_sha256": V013_DIGEST, "funding": "Fresh game, in-app purchases at normal prices",
              "paid_age": paid.get("settlement_age"), "paid_camera": paid.get("camera"),
              "paid_resources": paid.get("resources"),
              "paid_research": paid.get("tower_tracks"), "paid_foundations": foundation_signature(paid) if paid else []}
    (device.OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report), flush=True)
    return int(error is not None)


if __name__ == "__main__":
    raise SystemExit(run())
