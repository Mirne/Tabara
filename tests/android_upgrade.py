"""Actual v0.10 -> v0.11 Android update, target-facing attacks and final-boss victory.

Uses android_smoke's adb/APK/report variables and the published previous APK.
Never clears app data. Clock/position/HP fixtures isolate encounters; the attack
fixture reinforces walls to level 100, and the win fixture lowers final boss HP
for a real tower kill. Neither is a normal-cost campaign. Restore the migrated
settlement after testing. ANDROID_OLD_FIXTURE can supply a retained old save on retry.
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

PREVIOUS = Path(os.environ.get('ANDROID_PREVIOUS_APK', n.ROOT / 'builds/tabara-frontier-v0.10.apk'))

def signature(data):
    return [(b['kind'], b['pos'], b['level']) if b else None for b in data['buildings']]

def launch_continue(name=None):
    n.launch()
    n.wait_menu()
    n.screen('menu')
    n.tap(260, 462)
    time.sleep(6)
    if name:
        n.screen(name)

def pause():
    n.tap(1338, 43)
    return n.save()

def load_fixture(data, name=None):
    n.adb('shell', 'am', 'force-stop', n.PACKAGE)
    n.write_save(data)
    launch_continue(name)
    return pause()

def run():
    n.OUT.mkdir(parents=True, exist_ok=True)
    started=time.monotonic()
    retained=None
    error=None
    try:
        n.adb('shell','am','force-stop',n.PACKAGE)
        n.check('Success' in n.adb('install','--no-incremental','-r','-d',PREVIOUS,timeout=360),
                'Published v0.10 APK installs without clearing its settlement')
        old_path=os.environ.get('ANDROID_OLD_FIXTURE')
        original=json.loads(Path(old_path).read_text()) if old_path else n.save()
        n.check(original['version'] in [8,9], 'A compatible old settlement exists before updating')
        original.update(enemies=[],spawn_remaining=0,spawn_clock=30.0)
        original['camera']=[4840.0,2800.0,.72]
        old=load_fixture(original,'01-v010-settlement')
        n.check(old['version']==9,'Actual v0.10 app writes its format-nine save')
        (n.OUT/'old-format-nine.json').write_text(json.dumps(old,indent=2))
        n.adb('shell','am','force-stop',n.PACKAGE)
        n.check('Success' in n.adb('install','--no-incremental','-r',n.APK,timeout=360),
                'Signed v0.11 APK updates v0.10 with the same certificate')
        n.check(n.save()==old,'Android installation preserves the complete old save file')
        launch_continue('02-migrated-settlement')
        migrated=pause()
        n.check(migrated['version']==10 and migrated['terrain_revision']==old['terrain_revision'],
                'New save format retains the existing map')
        n.check(signature(migrated)==signature(old),'All local/global building levels and foundations survive migration')
        n.check(migrated['research_levels']==old['research_levels'] and migrated['regeneration_level']==old['regeneration_level'],
                'Defense upgrades and Regeneration are retained')
        n.check(all(migrated['resources'][k]>=old['resources'][k] for k in ['wood','stone','gold']),
                'Updating retains the original economy')
        n.check(migrated['elapsed']>=old['elapsed'] and migrated['kills']>=old['kills'],
                'Updating retains mission progress and kills')
        retained=migrated
        boundary=copy.deepcopy(migrated)
        boundary.update(elapsed=899.95,wave=30,boss_intervals=2,enemies=[],spawn_remaining=0,
                        spawn_clock=30.0,victory=False,victory_seen=False,final_boss_id=0,
                        final_boss_defeated=False,legacy_completion=False)
        boundary['camera']=[500.0,2700.0,1.0]
        observed=load_fixture(boundary,'03-final-boss-arrival')
        bosses=[e for e in observed['enemies'] if e.get('mission_boss')]
        n.check(observed['elapsed']>=900 and not observed['victory'] and not observed['victory_seen'],
                'Fifteen minutes keeps the native battle running without victory')
        n.check(len(bosses)==1 and bosses[0]['id']==observed['final_boss_id'] and bosses[0]['boss_rank']==3,
                'Exactly one final Warlord enters at fifteen minutes')
        n.check(bosses[0]['max_hp']>20000 and bosses[0]['damage']>500,
                'Native final boss uses its substantially stronger profile')
        n.check(bosses[0]['pos'][0]<1400,'Final Warlord enters at the western approach')
        # Hold a genuine attack against a reinforced wall to inspect both directions.
        posed=copy.deepcopy(observed)
        posed['enemies']=[copy.deepcopy(bosses[0])]
        posed['spawn_remaining']=0
        posed['spawn_clock']=30.0
        walls=[(i,b) for i,b in enumerate(posed['buildings']) if b and b['kind']=='wall']
        if not walls:
            raise RuntimeError('Old native settlement has no wall for the attack fixture')
        wall_index,wall=min(walls,key=lambda row:abs(row[1]['pos'][1]-2760))
        for b in posed['buildings']:
            if b and b['kind']=='wall':
                b['hp']*=1.085**(100-b['level'])
                b['level']=100
        posed['research_levels']['wall']=100
        posed['regeneration_level']=0
        enemy=posed['enemies'][0]
        enemy.update(pos=[wall['pos'][0]+60,wall['pos'][1]],target=wall_index,aim=.2,
                     cooldown=0.0,attacking=False,attack_left=0.0,anger=-1,anger_left=0.0)
        posed['camera']=[wall['pos'][0]+220,wall['pos'][1],1.0]
        left=load_fixture(posed,'04-attack-left')
        actor=next(e for e in left['enemies'] if e.get('mission_boss'))
        n.check(actor['attacking'] and actor['facing_left'],'A native unit attacking a target on its left mirrors and attacks')
        n.check(left['buildings'][wall_index]['hp']<posed['buildings'][wall_index]['hp'],
                'Native attack animation accompanies real building damage')
        n.check(left['final_boss_id']==observed['final_boss_id'] and not left['victory'],
                'Restart preserves the living final boss and unfinished mission')
        right_fixture=copy.deepcopy(left)
        right_fixture['enemies']=[copy.deepcopy(actor)]
        right_fixture['enemies'][0].update(pos=[wall['pos'][0]-60,wall['pos'][1]],target=wall_index,
                                          aim=.2,cooldown=0.0,attack_left=0.0,anger=-1,anger_left=0.0)
        right=load_fixture(right_fixture,'05-attack-right')
        actor=next(e for e in right['enemies'] if e.get('mission_boss'))
        n.check(actor['attacking'] and not actor['facing_left'],'A native unit switches back to a right-facing attack')
        # Only lower this boss's HP; an actual standing tower must deal the kill.
        finish=copy.deepcopy(right)
        arrow=next(b for b in finish['buildings'] if b and b['kind']=='arrow')
        actor=copy.deepcopy(actor)
        actor.update(hp=1.0,pos=[arrow['pos'][0]+100,arrow['pos'][1]],target=-1,aim=0.0,
                     attacking=False,attack_left=0.0,anger=-1,anger_left=0.0)
        finish['enemies']=[actor]
        finish['spawn_remaining']=0
        finish['spawn_clock']=30.0
        finish['camera']=[4840.0,2800.0,.72]
        for b in finish['buildings']:
            if b and b['kind'] in ['arrow','cannon','hall']:b['cooldown']=0.0
        n.adb('shell','am','force-stop',n.PACKAGE)
        n.write_save(finish)
        launch_continue('06-final-boss-victory')
        won=n.save()
        n.check(won['victory'] and won['final_boss_defeated'] and won['victory_seen'],
                'Actual native tower damage kills the final boss and opens victory')
        n.check(won['buildings'][0]['hp']>0 and not any(e.get('mission_boss') for e in won['enemies']),
                'Victory requires the final boss dead and the Hall alive')
        n.tap(720,505)
        time.sleep(4)
        endless=pause()
        n.check(endless['elapsed']>won['elapsed'] and endless['victory'],
                'Native endless survival resumes after the final-boss victory')
        log=n.adb('logcat','-d','-t','500','-v','brief',timeout=90)
        (n.OUT/'logcat.txt').write_text(log)
        n.check(not any(t in log for t in ['FATAL EXCEPTION','SCRIPT ERROR:','SHADER ERROR:','Shader compilation failed']),
                'Native diagnostics have no script, shader or fatal error')
    except BaseException as problem:
        error=str(problem)
        print('UPGRADE ERROR:',error,flush=True)
        try:
            (n.OUT/'failed-save.json').write_text(json.dumps(n.save(),indent=2))
            n.screen('failed-state')
        except Exception:pass
    finally:
        if retained is not None:
            try:
                n.adb('shell','am','force-stop',n.PACKAGE)
                n.write_save(retained)
            except Exception as problem:error=error or str(problem)
        report={'passed':error is None and bool(n.checks) and all(c['passed'] for c in n.checks),
                'error':error,'checks':n.checks,'actual_seconds':time.monotonic()-started,
                'apk_sha256':n.APK_SHA256,'previous_apk_sha256':hashlib.file_digest(PREVIOUS.open('rb'),'sha256').hexdigest(),
                'mode':'actual-v010-update-attacks-and-final-boss',
                'fixtures':'Migration keeps the old economy and clears incoming attackers. Later fixtures advance the clock to 899.95, reinforce existing walls to level 100 and disable Regeneration for isolated target-facing attack captures, reposition the final boss, and lower its HP to 1 for an actual tower kill. They grant no supplies and are not normal-cost campaign evidence. The pre-fixture migrated settlement is restored afterward.'}
        (n.OUT/'report.json').write_text(json.dumps(report,indent=2))
        print(json.dumps(report),flush=True)
    return 0 if report['passed'] else 1

if __name__=='__main__':sys.exit(run())
