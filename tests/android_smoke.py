"""Native Android verification of the frontier revision on a disposable emulator.

Requires adb and Pillow. Clears only com.tabara.lasthearth on the selected test
emulator. ANDROID_APK, ANDROID_ADB, ANDROID_SERIAL, ANDROID_ADB_PORT,
ANDROID_REPORT_NAME, ANDROID_COMMAND_TIMEOUT customize the local setup.
"""
from __future__ import annotations
import base64
import copy
import shlex
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from PIL import Image, ImageChops, ImageStat

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "com.tabara.lasthearth"
APK = Path(os.environ.get("ANDROID_APK", ROOT / "builds/tabara-frontier-v0.9.apk"))
OUT = ROOT / "test-results" / Path(os.environ.get("ANDROID_REPORT_NAME", "android-frontier")).name
ADB = os.environ.get("ANDROID_ADB", "adb")
SERIAL = os.environ.get("ANDROID_SERIAL", "emulator-5554")
PORT = os.environ.get("ANDROID_ADB_PORT", "5037")
TIMEOUT = float(os.environ.get("ANDROID_COMMAND_TIMEOUT", "90"))
TAP_DELAY = float(os.environ.get("ANDROID_TAP_DELAY", "3"))
checks: list[dict] = []
size = (1280, 720)
started = 0.0
reference = Image.open(ROOT / "assets/frontier/menu.png").convert("RGB").resize((1440, 810))
MENU_REGION = (1100, 100, 1390, 570)
with APK.open("rb") as stream:
    APK_SHA256 = hashlib.file_digest(stream, "sha256").hexdigest()

def adb(*args, binary=False, timeout=None):
    result = subprocess.run([ADB, "-P", PORT, "-s", SERIAL, *map(str, args)],
                            capture_output=True, timeout=timeout or TIMEOUT)
    if result.returncode:
        raise RuntimeError(f"adb {args}: " + result.stderr.decode(errors="replace")[-1200:] + result.stdout.decode(errors="replace")[-1200:])
    return result.stdout if binary else result.stdout.decode().strip()

def check(ok, label):
    checks.append({"label": label, "passed": bool(ok)})
    print(("PASS: " if ok else "FAIL: ") + label, flush=True)
    if not ok:
        raise AssertionError(label)

def screen(name=None):
    global size
    data = adb("exec-out", "screencap", "-p", binary=True, timeout=120)
    image = Image.open(io.BytesIO(data)).convert("RGB")
    size = image.size
    if name:
        (OUT / (name + ".png")).write_bytes(data)
    width, height = size
    scale = min(width / 1440, height / 810)
    left = (width - 1440 * scale) / 2
    top = (height - 810 * scale) / 2
    return image.crop((round(left), round(top), round(left + 1440 * scale), round(top + 810 * scale))).resize((1440, 810))

def menu_matches(image):
    diff = ImageStat.Stat(ImageChops.difference(image.crop(MENU_REGION), reference.crop(MENU_REGION)))
    return sum(diff.mean) / 3 < 20

def wait_menu():
    end = time.monotonic() + 300
    while time.monotonic() < end:
        if menu_matches(screen()):
            check(True, "Native menu renders the new illustrated landscape")
            return
        time.sleep(4)
    screen("menu-timeout")
    raise TimeoutError("Native menu did not match the rendered frontier art")

def world_point(x, y):
    # Default mission camera and logical game viewport, before any drag/pinch.
    return round((x - 4840) * .72 + 552), round((y - 2800) * .72 + 447)

def physical(x, y):
    width, height = size
    scale = min(width / 1440, height / 810)
    return round((width - 1440 * scale) / 2 + x * scale), round((height - 810 * scale) / 2 + y * scale)

def tap(x, y):
    adb("shell", "input", "tap", *physical(x, y))
    time.sleep(TAP_DELAY)

def launch():
    result = adb("shell", "am", "start", "-W", "-n", PACKAGE + "/com.godot.game.GodotAppLauncher", timeout=180)
    check("Error" not in result, "Android launcher opens the game")
    time.sleep(10)

def save():
    return json.loads(adb("shell", "run-as", PACKAGE, "cat", "files/frontier-settlement.json"))

def wait_saved_structure(index, kind):
    end = time.monotonic() + 75
    while time.monotonic() < end:
        data = save()
        if len(data["buildings"]) > index and data["buildings"][index] and data["buildings"][index]["kind"] == kind:
            return data
        time.sleep(4)
    raise TimeoutError(f"Missing saved structure {index}: {kind}")

def wait_saved_kind(kind):
    end = time.monotonic() + 75
    while time.monotonic() < end:
        data = save()
        if any(b and b["kind"] == kind for b in data["buildings"]):
            return data
        time.sleep(4)
    raise TimeoutError(f"Missing saved building: {kind}")

def write_save(data):
    # Normal shell protocol works on API 24 as well as modern adbd.
    payload = base64.b64encode(json.dumps(data).encode()).decode("ascii")
    inner = "printf '%s' " + shlex.quote(payload) + " | base64 -d > files/frontier-settlement.json"
    adb("shell", "run-as " + shlex.quote(PACKAGE) + " sh -c " + shlex.quote(inner), timeout=120)
    if save() != data:
        raise RuntimeError("Test fixture transfer did not preserve the complete save")


def wait_supplies(data, required):
    # Called while paused; all supplies come from production and real kills.
    end = time.monotonic() + 900
    while any(data["resources"][kind] < amount for kind, amount in required.items()):
        print("WAITING FOR SUPPLIES:", data["resources"], "game seconds:", data["elapsed"], flush=True)
        if time.monotonic() >= end:
            raise TimeoutError("Native defender did not earn its paid upgrade supplies")
        adb("shell", "input", "keyevent", "4")
        time.sleep(15)
        tap(1338, 43)
        data = save()
    return data


def back_sequence():
    before = save()["elapsed"]
    adb("shell", "input", "keyevent", "4")
    time.sleep(12)
    adb("shell", "input", "keyevent", "4")
    time.sleep(5)
    after = save()["elapsed"]
    print(f"BACK CLOCKS: {before} -> {after}", flush=True)
    check(after > before + 0.01, "Hardware Back resumes the clock before pausing again")
    time.sleep(12)  # Longer than the real-time autosave interval.
    check(save()["elapsed"] == after, "Hardware Back then keeps combat paused")
    windows = adb("shell", "dumpsys", "window", timeout=60)
    check(any(PACKAGE in line for line in windows.splitlines() if "mCurrentFocus" in line), "Back handling retains the native game activity")
    screen("hardware-back-paused")

def native_checks(back_only=False):
    global started
    OUT.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    error = None
    resume_log = os.environ.get("ANDROID_RESUME_WORKSHOP_LOG") if not back_only else None
    prior_segment = None
    try:
        end = time.monotonic() + 1800
        while time.monotonic() < end:
            try:
                if adb("shell", "getprop", "sys.boot_completed", timeout=15) == "1" and adb("shell", "service", "check", "package", timeout=15).endswith(": found"):
                    break
            except (RuntimeError, subprocess.SubprocessError):
                pass
            time.sleep(5)
        else:
            raise TimeoutError("Disposable emulator did not finish booting")
        check(True, "Android boot and package service are ready")
        if not back_only and not resume_log:
            installed = adb("install", "--no-incremental", "-r", APK, timeout=300)
            check("Success" in installed, "Frontier APK installs")
            adb("shell", "pm", "clear", PACKAGE)
            try:
                adb("logcat", "-c")
                adb("shell", "settings", "put", "secure", "immersive_mode_confirmations", "confirmed")
            except RuntimeError as problem:
                print("Optional emulator setup:", str(problem)[:250], flush=True)
        else:
            adb("shell", "am", "force-stop", PACKAGE)
        if resume_log:
            previous = Path(resume_log).read_text()
            if any(line.startswith(("FAIL:", "NATIVE ERROR:")) for line in previous.splitlines()):
                raise RuntimeError("Cannot resume a failed segment")
            labels = [line.removeprefix("PASS: ") for line in previous.splitlines() if line.startswith("PASS: ")]
            if "Native touch constructs an operational Workshop" not in labels:
                raise RuntimeError("The previous segment did not reach an operational Workshop")
            package_path = adb("shell", "pm", "path", PACKAGE).splitlines()[0].removeprefix("package:")
            # API 24 adbd can reject sync/pull stat calls for an existing file;
            # exec-out preserves the actual package bytes without that protocol.
            installed_bytes = adb("exec-out", "cat", package_path, binary=True, timeout=300)
            digest = hashlib.sha256(installed_bytes).hexdigest()
            del installed_bytes
            check(digest == APK_SHA256, "Preserved installed APK exactly matches the signed download")
            checks[:0] = [{"label": label, "passed": True} for label in labels]
            (OUT / "previous-segment.log").write_text(previous)
            prior_segment = {"completed_checks": len(labels),
                             "log_sha256": hashlib.sha256(previous.encode()).hexdigest(),
                             "timing": "Interrupted by environment outage; its active duration was not retained"}
        launch()
        wait_menu()
        screen("01-menu")
        tap(260, 462)
        if not resume_log:
            if not back_only:
                screen("02-briefing")
                tap(805, 650)
                time.sleep(5)
                screen("03-initial-mission")
                # Full-height catalogue; selecting and placing hides it until Build structures.
                tap(1194, 218)
                tap(*world_point(4760, 2440))
                image = screen("03a-green-grid-preview")
                wx, wy = world_point(4760, 2440)
                patch = image.crop((wx-60, wy-60, wx+60, wy+60))
                green = sum(g > r*1.2 and g > b*1.15 and g > 75 for r, g, b in patch.getdata())
                check(green > 400, "Native producer preview renders green buildable tiles")
                tap(1338, 43)
                preview_save = save()
                check(len(preview_save["buildings"]) == 1, "Native preview never constructs before confirmation")
                adb("shell", "input", "keyevent", "4")
                time.sleep(4)
                tap(1194, 218)
                tap(*world_point(4760, 2440))
                tap(1273, 685)
                tap(1273, 763)  # Selected-building panel: Build structures.
                tap(1352, 218)
                tap(*world_point(5480, 3240))
                tap(1273, 685)
                tap(1273, 763)
                tap(1194, 376)
                tap(*world_point(4480, 2760))
                tap(1273, 685)
                # Place another tower directly: no catalogue or building selection.
                tap(*world_point(4640, 2760))
                tap(1273, 685)
                tap(1338, 43)
                before_wall = save()
                check(len(before_wall["buildings"]) == 5, "Native placement constructs two producers and two towers without reopening the tower catalogue")
                before_wall = wait_supplies(before_wall, {"wood": 150, "stone": 330, "gold": 60})
                adb("shell", "input", "keyevent", "4")
                time.sleep(4)
                tap(1352, 376)
                start = world_point(4160, 2400)
                finish = world_point(4160, 3200)
                adb("shell", "input", "swipe", *physical(*start), *physical(*finish), "700")
                time.sleep(4)
                screen("03b-wall-preview")
                tap(1338, 43)
                check(len(save()["buildings"]) == 5, "Native wall drag previews without constructing")
                adb("shell", "input", "keyevent", "4")
                time.sleep(4)
                tap(1352, 376)
                adb("shell", "input", "swipe", *physical(*start), *physical(*finish), "700")
                time.sleep(4)
                tap(1273, 685)
                screen("03c-wall-built")
            tap(1338, 43)  # Explicit known pause.
            screen("04-built-and-paused")
            data = wait_saved_structure(10, "wall")
            check(data["version"] == 8 and data["terrain_revision"] == 5, "Native app writes global research and the new eight-site terrain format")
            for index, kind in [(1, "wood"), (2, "stone"), (3, "arrow"), (4, "arrow")]:
                check(data["buildings"][index]["kind"] == kind, "Native touch constructs " + kind)
                check(len(data["buildings"][index]["pos"]) == 2, "Native save retains " + kind + " world coordinates")
            expected = [(4760,2440),(5480,3240),(4480,2760),(4640,2760)]
            for index, position in enumerate(expected, 1):
                check(tuple(data["buildings"][index]["pos"]) == position, "Native confirmed building follows the grid at " + str(position))
            for index, position in [(5,(4160,2600)),(6,(4160,2680)),(7,(4160,2760)),(8,(4160,2840)),(9,(4160,2920)),(10,(4160,3000))]:
                check(data["buildings"][index]["kind"] == "wall" and tuple(data["buildings"][index]["pos"]) == position, "Native wall stroke creates joined piece at " + str(position))
            check(len(data["deposits"]) == 8, "Native mission contains only eight producer sites")
            check(data["elapsed"] > 0 and data["wave"] >= 1, "Native mission advances")
            before = data["elapsed"]
            time.sleep(12)
            check(save()["elapsed"] == before, "Native pause freezes the saved clock beyond autosave interval")
            back_sequence()
        else:
            tap(*world_point(5200, 2800))
            tap(1338, 43)
            checkpoint = save()
            check(checkpoint["version"] == 8 and checkpoint["terrain_revision"] == 5,
                  "Resumed checkpoint retains the current save format and map")
            check(checkpoint["research_levels"]["arrow"] == 1 and checkpoint["regeneration_level"] == 0,
                  "Resumed checkpoint starts before the remaining paid upgrade tests")
            check(any(b and b["kind"] == "workshop" and b["age"] >= 6 for b in checkpoint["buildings"]),
                  "Resumed checkpoint retains the operational Workshop")
        if not back_only:
            if not resume_log:
                # Add the Workshop using its larger catalogue card and research controls.
                wait_supplies(save(), {"wood": 140, "stone": 100, "gold": 70})
                adb("shell", "input", "keyevent", "4")
                time.sleep(4)
                tap(1273, 692)
                tap(*world_point(5200, 2800))
                tap(1273, 685)
                tap(1273, 763)  # Done building, then explicitly select the Workshop.
                tap(*world_point(5200, 2800))
                end = time.monotonic() + 240
                while True:
                    tap(1338, 43)
                    workshop_save = wait_saved_kind("workshop")
                    if next(b for b in workshop_save["buildings"] if b and b["kind"] == "workshop")["age"] >= 6:
                        break
                    if time.monotonic() >= end:
                        raise TimeoutError("Native Workshop did not finish construction")
                    adb("shell", "input", "keyevent", "4")
                    time.sleep(8)
                check(True, "Native touch constructs an operational Workshop")
            else:
                workshop_save = save()
            workshop_save = wait_supplies(workshop_save, {"wood": 110, "stone": 70, "gold": 40})
            adb("shell", "input", "keyevent", "4")
            time.sleep(4)
            tap(1352, 330)  # Arrow research subject.
            tap(1273, 678)
            tap(1338, 43)
            research_save = save()
            check(research_save["research_levels"]["arrow"] == 2 and any(b and b["kind"] == "arrow" for b in research_save["buildings"]) and all(b["level"] == 2 for b in research_save["buildings"] if b and b["kind"] == "arrow") and "research_job" not in research_save,
                  "Native Workshop upgrades all surviving towers instantly without a queue")
            screen("04b-workshop-research")
            # Regeneration is a paid global upgrade, with no local repair buttons.
            wait_supplies(save(), {"wood": 120, "stone": 90, "gold": 60})
            adb("shell", "input", "keyevent", "4")
            time.sleep(4)
            tap(1273, 173)
            tap(1273, 678)
            tap(1338, 43)
            check(save()["regeneration_level"] == 1, "Native Workshop purchases global automatic Regeneration")
            screen("04c-regeneration")
            retained = save()
            adb("shell", "am", "force-stop", PACKAGE)
            # Isolate restore/lifecycle from legitimate destruction during the
            # subsequent UI waits. Economy, buildings, upgrades and time stay.
            retained["enemies"] = []
            retained["spawn_remaining"] = 0
            retained["spawn_clock"] = 30.0
            write_save(retained)
            launch()
            wait_menu()
            screen("05-continue-menu")
            tap(260, 462)
            time.sleep(6)
            tap(1338, 43)
            restored = save()
            check(restored["elapsed"] >= retained["elapsed"], "Cold restart retains elapsed time")
            signature = lambda rows: [(b["kind"], b["pos"]) if b else None for b in rows]
            check(signature(restored["buildings"]) == signature(retained["buildings"]), "Cold restart retains all confirmed structures and coordinates")
            check(restored["research_levels"]["arrow"] == 2 and restored["regeneration_level"] == 1,
                  "Cold restart retains instant upgrades and automatic Regeneration")
            screen("06-restored-and-paused")
            # Test camera movement with a real drag; this must not construct anything.
            adb("shell", "input", "keyevent", "4")
            time.sleep(4)
            start = physical(700, 350)
            finish = physical(900, 380)
            adb("shell", "input", "swipe", *start, *finish, "650")
            time.sleep(4)
            tap(1338, 43)
            dragged = save()
            check(dragged["camera"][:2] != restored["camera"][:2], "Native one-finger drag moves the camera")
            check(len(dragged["buildings"]) == len(restored["buildings"]), "Native drag creates no accidental building")
            screen("07-panned")
            # Home must save and pause; foreground may recreate the activity.
            adb("shell", "input", "keyevent", "4")
            time.sleep(5)
            adb("shell", "input", "keyevent", "3")
            time.sleep(5)
            backgrounded = save()
            check(backgrounded["elapsed"] >= dragged["elapsed"], "Backgrounding persists the current settlement")
            launch()
            image = screen("08-foreground")
            if menu_matches(image):
                tap(260, 462)
                time.sleep(4)
                tap(1338, 43)
            # Clock resumption is checked again, exposing a stuck emulator surface.
            back_sequence()
        if not back_only:
            # Explicit clock-boundary fixture, not a five-minute real campaign claim.
            # No resources are granted; restore the normal native settlement after.
            normal = save()
            try:
                adb("shell", "am", "force-stop", PACKAGE)
                boundary = copy.deepcopy(normal)
                boundary.update(elapsed=299.95, wave=10, boss_intervals=0,
                                spawn_remaining=0, spawn_clock=1.0, enemies=[], victory_seen=False)
                boundary["camera"] = [500.0, 2700.0, 1.0]
                boundary["buildings"][0]["hp"] = 2100.0
                write_save(boundary)
                launch()
                wait_menu()
                tap(260, 462)
                time.sleep(6)
                tap(1338, 43)
                observed = save()
                bosses = [e for e in observed["enemies"] if e["kind"] == "boss"]
                check(observed["boss_intervals"] == 1 and len(bosses) == 1,
                      "Native five-minute boundary spawns exactly one miniboss at the western entrance")
                check(bosses[0]["pos"][0] < 1200 and bosses[0]["hp"] > 1000,
                      "Native miniboss has its own stronger stats and starts on the approach")
                check(observed["buildings"][0]["hp"] > 2100,
                      "Native Regeneration heals the damaged Hall without a repair tap")
                screen("09-miniboss-and-regeneration")
            finally:
                adb("shell", "am", "force-stop", PACKAGE)
                write_save(normal)
        log = adb("logcat", "-d", "-t", "500", "-v", "brief", timeout=90)
        (OUT / "logcat.txt").write_text(log)
        check(not any(text in log for text in ["FATAL EXCEPTION", "SCRIPT ERROR:", "SHADER ERROR:", "Shader compilation failed"]), "Captured native diagnostics contain no script, shader, or fatal error")
    except BaseException as problem:
        error = str(problem)
        print("NATIVE ERROR:", error, flush=True)
        try:
            diagnostic = save()
            (OUT / "failed-save.json").write_text(json.dumps(diagnostic, indent=2))
            print("FAILED STATE:", {key: diagnostic.get(key) for key in
                  ["elapsed", "resources", "research_levels", "regeneration_level", "boss_intervals"]}, flush=True)
            screen("failed-state")
        except Exception:
            pass
    finally:
        try:
            log = adb("logcat", "-d", "-t", "500", "-v", "brief", timeout=90)
            (OUT / "logcat.txt").write_text(log)
        except Exception as problem:
            print("Diagnostic capture unavailable:", str(problem)[:250], flush=True)
        report = {"passed": error is None and bool(checks) and all(c["passed"] for c in checks),
                  "error": error, "checks": checks, "actual_seconds": time.monotonic() - started,
                  "apk_sha256": APK_SHA256, "mode": "foreground-back" if back_only else ("resumed-native" if resume_log else "full-native"),
                  "prior_segment": prior_segment,
                  "fixtures": "Restore/lifecycle checks clear incoming attackers after paid construction. The miniboss check advances a saved clock to 299.95 seconds and damages the Hall. Neither fixture grants resources; the miniboss check restores the original native settlement" if not back_only else "existing settlement"}
        (OUT / "report.json").write_text(json.dumps(report, indent=2))
        print(json.dumps(report), flush=True)
    return 0 if report["passed"] else 1

if __name__ == "__main__":
    sys.exit(native_checks())
