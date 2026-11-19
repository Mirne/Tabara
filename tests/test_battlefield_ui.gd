extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var game
var checks:=0
var failures:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures+=1
  printerr("FAIL BATTLEFIELD UI: ",label)
func frame()->void:
 game.world.queue_redraw()
 game.queue_redraw()
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
func capture(name:String)->Image:
 await frame()
 var image:Image=root.get_texture().get_image()
 image.save_png("res://test-results/battlefield-"+name+".png")
 return image
func tap(at:Vector2)->void:
 for pressed in [true,false]:
  var event:=InputEventScreenTouch.new()
  event.index=0
  event.position=at
  event.pressed=pressed
  Input.parse_input_event(event)
  await frame()
func touch(index:int,at:Vector2,pressed:bool)->void:
 var event:=InputEventScreenTouch.new()
 event.index=index
 event.position=at
 event.pressed=pressed
 Input.parse_input_event(event)
func drag(index:int,at:Vector2,relative:Vector2)->void:
 var event:=InputEventScreenDrag.new()
 event.index=index
 event.position=at
 event.relative=relative
 Input.parse_input_event(event)
func action(name:String)->void:
 await frame()
 for control in game.buttons:
  if control.action==name:
   check(control.enabled,"Enabled mobile ability control: "+name)
   await tap(control.rect.get_center())
   return
 check(false,"Visible mobile ability control: "+name)
func red_pixels(image:Image,area:Rect2i)->int:
 var count:=0
 for y in range(area.position.y,area.end.y,2):
  for x in range(area.position.x,area.end.x,2):
   var color:=image.get_pixel(x,y)
   if color.r>color.g*1.3 and color.r>color.b*1.3 and color.r>0.55:count+=1
 return count
func run()->void:
 root.size=Vector2i(1440,810)
 DirAccess.make_dir_recursive_absolute("res://test-results")
 game=load("res://main.tscn").instantiate()
 root.add_child(game)
 await frame()
 game.set_process(false)
 game.music_player.stop()
 game.music_player.stream=null
 game.sound_on=false
 game.sim=Sim.new(125)
 game.sim.resources={"wood":100000.0,"stone":100000.0,"gold":100000.0}
 game.sim.enemies.clear()
 game.sim.spawn_remaining=0
 game.sim.elapsed=300
 game.sim.wave=11
 game.sim.boss_intervals=1
 for y in [2740,2780,2820,2860,2900]:
  check(game.sim.build_at(Vector2(6260,y),"wall")=="","Boss render fixture uses legal single-cell walls")
 for building in game.sim.buildings:
  if building!=null:building.age=10
 game.sim.events.clear()
 var boss:Dictionary=game.sim.spawn_enemy(0,"boss")
 boss.pos=Vector2(6200,2820)
 boss.smash_clock=3.0
 var ally:Dictionary=game.sim.spawn_enemy(0,"elite")
 ally.pos=Vector2(6070,2760)
 game.screen="mission"
 game.selected=-1
 game.build_kind=""
 game.camera_center=Vector2(6200,2820)
 game.zoom=1.0
 game.apply_camera()
 game.world_container.visible=true
 game.sim.step(0.05)
 game.animation_clock=game.sim.elapsed
 check(ally.rallied,"Rendered battle marks an ally inside the passive war cry")
 var normal:Image=await capture("war-cry")
 boss.cooldown=0
 boss.smash_clock=0
 game.sim.attack_building(boss,3)
 var warning:Image=await capture("smash-warning")
 var center:Vector2=game.world_to_screen(boss.smash_center)
 var area:=Rect2i(Vector2i(center-Vector2(170,170)),Vector2i(340,340))
 check(red_pixels(warning,area)>red_pixels(normal,area)+100,"Actual viewport draws a clear red smash warning circle")
 var old_health:float=game.sim.buildings[2].hp
 game.sim.step(0.65)
 game.consume_events()
 game.animation_clock=game.sim.elapsed
 var has_impact:=false
 for effect in game.fx:
  if effect.type=="smash":
   effect.time=0.5
   has_impact=true
 check(has_impact and game.sim.buildings[2].hp<old_health,"Real area damage creates the visible impact effect")
 var impact:Image=await capture("smash-impact")
 check(impact.get_data()!=warning.get_data(),"Hammer impact changes the rendered scene after its warning")
 # Isolated visual fixture uses the starting recharge.
 var release_period:float=Sim.Abilities.rain_recharge_seconds
 Sim.Abilities.rain_recharge_seconds=60
 game.sim=Sim.new(126)
 game.fx.clear()
 game.sim.enemies.clear()
 game.sim.spawn_remaining=0
 game.sim.events.clear()
 var victim:Dictionary=game.sim.spawn_enemy(0,"elite")
 victim.pos=Vector2(6200,2820)
 victim.hp=5000
 victim.max_hp=5000
 await action("rain")
 check(game.ability_mode and not game.ability_placed and game.sim.rain_cooldown==0,"Selecting Rain opens targeting without casting")
 await tap(game.world_to_screen(victim.pos))
 check(game.ability_placed and game.sim.arrow_rains.is_empty(),"One mobile battlefield tap previews rather than casting")
 await capture("rain-preview")
 var target:Vector2=game.ability_target
 var camera:Vector2=game.camera_center
 touch(0,Vector2(700,460),true)
 await frame()
 drag(0,Vector2(780,460),Vector2(80,0))
 await frame()
 touch(0,Vector2(780,460),false)
 await frame()
 check(game.camera_center!=camera and game.ability_target==target and game.sim.rain_cooldown==0,"One-finger panning keeps the target without spending a cast")
 game.camera_center=camera
 game.apply_camera()
 var zoom:float=game.zoom
 touch(0,Vector2(500,400),true)
 touch(1,Vector2(700,400),true)
 await frame()
 drag(1,Vector2(740,400),Vector2(40,0))
 await frame()
 touch(1,Vector2(740,400),false)
 touch(0,Vector2(500,400),false)
 await frame()
 check(game.zoom>zoom and game.ability_target==target and game.sim.arrow_rains.is_empty(),"Pinch zoom preserves the pending circle without casting")
 game.camera_center=camera
 game.zoom=zoom
 game.apply_camera()
 game.go_back()
 check(not game.ability_mode and game.sim.rain_ready(),"Back cancels the target without consuming recharge")
 await action("build:wall")
 await action("rain")
 check(game.build_kind=="" and not game.wall_drawing,"Selecting Rain cleanly leaves wall construction")
 await tap(game.world_to_screen(victim.pos))
 await action("confirm_rain")
 check(not game.ability_mode and game.sim.arrow_rains.size()==1 and game.sim.rain_cooldown==60,"Separate mobile confirmation releases one barrage")
 game.sim.step(0.3)
 game.animation_clock=game.sim.elapsed
 var rain_image:Image=await capture("rain-falling")
 check(rain_image.get_data()!=normal.get_data(),"Actual viewport draws the airborne barrage")
 game.act("pause")
 game.set_process(true)
 var paused:float=game.sim.rain_cooldown
 await create_timer(0.2).timeout
 await frame()
 check(game.sim.rain_cooldown==paused,"Pause freezes the active recharge")
 var could_cast:=false
 for control in game.buttons:
  if control.action=="confirm_rain" and control.enabled:could_cast=true
 check(not could_cast,"Paused overlay cannot activate the underlying cast control")
 game.act("resume")
 game.sim.step(0.3)
 check(game.sim.enemies[0].hp<5000,"Rendered falling arrows accompany actual simulation damage")
 game.set_process(false)
 Sim.Abilities.rain_recharge_seconds=release_period
 game.music_player.stop()
 game.sfx_player.stop()
 game.music_player.stream=null
 game.sfx_player.stream=null
 game.sounds.clear()
 await create_timer(0.2).timeout
 game.queue_free()
 await process_frame
 await process_frame
 print("BATTLEFIELD UI RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
