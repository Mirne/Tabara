"""Verify an actual v0.7 -> v0.8 Android update on the disposable emulator.

Run after android_smoke.py. Requires ANDROID_PREVIOUS_APK and ANDROID_BASE_REPORT;
uses the same adb/device/report variables as android_smoke.py. Both APKs must
use the same signing key. It replaces only
com.tabara.lasthearth on that test emulator and never clears app data.
"""
from __future__ import annotations
import base64
import copy
import hashlib
import json
import os
from pathlib import Path
import shlex
import sys
import time
import android_smoke as native

PREVIOUS = Path(os.environ['ANDROID_PREVIOUS_APK'])
BASE_REPORT = Path(os.environ['ANDROID_BASE_REPORT'])

def write_save(data):
    # Older adbd can acknowledge exec-in without executing its command. Use the
    # normal shell protocol and verify the app-private file before proceeding.
    payload = base64.b64encode(json.dumps(data).encode()).decode('ascii')
    inner = "printf '%s' " + shlex.quote(payload) + " | base64 -d > files/frontier-settlement.json"
    command = 'run-as ' + shlex.quote(native.PACKAGE) + ' sh -c ' + shlex.quote(inner)
    native.adb('shell', command, timeout=120)
    if native.save() != data:
        raise RuntimeError('Legacy fixture transfer did not preserve the complete save')


def signature(data):
    return [(b['kind'], b['pos'], b['level']) if b else None for b in data['buildings']]

def continue_and_pause():
    native.launch()
    native.wait_menu()
    native.screen('current-menu')
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
        native.check(original['version'] == 7 and original['terrain_revision'] == 4,
                     'Current native settlement uses the authored map')
        native.adb('shell', 'am', 'force-stop', native.PACKAGE)
        result = native.adb('install', '--no-incremental', '-r', '-d', PREVIOUS, timeout=360)
        native.check('Success' in result, 'Previous signed v0.7 APK installs on the disposable emulator')
        legacy = copy.deepcopy(original)
        legacy['version'] = 6
        legacy['terrain_revision'] = 3
        legacy['deposits'] = [0.0] * 28
        for key in ['research_levels', 'research_job', 'trade_clock']:
            legacy.pop(key, None)
        old_bases = {'hall': 4200.0, 'wood': 300.0, 'stone': 380.0, 'arrow': 500.0,
                     'wall': 1250.0, 'cannon': 650.0, 'market': 350.0}
        for index, building in enumerate(legacy['buildings']):
            if building is None:
                continue
            if building['kind'] == 'workshop':
                legacy['buildings'][index] = None
                continue
            building['hp'] = min(building['hp'], old_bases[building['kind']] * 1.11 ** (building['level'] - 1))
            building.pop('repair_left', None)
            building.pop('repair_rate', None)
        # An actual older settlement can have different individual tower levels.
        legacy['buildings'].append({'kind': 'arrow', 'pos': [4920.0, 2520.0], 'level': 3,
                                    'hp': 500.0 * 1.11 ** 2, 'cooldown': 0.15,
                                    'age': 10.0, 'ruined_at': -1.0})
        legacy['enemies'] = [enemy for enemy in legacy['enemies'] if enemy['kind'] != 'elite']
        for enemy in legacy['enemies']:
            for key in ['anger', 'anger_left', 'anger_path', 'anger_step']:
                enemy.pop(key, None)
        legacy['mountains_enabled'] = True
        write_save(legacy)
        injected = native.save()
        (native.OUT / 'injected-legacy.json').write_text(json.dumps(injected, indent=2))
        native.check(injected == legacy, 'Legacy fixture is written completely before launching the old app')
        old = continue_and_pause()
        (native.OUT / 'old-observed.json').write_text(json.dumps(old, indent=2))
        native.screen('01-old-app-settlement')
        print('OLD SAVE OBSERVED:', old.get('version'), old.get('mountains_enabled'), old.get('elapsed'), flush=True)
        native.check(old['version'] == 6 and old['terrain_revision'] == 3,
                     'Actual v0.7 app restores and writes its legacy terrain save')
        native.check(signature(old) == signature(legacy),
                     'Actual old app retains all building positions and levels')
        native.adb('shell', 'am', 'force-stop', native.PACKAGE)
        result = native.adb('install', '--no-incremental', '-r', native.APK, timeout=360)
        native.check('Success' in result, 'New v0.8 APK updates v0.7 without clearing app data')
        retained = native.save()
        native.check(retained == old, 'Android update retains the complete legacy save file')
        migrated = continue_and_pause()
        native.check(migrated['version'] == 7 and migrated['terrain_revision'] == 3,
                     'New app migrates the actual old save while retaining its terrain')
        levels = {}
        for building in old['buildings']:
            if building and building['hp'] > 0:
                levels[building['kind']] = max(levels.get(building['kind'], 1), int(building['level']))
        expected = [(building['kind'], building['pos'], levels[building['kind']])
                    if building and building['hp'] > 0 else None for building in old['buildings']]
        native.check(signature(migrated) == expected,
                     'Upgrade preserves foundations and migrates the highest old level per building type globally')
        native.check(migrated['research_levels']['arrow'] == 3 and len(migrated['deposits']) == 28,
                     'Legacy terrain retains its sites and existing tower research is never downgraded')
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
