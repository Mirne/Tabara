"""Real Android APK smoke test on a disposable emulator. Requires adb and Pillow.

ANDROID_ADB selects adb; ANDROID_SERIAL and ANDROID_ADB_PORT select the test
device/server. This script clears ONLY com.tabara.lasthearth on that device.
"""
import json
import io
import hashlib
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
    (OUT / "menu-not-ready.png").write_bytes(data)
    print(f"Menu probe: screen={screen_size}, point={(x, y)}, color={(red, green, blue)}", flush=True)
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
    if os.environ.get("ANDROID_REUSE_INSTALLED") == "1":
        apk_path = adb("shell", "pm", "path", PACKAGE).splitlines()[0].removeprefix("package:")
        # Older Android images do not provide a sha256sum command.
        device_hash = hashlib.sha256(adb("exec-out", "cat", apk_path, timeout=240, binary=True)).hexdigest()
        with (ROOT / "builds/tabara-last-hearth.apk").open("rb") as source:
            local_hash = hashlib.file_digest(source, "sha256").hexdigest()
        check(device_hash == local_hash, "Installed Android APK matches build SHA-256")
    else:
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
    try:
        adb("logcat", "-c")
    except RuntimeError as error:
        print("Could not clear the device diagnostic log:", str(error)[:300], flush=True)
    try:
        adb("shell", "settings", "put", "secure", "immersive_mode_confirmations", "confirmed")
    except RuntimeError as error:
        print("Could not pre-confirm the system fullscreen tip:", str(error)[:300], flush=True)
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
    background_image = Image.open(capture("07-background-paused")).convert("RGB")
    width, height = background_image.size
    scale = min(width / 1440, height / 810)
    red, green, blue = background_image.getpixel((round((width-1440*scale)/2+46*scale), round((height-810*scale)/2+52*scale)))
    if red>150 and green>100 and blue<150:
        # Android may recreate a background activity. Continue the saved mission.
        tap(220,520)
    pause_image = Image.open(capture("07-before-back-check")).convert("RGB")
    width, height = pause_image.size
    scale = min(width / 1440, height / 810)
    panel_color = pause_image.getpixel((round((width-1440*scale)/2+450*scale), round((height-810*scale)/2+170*scale)))
    if not (panel_color[0]>180 and panel_color[1]>170):
        tap(1320,58)
    pause_image = Image.open(capture("07-known-pause")).convert("RGB")
    panel_color = pause_image.getpixel((round((width-1440*scale)/2+450*scale), round((height-810*scale)/2+170*scale)))
    check(panel_color[0]>180 and panel_color[1]>170, "Android Back test starts at the pause panel")
    before_back = read_save()["elapsed"]
    adb("shell", "input", "keyevent", "4")  # Back resumes the paused mission.
    time.sleep(5)
    adb("shell", "input", "keyevent", "4")  # Back pauses it again.
    time.sleep(2)
    windows = adb("shell", "dumpsys", "window")
    focused = [line for line in windows.splitlines() if "mCurrentFocus" in line]
    check(any(PACKAGE in line for line in focused), "Android Back keeps the game open while pausing or resuming")
    paused_time = read_save()["elapsed"]
    deadline = time.monotonic()+15
    while paused_time<=before_back+.1 and time.monotonic()<deadline:
        time.sleep(1)
        paused_time = read_save()["elapsed"]
    print(f"BACK CLOCKS: before={before_back}, after={paused_time}", flush=True)
    check(paused_time > before_back + .1, "Android Back resumes combat before pausing again")
    time.sleep(3)
    check(read_save()["elapsed"] == paused_time, "Android Back pauses combat")
    capture("08-hardware-back-paused")
    log = adb("logcat", "-d", "-t", "500", "-v", "brief", timeout=60)
    (OUT / "logcat.txt").write_text(log)
    check("FATAL EXCEPTION" not in log and "SCRIPT ERROR:" not in log, "No Android crash or script error")
    completed = True
finally:
    try:
        log = adb("logcat", "-d", "-t", "500", "-v", "brief", timeout=60)
        (OUT / "logcat.txt").write_text(log)
        relevant = [line for line in log.splitlines() if any(word in line.lower() for word in ["godot", "fatal", "script error", "com.tabara", "exception"])]
        print("NATIVE DIAGNOSTICS", flush=True)
        for line in relevant[-100:]:
            print(line[:800], flush=True)
        windows = adb("shell", "dumpsys", "window", timeout=30)
        for line in windows.splitlines():
            if "mCurrentFocus" in line or "mFocusedApp" in line:
                print(line.strip(), flush=True)
    except Exception as error:
        print("Diagnostics unavailable:", str(error)[:500], flush=True)
    report = {"actual_seconds": time.monotonic() - started, "checks": checks,
              "passed": completed and all(item["passed"] for item in checks)}
    (OUT / "report.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report), flush=True)
