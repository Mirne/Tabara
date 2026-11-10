"""Verify hardware Back from a fresh activity with an existing saved mission.
Set ANDROID_ADB, ANDROID_ADB_PORT, and ANDROID_SERIAL for the test device.
This isolates Back input from emulator graphics-surface restoration after Home.
"""
import subprocess,time,json,io,os
from pathlib import Path
from PIL import Image
A=[os.environ.get('ANDROID_ADB','adb'),'-P',os.environ.get('ANDROID_ADB_PORT','5037'),'-s',os.environ.get('ANDROID_SERIAL','emulator-5554')]
O=Path(__file__).resolve().parents[1]/'test-results'/'android-foreground-back';O.mkdir(parents=True,exist_ok=True)
size=(1280,720)
checks=[]
def adb(*args,binary=False,timeout=180):
 r=subprocess.run(A+list(args),capture_output=True,timeout=timeout,check=True)
 return r.stdout if binary else r.stdout.decode().strip()
def check(ok,label):
 checks.append({'label':label,'passed':bool(ok)});print(('PASS: ' if ok else 'FAIL: ')+label,flush=True)
 if not ok:raise AssertionError(label)
def shot(name):
 global size
 b=adb('exec-out','screencap','-p',binary=True);(O/(name+'.png')).write_bytes(b);im=Image.open(io.BytesIO(b)).convert('RGB');size=im.size;return im
def color(im,x,y):
 w,h=im.size;s=min(w/1440,h/810);return im.getpixel((round((w-1440*s)/2+x*s),round((h-810*s)/2+y*s)))
def wait_frame(name,test):
 end=time.monotonic()+180
 while time.monotonic()<end:
  im=shot(name)
  if test(im):return im
  time.sleep(3)
 check(False,'Rendered frame: '+name)
def tap(x,y):
 w,h=size;s=min(w/1440,h/810);adb('shell','input','tap',str(round((w-1440*s)/2+x*s)),str(round((h-810*s)/2+y*s)));time.sleep(5)
def save():return json.loads(adb('shell','run-as','com.tabara.lasthearth','cat','files/settlement.json'))
started=time.monotonic();before=None;after=None;error=None
try:
 adb('shell','am','force-stop','com.tabara.lasthearth')
 adb('shell','am','start','-W','-n','com.tabara.lasthearth/com.godot.game.GodotAppLauncher')
 wait_frame('01-menu',lambda im: color(im,46,52)[0]>150 and color(im,46,52)[1]>100)
 check(True,'Fresh native activity renders menu')
 tap(220,520)
 wait_frame('02-mission',lambda im:color(im,500,50)[0]>180 and color(im,500,50)[1]>170)
 tap(1320,58)
 wait_frame('03-paused',lambda im:color(im,450,170)[0]>180 and color(im,450,170)[1]>170)
 check(True,'Saved mission reaches visible pause panel')
 before=save()['elapsed']
 adb('shell','input','keyevent','4');time.sleep(8)
 adb('shell','input','keyevent','4');time.sleep(3)
 after=save()['elapsed'];print('BACK CLOCKS',before,after,flush=True)
 check(after>before+.01,'Hardware Back resumes game clock')
 frozen=after;time.sleep(5)
 check(save()['elapsed']==frozen,'Next Back freezes game clock')
 shot('04-back-paused')
 log=adb('logcat','-d','-t','500','-v','brief',timeout=60);(O/'logcat.txt').write_text(log)
 check('SCRIPT ERROR:' not in log and 'FATAL EXCEPTION' not in log,'Captured native diagnostics contain no script error or fatal exception')
except Exception as e:
 error=str(e);print('ERROR',error,flush=True)
finally:
 report={'checks':checks,'passed':bool(checks) and all(c['passed'] for c in checks) and error is None,'before':before,'after':after,'error':error,'actual_seconds':time.monotonic()-started,'setup':'Fresh activity, existing saved mission; isolates Back from emulator background-surface restoration'}
 (O/'report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
