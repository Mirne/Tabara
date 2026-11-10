"""Real Android APK smoke test on a disposable emulator. Requires adb and Pillow.

ANDROID_ADB selects adb; ANDROID_SERIAL and ANDROID_ADB_PORT select the test
device/server. This script clears ONLY com.tabara.lasthearth on that device.
"""
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "test-results" / "android"
OUT.mkdir(parents=True, exist_ok=True)
ADB = os.environ.get("ANDROID_ADB", "adb")
SERIAL = os.environ.get("ANDROID_SERIAL", "emulator-5554")
PORT = os.environ.get("ANDROID_ADB_PORT", "5037")
PACKAGE = "com.tabara.lasthearth"
checks = []
completed = False
started = time.monotonic()

def adb(*args, timeout=60, binary=False):
    result = subprocess.run([ADB, "-P", PORT, "-s", SERIAL, *args],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            timeout=timeout, check=True)
    return result.stdout if binary else result.stdout.decode().strip()

def check(condition, label):
    checks.append({"label": label, "passed": bool(condition)})
    print(("PASS: " if condition else "FAIL: ") + label, flush=True)
    if not condition:
        raise AssertionError(label)

def capture(name):
    data = adb("exec-out", "screencap", "-p", timeout=90, binary=True)
    check(data.startswith(b"\x89PNG"), "Android screenshot: " + name)
    path = OUT / (name + ".png")
    path.write_bytes(data)
    return path

def tap(x, y):
    adb("shell", "input", "tap", str(round(x * 1280 / 1440)), str(round(y * 720 / 810)))
    time.sleep(3)

def launch():
    result = adb("shell", "am", "start", "-W", "-n", PACKAGE + "/com.godot.game.GodotAppLauncher", timeout=150)
    check("Error" not in result, "Android launcher starts the game")
    time.sleep(12)

def read_save():
    data = adb("shell", "run-as", PACKAGE, "cat", "files/settlement.json")
    return json.loads(data)

try:
    print("Waiting for Android boot and package service...", flush=True)
    deadline = time.monotonic() + 2700
    while time.monotonic() < deadline:
        try:
            if adb("shell", "getprop", "sys.boot_completed", timeout=12) == "1":
                break
        except (subprocess.SubprocessError, OSError):
            pass
        time.sleep(5)
    else:
        raise TimeoutError("Android did not finish booting in 45 minutes")
    check(True, "Android finished booting")
    adb("shell", "wm", "size", "1280x720")
    adb("shell", "wm", "density", "160")
    installed = adb("install", "--no-incremental", "-r", str(ROOT / "builds/tabara-last-hearth.apk"), timeout=240)
    check("Success" in installed, "APK installs on Android")
    adb("shell", "pm", "clear", PACKAGE)
    adb("logcat", "-c")
    launch()
    capture("01-menu")
    tap(220, 520)
    capture("02-briefing")
    tap(770, 635)
    time.sleep(6)
    capture("03-mission")
    tap(220, 747)
    tap(335, 242)
    tap(440, 747)
    tap(817, 217)
    tap(640, 747)
    tap(425, 342)
    tap(192, 198)
    tap(1320, 58)
    capture("04-built-and-paused")
    saved = read_save()
    check(saved["buildings"][1]["kind"] == "wood", "Android touch builds woodcutter")
    check(saved["buildings"][2]["kind"] == "stone", "Android touch builds stonemason")
    check(saved["buildings"][4]["kind"] == "arrow", "Android touch builds arrow tower")
    check(saved["elapsed"] > 0 and saved["wave"] >= 1, "Android mission advances")
    before = saved["elapsed"]
    time.sleep(4)
    check(read_save()["elapsed"] == before, "Android pause freezes mission")
    adb("shell", "am", "force-stop", PACKAGE)
    launch()
    capture("05-continue-menu")
    tap(220, 520)
    time.sleep(3)
    capture("06-restored-settlement")
    adb("shell", "input", "keyevent", "3")  # Home triggers app pause/save.
    time.sleep(3)
    restored = read_save()
    check(restored["elapsed"] >= before, "Android cold restart preserves elapsed time")
    check(restored["buildings"][4]["kind"] == "arrow", "Android cold restart preserves buildings")
    launch()
    capture("07-background-paused")
    log = adb("logcat", "-d", "-v", "brief", timeout=60)
    (OUT / "logcat.txt").write_text(log)
    check("FATAL EXCEPTION" not in log and "SCRIPT ERROR:" not in log, "No Android crash or script error")
    completed = True
finally:
    report = {"actual_seconds": time.monotonic() - started, "checks": checks,
              "passed": completed and all(item["passed"] for item in checks)}
    (OUT / "report.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report), flush=True)
