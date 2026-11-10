"""Real Android APK smoke test on a disposable emulator. Requires adb and Pillow.

ANDROID_ADB selects adb; ANDROID_SERIAL and ANDROID_ADB_PORT select the test
device/server. This script clears ONLY com.tabara.lasthearth on that device.
"""
import json
import io
import os
from pathlib import Path
import subprocess
import time
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "test-results" / Path(os.environ.get("ANDROID_REPORT_NAME", "android")).name
OUT.mkdir(parents=True, exist_ok=True)
ADB = os.environ.get("ANDROID_ADB", "adb")
SERIAL = os.environ.get("ANDROID_SERIAL", "emulator-5554")
PORT = os.environ.get("ANDROID_ADB_PORT", "5037")
PACKAGE = "com.tabara.lasthearth"
checks = []
completed = False
started = time.monotonic()
screen_size = (1280, 720)

def adb(*args, timeout=60, binary=False):
    result = subprocess.run([ADB, "-P", PORT, "-s", SERIAL, *args],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"adb {args}: {result.returncode}: " + result.stdout.decode(errors="replace")[-2000:] + result.stderr.decode(errors="replace")[-2000:])
    return result.stdout if binary else result.stdout.decode().strip()

def check(condition, label):
    checks.append({"label": label, "passed": bool(condition)})
    print(("PASS: " if condition else "FAIL: ") + label, flush=True)
    if not condition:
        raise AssertionError(label)

def capture(name):
    global screen_size
    data = adb("exec-out", "screencap", "-p", timeout=90, binary=True)
    check(data.startswith(b"\x89PNG"), "Android screenshot: " + name)
    path = OUT / (name + ".png")
    path.write_bytes(data)
    screen_size = Image.open(io.BytesIO(data)).size
    return path

def tap(x, y):
    width, height = screen_size
    scale = min(width / 1440, height / 810)
    px = (width - 1440 * scale) / 2 + x * scale
    py = (height - 810 * scale) / 2 + y * scale
    adb("shell", "input", "tap", str(round(px)), str(round(py)))
    time.sleep(3)

def launch():
    result = adb("shell", "am", "start", "-W", "-n", PACKAGE + "/com.godot.game.GodotAppLauncher", timeout=150)
    check("Error" not in result, "Android launcher starts the game")
    time.sleep(12)

def read_save():
    data = adb("shell", "run-as", PACKAGE, "cat", "files/settlement.json")
    return json.loads(data)

def wait_menu():
    global screen_size
    deadline = time.monotonic() + 150
    while time.monotonic() < deadline:
        data = adb("exec-out", "screencap", "-p", timeout=90, binary=True)
        image = Image.open(io.BytesIO(data)).convert("RGB")
        screen_size = image.size
        width, height = screen_size
        scale = min(width / 1440, height / 810)
        x = round((width - 1440 * scale) / 2 + 46 * scale)
        y = round((height - 810 * scale) / 2 + 52 * scale)
        red, green, blue = image.getpixel((x, y))
        if red > 150 and green > 100 and blue < 150:
            check(True, "Android renders the main menu")
            return
        time.sleep(5)
    check(False, "Android renders the main menu")

try:
    print("Waiting for Android boot and package service...", flush=True)
    deadline = time.monotonic() + 2700
    while time.monotonic() < deadline:
        try:
            booted = adb("shell", "getprop", "sys.boot_completed", timeout=12) == "1"
            package_ready = adb("shell", "service", "check", "package", timeout=12).endswith(": found")
            if booted and package_ready:
                break
        except (subprocess.SubprocessError, OSError, RuntimeError):
            pass
        time.sleep(5)
    else:
        raise TimeoutError("Android did not finish booting in 45 minutes")
    check(True, "Android finished booting")
    installed = ""
    for attempt in range(3):
        try:
            installed = adb("install", "--no-incremental", "-r", str(ROOT / "builds/tabara-last-hearth.apk"), timeout=240)
            break
        except RuntimeError as error:
            transient = any(message in str(error) for message in ["Can't find service: package", "PackageManagerInternal", "DeadObjectException"])
            if not transient or attempt == 2:
                raise
            print("Android package service restarted; waiting before retrying installation.", flush=True)
            time.sleep(10)
    check("Success" in installed, "APK installs on Android")
    adb("shell", "pm", "clear", PACKAGE)
    adb("logcat", "-c")
    launch()
    wait_menu()
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
    wait_menu()
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
