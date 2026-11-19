"""Actual v0.11 -> v0.12 update, mixed-size walls, miniboss skills and Rain.

Does not clear app data. Later encounter fixtures are explicitly not campaigns.
Restore the pre-fixture migrated settlement after all checks.
ANDROID_OLD_FIXTURE supplies the retained format-ten save on a retry.
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

PREVIOUS=Path(os.environ.get('ANDROID_PREVIOUS_APK',n.ROOT/'builds/tabara-frontier-v0.11.apk'))

def signature(data):
    return [(b['kind'],b['pos'],b['level']) if b else None for b in data['buildings']]

def launch_continue(name=None):
    n.launch()
    n.wait_menu()
    n.screen('menu')
    n.tap(260,462)
    time.sleep(6)
    if name:n.screen(name)

def pause():
    n.tap(1338,43)
    return n.save()

def load_fixture(data,name=None):
    n.adb('shell','am','force-stop',n.PACKAGE)
    n.write_save(data)
    launch_continue(name)
    return pause()

def run():
    n.OUT.mkdir(parents=True,exist_ok=True)
    started=time.monotonic()
    retained=None
    error=None
    try:
        n.adb('shell','am','force-stop',n.PACKAGE)
        n.check('Success' in n.adb('install','--no-incremental','-r','-d',PREVIOUS,timeout=360),
                'Published v0.11 installs without clearing the settlement')
        old_path=os.environ.get('ANDROID_OLD_FIXTURE')
        original=json.loads(Path(old_path).read_text()) if old_path else n.save()
        n.check(original['version'] in [9,10],'A compatible old settlement exists')
        original.update(enemies=[],spawn_remaining=0,spawn_clock=30.0)
        original['camera']=[4840.0,2800.0,.72]
        old=load_fixture(original,'01-v011-settlement')
        n.check(old['version']==10,'Actual v0.11 writes a format-ten save')
        (n.OUT/'old-format-ten.json').write_text(json.dumps(old,indent=2))
        n.adb('shell','am','force-stop',n.PACKAGE)
        n.check('Success' in n.adb('install','--no-incremental','-r',n.APK,timeout=360),
                'Signed v0.12 updates v0.11 with the same certificate')
        n.check(n.save()==old,'Installing preserves the complete old save file')
        launch_continue('02-migrated-settlement')
        migrated=pause()
        n.check(migrated['version']==11 and migrated['terrain_revision']==old['terrain_revision'],
                'New ability save format keeps the map')
        n.check(signature(migrated)==signature(old),'Existing foundations and levels survive migration')
        n.check(all(b.get('wall_size')==80 for b in migrated['buildings'] if b and b['kind']=='wall'),
                'Existing 80-unit walls retain their physical footprints')
        n.check(migrated['research_levels']==old['research_levels'] and migrated['regeneration_level']==old['regeneration_level'],
                'Global upgrades and Regeneration survive the update')
        n.check(all(migrated['resources'][k]>=old['resources'][k] for k in ['wood','stone','gold']) and migrated['elapsed']>=old['elapsed'],
                'The original economy and mission progress are retained')
        n.check(migrated['rain_cooldown']==0 and not migrated['arrow_rains'],
                'Old settlements start with Rain available and no phantom barrage')
        retained=copy.deepcopy(migrated)
        # Explicit UI budget after the unmodified economy migration checks.
        fixture=copy.deepcopy(migrated)
        fixture.update(resources={'wood':1000.0,'stone':1000.0,'gold':1000.0},
                       enemies=[],spawn_remaining=0,spawn_clock=30.0)
        fixture['camera']=[4840.0,2800.0,.72]
        load_fixture(fixture)
        n.tap(720,505)
        n.tap(1352,376)
        n.tap(*n.world_point(4220,2780))
        n.screen('03-single-cell-preview')
        n.tap(1273,685)
        mixed=pause()
        added=[b for b in mixed['buildings'] if b and b['kind']=='wall' and b.get('wall_size')==40]
        n.check(len(added)==1 and added[0]['pos']==[4220.0,2780.0],
                'A mobile confirmation adds one 40-unit wall against the old rampart')
        n.check(sum(bool(b and b['kind']=='wall' and b.get('wall_size')==80) for b in mixed['buildings'])==
                sum(bool(b and b['kind']=='wall') for b in old['buildings']),
                'New construction leaves all legacy wall foundations intact')
        n.screen('04-mixed-wall-join')
        boundary=copy.deepcopy(mixed)
        boundary.update(elapsed=299.95,wave=10,boss_intervals=0,enemies=[],spawn_remaining=0,
                        spawn_clock=30.0,victory=False,victory_seen=False,final_boss_id=0,
                        final_boss_defeated=False,legacy_completion=False)
        boundary['camera']=[500.0,2700.0,1.0]
        observed=load_fixture(boundary,'05-five-minute-warlord')
        bosses=[e for e in observed['enemies'] if e['kind']=='boss']
        n.check(len(bosses)==1 and bosses[0]['boss_rank']==1 and not observed['victory'],
                'Five-minute miniboss enters once without completing the mission')
        n.check(2000<bosses[0]['max_hp']<3000 and bosses[0]['smash_clock']==0,
                'The arriving miniboss retains its real profile and has smash ready')
        posed=copy.deepcopy(observed)
        posed['enemies']=[copy.deepcopy(bosses[0])]
        posed['spawn_remaining']=0
        posed['spawn_clock']=30.0
        posed['regeneration_level']=0
        walls=[(i,b) for i,b in enumerate(posed['buildings']) if b and b['kind']=='wall' and b['wall_size']==80]
        wall_index,wall=min(walls,key=lambda row:abs(row[1]['pos'][1]-2680))
        for building in posed['buildings']:
            if building and building['kind']=='wall':
                building['hp']*=1.085**(100-building['level'])
                building['level']=100
        posed['research_levels']['wall']=100
        actor=posed['enemies'][0]
        actor.update(hp=20000.0,max_hp=20000.0,pos=[wall['pos'][0]+60,wall['pos'][1]],
                     target=wall_index,aim=.2,cooldown=0.0,attacking=False,attack_left=0.0,
                     smash_clock=0.0,smash_left=0.0,smash_center=[0.0,0.0],anger=-1,anger_left=0.0)
        posed['camera']=[wall['pos'][0]+220,wall['pos'][1],1.0]
        left=load_fixture(posed,'06-smash-left')
        actor=left['enemies'][0]
        hurt=[i for i,b in enumerate(left['buildings']) if b and b['kind']=='wall' and
              b['hp']<posed['buildings'][i]['hp']-.01]
        n.check(actor['attacking'] and actor['facing_left'] and 0<actor['smash_clock']<=3,
                'Native miniboss mirrors left and uses its three-second smash cycle')
        n.check(len(hurt)>=2,'A native smash damages multiple real wall buildings')
        right_fixture=copy.deepcopy(left)
        right_fixture['enemies'][0].update(pos=[wall['pos'][0]-60,wall['pos'][1]],target=wall_index,
                                          aim=.2,cooldown=0.0,smash_clock=0.0,smash_left=0.0,
                                          attack_left=0.0,anger=-1,anger_left=0.0)
        right=load_fixture(right_fixture,'07-smash-right')
        n.check(right['enemies'][0]['attacking'] and not right['enemies'][0]['facing_left'],
                'Reloaded miniboss switches to a right-facing hammer attack')
        # Isolate Rain as the final-boss killing source outside every weapon range.
        final=copy.deepcopy(mixed)
        final.update(elapsed=899.95,wave=30,boss_intervals=2,enemies=[],spawn_remaining=0,
                     spawn_clock=30.0,victory=False,victory_seen=False,final_boss_id=0,
                     final_boss_defeated=False,legacy_completion=False,rain_cooldown=0.0,arrow_rains=[])
        final['camera']=[500.0,2700.0,1.0]
        arrival=load_fixture(final,'08-final-arrival')
        final_actor=next(e for e in arrival['enemies'] if e.get('mission_boss'))
        n.check(not arrival['victory'] and final_actor['max_hp']>20000,
                'Fifteen-minute final Warlord still arrives without a timed victory')
        finish=copy.deepcopy(arrival)
        finish['enemies']=[copy.deepcopy(final_actor)]
        finish['spawn_remaining']=0
        finish['spawn_clock']=30.0
        finish['regeneration_level']=0
        workshop_index=next(i for i,b in enumerate(finish['buildings']) if b and b['kind']=='workshop')
        workshop=finish['buildings'][workshop_index]
        workshop['hp']*=1.085**(100-workshop['level'])
        workshop['level']=100
        quarry_index=next(i for i,b in enumerate(finish['buildings']) if b and b['kind']=='stone')
        quarry=finish['buildings'][quarry_index]
        quarry['hp']*=1.085**(100-quarry['level'])
        quarry['level']=100
        finish['enemies'][0].update(hp=1.0,pos=[5480.0,3100.0],target=quarry_index,aim=.2,
                                   cooldown=0.0,anger=quarry_index,anger_left=7.0,
                                   smash_clock=0.0,smash_left=0.0,smash_center=[0.0,0.0])
        finish['camera']=[4840.0,2800.0,.72]
        ready=load_fixture(finish)
        actor=ready['enemies'][0]
        n.check(actor['hp']==1 and actor['pos'][0]>5320 and not ready['victory'],
                'Rain kill fixture holds the final boss alive outside Hall and tower range')
        n.tap(720,505)
        n.tap(391,756)
        n.tap(*n.world_point(*actor['pos']))
        n.screen('09-rain-preview')
        n.check(n.save()['rain_cooldown']==0 and not n.save()['arrow_rains'],
                'Selecting and targeting Rain does not spend a cast')
        n.tap(1273,685)
        time.sleep(2)
        n.screen('10-rain-final-victory')
        won=n.save()
        n.check(won['victory'] and won['victory_seen'] and won['final_boss_defeated'] and won['rain_cooldown']>0,
                'Actual native Rain kills the final Warlord and opens victory')
        n.check(won['buildings'][0]['hp']>0 and not any(e.get('mission_boss') for e in won['enemies']),
                'Rain victory requires the final boss dead and Hall alive')
        n.tap(720,505)
        endless=pause()
        n.check(endless['elapsed']>won['elapsed'] and endless['victory'],
                'Endless survival resumes after Rain wins the mission')
        n.adb('shell','am','force-stop',n.PACKAGE)
        launch_continue()
        reloaded=pause()
        n.check(0<reloaded['rain_cooldown']<endless['rain_cooldown'],
                'Rain recharge survives another cold restart without resetting')
        log=n.adb('logcat','-d','-t','500','-v','brief',timeout=90)
        (n.OUT/'logcat.txt').write_text(log)
        n.check(not any(t in log for t in ['FATAL EXCEPTION','SCRIPT ERROR:','SHADER ERROR:','Shader compilation failed']),
                'Native diagnostics contain no script, shader or fatal error')
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
                'mode':'actual-v011-update-walls-miniboss-skills-and-rain',
                'fixtures':'Migration preserves the old economy and clears attackers. Later UI checks set a 1,000-resource budget, advance clocks to 299.95/899.95, reinforce walls, Workshop and quarry to level 100, disable Regeneration, and reposition enemies. The miniboss has 20,000 HP for repeatable skill captures. The final boss has one HP and is held at the quarry outside tower/Hall range for an actual Rain kill. These are controlled transition fixtures, not paid campaigns. The pre-fixture migrated settlement is restored.'}
        (n.OUT/'report.json').write_text(json.dumps(report,indent=2))
        print(json.dumps(report),flush=True)
    return 0 if report['passed'] else 1

if __name__=='__main__':sys.exit(run())
