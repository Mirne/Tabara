"""Verify an actual v0.5 -> v0.6 Android update on the disposable emulator.

Run after android_smoke.py. Requires ANDROID_PREVIOUS_APK and ANDROID_BASE_REPORT;
uses the same adb/device/report variables as android_smoke.py. It replaces only
com.tabara.lasthearth on that test emulator and never clears app data.
"""
from __future__ import annotations
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import android_smoke as native

PREVIOUS = Path(os.environ['ANDROID_PREVIOUS_APK'])
BASE_REPORT = Path(os.environ['ANDROID_BASE_REPORT'])

def write_save(data):
    result = subprocess.run(
        [native.ADB, '-P', native.PORT, '-s', native.SERIAL, 'exec-in', 'run-as',
         native.PACKAGE, 'tee', 'files/frontier-settlement.json'],
        input=json.dumps(data).encode(), capture_output=True, timeout=120)
    if result.returncode:
        raise RuntimeError(result.stderr.decode(errors='replace')[-1000:])

def signature(data):
    return [(b['kind'], b['pos'], b['level']) if b else None for b in data['buildings']]

def continue_and_pause():
    native.launch()
    native.wait_menu()
    native.screen()
    native.tap(260, 462)
    time.sleep(6)
    native.tap(1338, 43)
    return native.save()

def run():
    started = time.monotonic()
    error = None
    native.OUT.mkdir(parents=True, exist_ok=True)
    original = None
    try:
        base = json.loads(BASE_REPORT.read_text())
        native.check(base['passed'] and base['apk_sha256'] == native.APK_SHA256,
                     'Upgrade test begins after the exact current APK passes native checks')
        original = native.save()
        native.check(original['version'] == 5 and original['terrain_revision'] == 2,
                     'Current native settlement uses the authored map')
        native.adb('shell', 'am', 'force-stop', native.PACKAGE)
        result = native.adb('install', '--no-incremental', '-r', '-d', PREVIOUS, timeout=360)
        native.check('Success' in result, 'Previous signed v0.5 APK installs on the disposable emulator')
        legacy = copy.deepcopy(original)
        legacy['version'] = 4
        legacy.pop('terrain_revision', None)
        legacy['mountains_enabled'] = True
        write_save(legacy)
        old = continue_and_pause()
        native.check(old['version'] == 4 and old['mountains_enabled'],
                     'Actual v0.5 app restores and writes its legacy terrain save')
        native.check(signature(old) == signature(original),
                     'Actual old app retains all building positions and levels')
        native.screen('01-old-app-settlement')
        native.adb('shell', 'am', 'force-stop', native.PACKAGE)
        result = native.adb('install', '--no-incremental', '-r', native.APK, timeout=360)
        native.check('Success' in result, 'New v0.6 APK updates v0.5 without clearing app data')
        retained = native.save()
        native.check(retained == old, 'Android update retains the complete legacy save file')
        migrated = continue_and_pause()
        native.check(migrated['version'] == 5 and migrated['terrain_revision'] == 1,
                     'New app migrates the actual old save while retaining its terrain')
        native.check(signature(migrated) == signature(old),
                     'Upgrade preserves every building kind, position and level')
        native.check(migrated['elapsed'] >= old['elapsed'] and migrated['kills'] >= old['kills'],
                     'Upgrade preserves mission progress and kills')
        native.check(all(migrated['resources'][k] >= old['resources'][k] for k in ['wood', 'stone', 'gold']),
                     'Upgrade retains the legacy economy')
        native.screen('02-updated-app-settlement')
    except BaseException as problem:
        error = str(problem)
        print('UPGRADE ERROR:', error, flush=True)
    finally:
        # Preserve the authored native-test settlement for any later diagnostics.
        if original is not None:
            try:
                native.adb('shell', 'am', 'force-stop', native.PACKAGE)
                write_save(original)
            except Exception as problem:
                error = error or ('Could not restore test fixture: ' + str(problem))
        report = {'passed': error is None and bool(native.checks) and all(c['passed'] for c in native.checks),
                  'error': error, 'checks': native.checks, 'actual_seconds': time.monotonic() - started,
                  'apk_sha256': native.APK_SHA256,
                  'previous_apk_sha256': hashlib.file_digest(PREVIOUS.open('rb'), 'sha256').hexdigest(),
                  'mode': 'actual-native-version-update'}
        (native.OUT / 'report.json').write_text(json.dumps(report, indent=2))
        print(json.dumps(report), flush=True)
    return 0 if report['passed'] else 1

if __name__ == '__main__':
    sys.exit(run())
