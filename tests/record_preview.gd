extends SceneTree
## Scripted visual tour from an actual normal-cost campaign snapshot.
const Sim=preload("res://scripts/simulation.gd")
const Bot=preload("res://tests/player_bot.gd")
var game
var bot
var started:=0
var stage:=-1
var paid_at:=0
var finished:=false
const SITE=Vector2(4720,3440)
func _init()->void:
 call_deferred("run")
func run()->void:
 root.size=Vector2i(1280,720)
 game=load("res://main.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 game.sim=Sim.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/frontier-preview.json")))
 if game.sim==null:
  printerr("Preview snapshot failed validation")
  quit(1)
  return
 game.screen="mission"
 game.sound_on=false
 game.music_on=false
 game.reduced_motion=false
 game.world.water.material.set_shader_parameter("motion_rate",1.0)
 game.music_player.stop()
 game.selected=-1
 game.toast_left=0
 game.zoom=0.48
 game.camera_center=Vector2(4750,3100)
 game.apply_camera()
 bot=Bot.new(game.sim)
 # Warm up through ordinary paid actions so the next horde is in view.
 for second in 30:
  bot.act()
  game.sim.step(1)
  game.sim.events.clear()
 game.animation_clock=game.sim.elapsed
 game.world.queue_redraw()
 game.queue_redraw()
 await create_timer(1).timeout
 print("PREVIEW READY")
 while not FileAccess.file_exists("/tmp/tabara-frontier-preview.start"):
  await create_timer(0.05).timeout
 started=Time.get_ticks_msec()
 game.set_process(true)
 process_frame.connect(tick)
func tick()->void:
 if finished: return
 var now:=Time.get_ticks_msec()
 var t:float=(now-started)/1000.0
 if t<5:
  game.zoom=0.48
  game.camera_center=Vector2(4750,3100)
 elif t<10:
  game.zoom=lerpf(0.48,0.72,clampf((t-5)/2,0,1))
  game.camera_center=Vector2(4750,3100)
 elif t<17:
  game.zoom=0.72
  game.camera_center=Vector2(4750,3100)
 elif t<25:
  var p:float=clampf((t-17)/4,0,1)
  game.zoom=lerpf(0.72,0.28,p)
  game.camera_center=Vector2(4750,3100).lerp(Vector2(2700,2400),p)
 elif t<31:
  var p:float=clampf((t-25)/3,0,1)
  game.zoom=lerpf(0.28,0.55,p)
  game.camera_center=Vector2(2700,2400).lerp(Vector2(6350,1750),p)
 else:
  var p:float=clampf((t-31)/3,0,1)
  game.zoom=lerpf(0.55,0.57,p)
  game.camera_center=Vector2(6350,1750).lerp(Vector2(4600,2780),p)
 game.apply_camera()
 if stage<0 and t>=5:
  game.act("build:cannon")
  game.ghost=SITE
  stage=0
 if stage==0 and t>=7:
  game.click_world(game.world_to_screen(SITE))
  game.act("confirm_build")
  stage=1
 if stage==1 and t>=10:
  game.act("upgrade")
  stage=2
 if stage==2 and t>=13:
  game.act("clear")
  stage=3
 if stage==3 and t>=14.5:
  game.act("confirm_clear")
  game.toast_left=0
  stage=4
 if t>17 and now>=paid_at and game.screen=="mission":
  paid_at=now+1000
  bot.act()
 if game.screen=="victory": game.act("endless")
 if t>=39.8:
  finished=true
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/frontier-preview-final.png")
  game.music_player.stop()
  game.sfx_player.stop()
  game.music_player.stream=null
  game.sfx_player.stream=null
  game.sounds.clear()
  await create_timer(0.25).timeout
  game.queue_free()
  await process_frame
  await process_frame
  print("PREVIEW COMPLETE")
  quit()
