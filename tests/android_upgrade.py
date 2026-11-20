"""Install the published v0.12 APK, write an actual legacy save, and update to v0.13.

Targets a disposable Android emulator. Preserves its original game save when
available. Uses a v0.12 save with multiple paid producers and tower upgrades so
we can exercise compatibility that fresh v0.13 settlements cannot reproduce.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import time

import android_smoke as device

PREVIOUS = Path(os.environ.get('ANDROID_PREVIOUS_APK', device.ROOT / 'builds/tabara-frontier-v0.12.apk'))
FIXTURE = device.ROOT / 'tests/fixtures/v012-paid-settlement.json'


def foundations(data):
    return [(b['kind'], b['pos'], b['level'], b.get('wall_size')) if b else None for b in data['buildings']]


def stop():
    device.adb('shell', 'am', 'force-stop', device.PACKAGE)


def continue_and_pause(capture):
    device.launch()
    device.wait_menu()
    device.tap(260, 462)
    time.sleep(4)
    device.screen(capture)
    device.tap(1338, 43)
    return device.save()


def purchase_age(expected):
    # advance_age saves synchronously. Read the receipt as soon as Android handles
    # the touch so waiting for seven separate pause/resume cycles cannot start a raid.
    time.sleep(.5)  # Let the next price finish drawing before accepting its tap.
    device.adb('shell', 'input', 'tap', *device.physical(1273, 678))
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        receipt = device.save()
        if receipt['settlement_age'] >= expected:
            device.check(receipt['settlement_age'] == expected,
                         f'Hall touch purchase advances exactly to tier {expected}')
            return receipt
        time.sleep(.2)
    raise TimeoutError(f'No Hall purchase receipt for age {expected}')


def install(apk, label):
    result = device.adb('install', '--no-incremental', '-r', '-d', apk, timeout=360)
    device.check('Success' in result, label)


def run():
    device.OUT.mkdir(parents=True, exist_ok=True)
    old_bytes = None
    failure = None
    started = time.monotonic()
    try:
        stop()
        try:
            old_bytes = device.save()
        except (RuntimeError, ValueError):
            pass  # A fresh disposable emulator may have no settlement yet.
        install(PREVIOUS, 'The published v0.12 APK installs')
        if old_bytes is None:
            # The old app creates its own private files directory on first launch.
            device.launch()
            device.wait_menu()
            stop()
        source = json.loads(FIXTURE.read_text())
        # Keep all eight actual v0.12 producers and their paid levels alive while
        # both apps render the scene. The far western woodcutter is already under
        # attack in the archived save and can fall before the first screenshot.
        source.update(camera=[4840.0, 2800.0, .72], enemies=[], spawn_remaining=0, spawn_clock=30.0)
        device.write_save(source)
        before = continue_and_pause('01-legacy-settlement')
        device.check(before['version'] == 11 and before['terrain_revision'] == 5,
                     'v0.12 loaded and saved the eight-site legacy settlement')
        device.check(foundations(before) == foundations(source), 'Old APK retained the fixture foundations')
        stop()
        install(device.APK, 'The signed ages APK updates v0.12 in place')
        device.check(device.save() == before, 'The Android update preserves the complete previous save')
        after = continue_and_pause('02-migrated-settlement')
        device.check(after['version'] == 12 and after['terrain_revision'] == 5 and after['settlement_age'] == 1,
                     'Legacy settlement starts in Wood with its original geography')
        device.check(after['deposits'] == before['deposits'] and foundations(after) == foundations(before),
                     'All original resource sites, workers’ buildings, tower levels and wall footprints survive')
        device.check(after['research_levels'] == before['research_levels'] and
                     after['regeneration_level'] == before['regeneration_level'], 'Old defense grades and Regeneration survive')
        device.check(all(after['tower_tracks'][kind + '_damage'] == before['research_levels'][kind]
                         for kind in ('arrow', 'cannon')), 'Purchased damage carries over into both tower lines')
        # The rest of the check uses a temporary late-game budget and an empty incoming wave.
        funded = dict(after, resources={'wood': 10000.0, 'stone': 10000.0, 'gold': 10000.0},
                      elapsed=0.0, wave=1, enemies=[], spawn_clock=30.0, spawn_remaining=0)
        stop()
        device.write_save(funded)
        continue_and_pause('03-funded-legacy-settlement')
        device.tap(720, 505)
        device.tap(1194, 43)
        for expected_age in range(2, 9):
            purchased = purchase_age(expected_age)
            device.check(foundations(purchased) == foundations(before),
                         f'All paid legacy foundations and levels survive age {expected_age}')
            if expected_age in (2, 4):
                device.screen(f'04-hall-age-{expected_age}')
        device.check(purchased['wave'] == 1 and not purchased['enemies'],
                     'The seven paid age transitions completed inside the isolated opening wave')
        device.screen('05-crown-hall')
        device.tap(1338, 43)
        stop()
        reloaded = continue_and_pause('06-crown-reloaded')
        device.check(reloaded['settlement_age'] == 8 and reloaded['tower_tracks'] == after['tower_tracks'],
                     'Crown and inherited tower ranks survive cold restart')
        device.check(foundations(reloaded) == foundations(before), 'Age changes preserve legacy foundations and levels')
        log = device.adb('logcat', '-d', '-t', '2000', '-v', 'brief')
        (device.OUT / 'logcat.txt').write_text(log)
        device.check(not any(flag in log for flag in ('FATAL EXCEPTION', 'SCRIPT ERROR:', 'Shader compilation failed')),
                     'Native progression run has no fatal, script or shader diagnostics')
    except Exception as exc:
        failure = str(exc)
        print('UPGRADE ERROR:', failure, flush=True)
        try:
            device.screen('failed-state')
            (device.OUT / 'failed-save.json').write_text(json.dumps(device.save(), indent=2))
        except Exception:
            pass
    finally:
        if old_bytes is not None:
            try:
                stop()
                device.write_save(old_bytes)
            except Exception as exc:
                failure = failure or str(exc)
    report = {'passed': failure is None, 'error': failure, 'checks': device.checks,
              'seconds': time.monotonic() - started, 'apk_sha256': device.APK_SHA256,
              'previous_apk_sha256': hashlib.sha256(PREVIOUS.read_bytes()).hexdigest(),
              'fixture': 'Actual v0.12 save with eight paid producers. The incoming wave is cleared before both versions render the baseline. Migration retains the old economy, levels and progress. Then a separate fixture grants 10,000 of each resource, resets elapsed time to zero and suppresses the opening wave while checking all seven paid age changes and cold reload.'}
    (device.OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)
    return int(not report['passed'])


if __name__ == '__main__':
    raise SystemExit(run())
