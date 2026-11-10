extends SceneTree
## Deliberately extreme rendering fixture; these are not normal campaign resources.
const Sim=preload("res://scripts/simulation.gd")
var game
var started:=0
var count:=0
var fps_total:=0.0
var fps_min:=10000.0
var peak_static:=0
var process_peak:=0.0
var finished:=false
var seconds_requested:=90.0
var freeze:=false
var draw_total:=0.0
var simulation_total:=0.0
var report_name:="frontier-stress"
func _init()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--seconds="): seconds_requested=float(arg.trim_prefix("--seconds="))
  if arg=="--freeze":
   freeze=true
   report_name="frontier-stress-render-only"
 call_deferred("run")
func run()->void:
 root.size=Vector2i(1280,720)
 game=load("res://main.tscn").instantiate()
 root.add_child(game)
 await create_timer(2).timeout
 game.start_mission()
 game.sound_on=false
 game.music_player.stop()
 game.sim.resources={"wood":1e12,"stone":1e12,"gold":1e12}
 var kinds:=["arrow","cannon","wall","wood","stone","market"]
 for y in range(192,5000,192):
  for x in range(192,8100,192):
   if game.sim.active_building_count()>=512: break
   game.sim.build_at(Vector2(x,y),kinds[(x/192+y/192)%kinds.size()])
 for b in game.sim.buildings:
  if b!=null: b.age=10
 game.sim.enemies.clear()
 var rng:=RandomNumberGenerator.new()
 rng.seed=7171
 for i in 1000:
  var e:Dictionary=game.sim.spawn_enemy(rng.randf_range(game.sim.total_length-1500,game.sim.total_length-50))
  e.hp=1e10
  e.max_hp=1e10
  e.damage=0.001
 game.sim.events.clear()
 if freeze: game.speed=0
 game.camera_center=Sim.World.HALL-Vector2(300,0)
 game.zoom=0.5
 game.apply_camera()
 started=Time.get_ticks_msec()
 process_frame.connect(tick)
 print("STRESS START: ",game.sim.active_building_count()," structures / ",game.sim.enemies.size()," enemies")
func tick()->void:
 if finished: return
 var seconds:float=(Time.get_ticks_msec()-started)/1000.0
 if seconds>10:
  count+=1
  var fps:float=Performance.get_monitor(Performance.TIME_FPS)
  fps_total+=fps
  draw_total+=game.world.last_draw_us/1000.0
  simulation_total+=game.last_simulation_us/1000.0
  fps_min=minf(fps_min,fps)
  peak_static=maxi(peak_static,int(Performance.get_monitor(Performance.MEMORY_STATIC)))
  process_peak=maxf(process_peak,Performance.get_monitor(Performance.TIME_PROCESS)*1000)
 if seconds>=seconds_requested:
  finished=true
  var data:={"fixture":"512 structures and 1000 high-health, low-damage enemies; unlimited supplies, not campaign balance","real_seconds":seconds,"structures":game.sim.active_building_count(),"enemies":game.sim.enemies.size(),"fps_cap":30,"minimum_fps_after_warmup":fps_min,"mean_sampled_fps_after_warmup":fps_total/maxi(1,count),"max_static_memory_bytes":peak_static,"max_process_ms":process_peak,"rendered_entities":game.world.drawn_entities}
  data.mean_world_draw_cpu_ms=draw_total/maxi(1,count)
  data.mean_simulation_cpu_ms=simulation_total/maxi(1,count)
  data.simulation_frozen=freeze
  var f:=FileAccess.open("res://test-results/"+report_name+".json",FileAccess.WRITE)
  f.store_string(JSON.stringify(data,"  "))
  f.close()
  print("STRESS RESULT ",JSON.stringify(data))
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/"+report_name+".png")
  game.music_player.stop()
  game.music_player.stream=null
  game.sfx_player.stream=null
  game.sounds.clear()
  await create_timer(0.25).timeout
  game.queue_free()
  await process_frame
  await process_frame
  quit()
