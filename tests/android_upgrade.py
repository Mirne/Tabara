"""Actual v0.9 -> v0.10 installation plus native UI checks on a disposable emulator.

ANDROID_PREVIOUS_APK selects the published v0.9 APK. Uses android_smoke's adb,
APK, tap-delay and report variables. Never clears app data. Migration retains the
old economy; the subsequent UI fixture explicitly grants supplies and clears
attackers. The migrated settlement is restored after testing.
"""
from __future__ import annotations
import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import time
import android_smoke as n

PREVIOUS = Path(os.environ.get('ANDROID_PREVIOUS_APK', n.ROOT / 'builds/tabara-frontier-v0.9.apk'))
LOCAL = {'hall', 'wood', 'stone', 'market', 'workshop'}

def signature(data):
    return [(b['kind'], b['pos'], b['level']) if b else None for b in data['buildings']]

def load_and_pause():
    n.launch()
    n.wait_menu()
    n.screen('menu')
    n.tap(260, 462)
    time.sleep(6)
    n.tap(1338, 43)
    return n.save()

def unpause():
    n.adb('shell', 'input', 'keyevent', '4')
    time.sleep(n.TAP_DELAY)

def run():
    n.OUT.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    error = None
    retained = None
    try:
        n.adb('shell', 'am', 'force-stop', n.PACKAGE)
        n.check('Success' in n.adb('install', '--no-incremental', '-r', '-d', PREVIOUS, timeout=360),
                'Published v0.9 APK installs without clearing its settlement')
        legacy = n.save()
        n.check(legacy['version'] == 8, 'Existing v0.9 settlement is present on the test device')
        # A controlled old-save fixture checks migration of global producer levels.
        # It changes no foundations, resource budget, kills, or mission clock.
        legacy['enemies'] = []
        legacy['spawn_remaining'] = 0
        legacy['spawn_clock'] = 30.0
        legacy['trade_clock'] = 7.0
        levels = {'hall': 2, 'wood': 3, 'stone': 4, 'market': 2, 'workshop': 2}
        for kind, level in levels.items():
            legacy['research_levels'][kind] = level
        for b in legacy['buildings']:
            if b and b['kind'] in levels:
                b['hp'] *= 1.085 ** (levels[b['kind']] - b['level'])
                b['level'] = levels[b['kind']]
        legacy['camera'] = [4840.0, 2800.0, .72]
        n.write_save(legacy)
        old = load_and_pause()
        n.check(old['version'] == 8 and signature(old) == signature(legacy),
                'Actual old app loads and writes the global-level fixture')
        n.screen('01-v09-save')
        n.adb('shell', 'am', 'force-stop', n.PACKAGE)
        n.check('Success' in n.adb('install', '--no-incremental', '-r', n.APK, timeout=360),
                'Signed v0.10 APK updates v0.9 with the existing certificate')
        n.check(n.save() == old, 'Android installation retains the complete old save file')
        migrated = load_and_pause()
        n.check(migrated['version'] == 9 and migrated['terrain_revision'] == old['terrain_revision'],
                'New app migrates the save format and preserves its map')
        n.check(signature(migrated) == signature(old),
                'Migration preserves every foundation and purchased building level')
        n.check(migrated['research_levels'] == old['research_levels'] and migrated['regeneration_level'] == old['regeneration_level'],
                'Migration preserves defense levels and purchased Regeneration')
        n.check(all(migrated['resources'][k] >= old['resources'][k] for k in ['wood', 'stone', 'gold']),
                'Migration preserves the original economy')
        n.check(migrated['elapsed'] >= old['elapsed'] and migrated['kills'] >= old['kills'],
                'Migration preserves mission progress and kills')
        n.check('trade_clock' not in migrated and 'research_job' not in migrated,
                'New save has no trade cooldown or research timer')
        n.screen('02-migrated')
        retained = migrated
        # UI-only fixture: explicit budget; this is not a normal-cost campaign.
        n.adb('shell', 'am', 'force-stop', n.PACKAGE)
        fixture = copy.deepcopy(migrated)
        fixture.update(resources={'wood': 1000.0, 'stone': 1000.0, 'gold': 1000.0},
                       enemies=[], spawn_remaining=0, spawn_clock=30.0)
        fixture['camera'] = [4840.0, 2800.0, .72]
        n.write_save(fixture)
        load_and_pause()
        unpause()
        n.tap(*n.world_point(4760, 2440))
        n.tap(1273, 584)
        n.screen('03-local-producer')
        n.tap(1273, 763)
        n.tap(1194, 218)
        n.tap(*n.world_point(5360, 2440))
        n.tap(1273, 685)
        n.tap(1273, 763)
        n.tap(1338, 43)
        local = n.save()
        woods = {tuple(b['pos']): b for b in local['buildings'] if b and b['kind'] == 'wood'}
        n.check(woods[(4760,2440)]['level'] == 4 and woods[(5360,2440)]['level'] == 1,
                'Native producer upgrade affects one building and a new producer starts at one')
        n.check(next(b for b in local['buildings'] if b and b['kind'] == 'stone')['level'] == 4,
                'Unselected quarry keeps its old purchased level')
        unpause()
        n.tap(1352, 534)
        n.tap(*n.world_point(5200, 3200))
        n.tap(1273, 685)
        n.tap(1273, 763)
        end = time.monotonic() + 240
        while True:
            time.sleep(12)
            n.tap(1338, 43)
            market = next((b for b in n.save()['buildings'] if b and b['kind'] == 'market'), None)
            if market and market['age'] >= 2.5:
                break
            if time.monotonic() > end:
                raise TimeoutError('Native Marketplace did not finish construction')
            unpause()
        n.check(market['level'] == 1, 'Native input builds a new Marketplace at level one')
        unpause()
        n.tap(*n.world_point(5200, 3200))
        n.tap(1273, 584)
        n.screen('04-passive-marketplace')
        n.tap(1338, 43)
        before = n.save()
        n.check(next(b for b in before['buildings'] if b and b['kind'] == 'market')['level'] == 2,
                'Native Marketplace panel upgrades passive gold income locally')
        unpause()
        time.sleep(15)
        n.tap(1338, 43)
        after = n.save()
        expected = (2.0 * 1.08 + .1) * (after['elapsed'] - before['elapsed'])
        n.check(abs(after['resources']['gold'] - before['resources']['gold'] - expected) < .03,
                'Native Marketplace credits upgraded passive gold without trade input')
        unpause()
        n.tap(*n.world_point(5200, 2800))
        n.tap(1352, 330)
        n.tap(1273, 678)
        n.screen('05-regeneration-in-upgrades')
        n.tap(1338, 43)
        final = n.save()
        n.check(final['regeneration_level'] == migrated['regeneration_level'] + 1,
                'Native Workshop purchases Regeneration from its shared Upgrades list')
        n.adb('shell', 'am', 'force-stop', n.PACKAGE)
        n.write_save(final)
        restarted = load_and_pause()
        n.check(signature(restarted) == signature(final) and restarted['regeneration_level'] == final['regeneration_level'],
                'Cold restart retains mixed local levels, Marketplace and Regeneration')
        log = n.adb('logcat', '-d', '-t', '500', '-v', 'brief', timeout=90)
        (n.OUT / 'logcat.txt').write_text(log)
        n.check(not any(t in log for t in ['FATAL EXCEPTION', 'SCRIPT ERROR:', 'SHADER ERROR:', 'Shader compilation failed']),
                'Native diagnostics have no script, shader or fatal error')
    except BaseException as problem:
        error = str(problem)
        print('UPGRADE ERROR:', error, flush=True)
        try:
            (n.OUT / 'failed-save.json').write_text(json.dumps(n.save(), indent=2))
            n.screen('failed-state')
        except Exception:
            pass
    finally:
        if retained is not None:
            try:
                n.adb('shell', 'am', 'force-stop', n.PACKAGE)
                n.write_save(retained)
            except Exception as problem:
                error = error or str(problem)
        report = {'passed': error is None and bool(n.checks) and all(c['passed'] for c in n.checks),
                  'error': error, 'checks': n.checks, 'actual_seconds': time.monotonic() - started,
                  'apk_sha256': n.APK_SHA256,
                  'previous_apk_sha256': hashlib.file_digest(PREVIOUS.open('rb'), 'sha256').hexdigest(),
                  'mode': 'actual-v09-update-and-native-ui',
                  'fixtures': 'Old global levels and a cooldown are set in a v0.9 save, then written by the actual old app. Migration retains its economy. Subsequent native UI checks explicitly grant 1000 of each resource and clear attackers. The migrated pre-grant settlement is restored afterward.'}
        (n.OUT / 'report.json').write_text(json.dumps(report, indent=2))
        print(json.dumps(report), flush=True)
    return 0 if report['passed'] else 1

if __name__ == '__main__':
    sys.exit(run())
