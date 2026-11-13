"""Verify an actual v0.8 -> v0.9 Android update on the disposable emulator.

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
        native.check(original['version'] == 8 and original['terrain_revision'] == 5,
                     'Current native settlement uses the authored map')
        native.adb('shell', 'am', 'force-stop', native.PACKAGE)
        result = native.adb('install', '--no-incremental', '-r', '-d', PREVIOUS, timeout=360)
        native.check('Success' in result, 'Previous signed v0.8 APK installs on the disposable emulator')
        legacy = copy.deepcopy(original)
        legacy['version'] = 7
        legacy['terrain_revision'] = 4
        legacy.pop('regeneration_level', None)
        legacy.pop('boss_intervals', None)
        legacy['research_job'] = {'kind': 'arrow', 'level': 3, 'duration': 43.0, 'remaining': 30.0}
        legacy['research_levels']['arrow'] = 2
        for building in legacy['buildings']:
            if building and building['kind'] == 'arrow':
                building.update(level=2, hp=650.0 * 1.085 * .5,
                                repair_left=6.0, repair_rate=650.0 * 1.085 * .5 / 8)
        # Isolate migration/healing from incoming damage during the two app loads.
        legacy['enemies'] = []
        legacy['spawn_remaining'] = 0
        legacy['spawn_clock'] = 30.0
        legacy['mountains_enabled'] = True
        write_save(legacy)
        injected = native.save()
        (native.OUT / 'injected-legacy.json').write_text(json.dumps(injected, indent=2))
        native.check(injected == legacy, 'Legacy fixture is written completely before launching the old app')
        old = continue_and_pause()
        (native.OUT / 'old-observed.json').write_text(json.dumps(old, indent=2))
        native.screen('01-old-app-settlement')
        print('OLD SAVE OBSERVED:', old.get('version'), old.get('mountains_enabled'), old.get('elapsed'), flush=True)
        native.check(old['version'] == 7 and old['terrain_revision'] == 4,
                     'Actual v0.8 app restores and writes its legacy terrain save')
        native.check(signature(old) == signature(legacy),
                     'Actual old app retains all building positions and levels')
        native.check(old['research_job'].get('kind') == 'arrow' and old['research_job']['remaining'] > 0,
                     'Old app has an already-paid upgrade still in progress before installation')
        native.adb('shell', 'am', 'force-stop', native.PACKAGE)
        result = native.adb('install', '--no-incremental', '-r', native.APK, timeout=360)
        native.check('Success' in result, 'New v0.9 APK updates v0.8 without clearing app data')
        retained = native.save()
        native.check(retained == old, 'Android update retains the complete legacy save file')
        migrated = continue_and_pause()
        native.check(migrated['version'] == 8 and migrated['terrain_revision'] == 4,
                     'New app migrates the actual old save while retaining its terrain')
        expected = [(b['kind'], b['pos'], 3 if b['kind'] == 'arrow' else b['level'])
                    if b and b['hp'] > 0 else None for b in old['buildings']]
        native.check(signature(migrated) == expected,
                     'Update retains foundations and completes the already-paid global arrow upgrade')
        native.check(migrated['research_levels']['arrow'] == 3 and len(migrated['deposits']) == 8 and
                     'research_job' not in migrated,
                     'Old eight-site terrain is retained and its research timer is removed')
        native.check(all('repair_left' not in b for b in migrated['buildings'] if b) and
                     migrated['regeneration_level'] == 0,
                     'Old paid repairs finish without retaining manual jobs or charging for Regeneration')
        health_preserved = True
        for before, after in zip(old['buildings'], migrated['buildings']):
            if before and before['kind'] == 'arrow' and before['hp'] > 0:
                old_max = 650.0 * 1.085 ** (before['level'] - 1)
                paid_hp = min(old_max, before['hp'] + before.get('repair_rate', 0) * before.get('repair_left', 0))
                expected_hp = paid_hp / old_max * 650.0 * 1.085 ** 2
                health_preserved &= after['hp'] >= expected_hp - .02
        native.check(health_preserved, 'Paid repair remainder is retained when instant global upgrade preserves the health fraction')
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
