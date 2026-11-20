extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
var game
var failures := 0
var checks := 0

func _init() -> void:
 call_deferred("run")

func check(ok: bool, text: String) -> void:
 checks += 1
 if not ok:
  printerr("FAIL AGE UI: ",text)
  failures += 1

func frame() -> void:
 game.queue_redraw()
 game.world.queue_redraw()
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw

func capture(name: String) -> Image:
 game.fx.clear()
 await frame()
 var image: Image = root.get_texture().get_image()
 image.save_png("res://test-results/age-ui-"+name+".png")
 return image

func tap(point: Vector2) -> void:
 for pressed in [true,false]:
  var touch := InputEventScreenTouch.new()
  touch.index = 0
  touch.position = point
  touch.pressed = pressed
  Input.parse_input_event(touch)
  await frame()

func button(action: String) -> Dictionary:
 for row in game.buttons:
  if row.action == action:
   return row
 return {}

func touch_event(finger:int,point:Vector2,down:bool,canceled:=false)->void:
 var event:=InputEventScreenTouch.new()
 event.index=finger
 event.position=point
 event.pressed=down
 event.canceled=canceled
 Input.parse_input_event(event)
 await frame()

func exercise_age_browsing()->void:
 var funds:Dictionary=game.sim.resources.duplicate()
 var camera:Vector2=game.camera_center
 var age:int=game.sim.settlement_age
 var zoom:float=game.zoom
 for index in 8:
  check(game.hall_preview_index==index,"Browse each building in world-art order")
  await press("next_age_painting")
 await press("previous_age_painting")
 check(game.hall_preview_index==7,"Previous wraps to Workshop")
 await press("next_age_painting")
 var advance:Vector2=button("advance_age").rect.get_center()
 await touch_event(3,advance,true)
 check(game.sim.resources==funds,"A held age purchase leaves supplies untouched")
 var drift:=InputEventScreenDrag.new()
 drift.index=3
 drift.position=advance-Vector2(400,0)
 drift.relative=Vector2(-400,0)
 Input.parse_input_event(drift)
 await frame()
 await touch_event(3,advance,false)
 await touch_event(3,advance,true)
 await touch_event(3,advance,false,true)
 await touch_event(1,Vector2(405,402),true)
 await touch_event(2,advance,true)
 check(game.touches.size()==1,"Panel contact stays outside a battlefield pinch")
 await touch_event(2,advance,false)
 await touch_event(1,Vector2(405,402),false,true)
 check(game.hall_preview_index==0 and game.sim.settlement_age==age and game.sim.resources==funds,
   "Browsing and canceled gestures never purchase an age")
 check(game.selected==0 and game.camera_center==camera and game.zoom==zoom,
   "Browsing and crossing the panel preserve the camera and selection")

func press(action: String) -> void:
 await frame()
 var control := button(action)
 check(not control.is_empty() and control.enabled,"Touch control available: "+action)
 if control.is_empty() or not control.enabled: return
 await tap(control.rect.get_center())

func build_producer(index: int) -> void:
 var node: Dictionary = game.sim.resource_nodes[index]
 await press("build:"+node.kind)
 var screen_pos: Vector2 = game.world_to_screen(node.pos)
 var touch_area := Rect2(screen_pos-Vector2(22,22),Vector2(44,44))
 var clear: bool = game.VIEW.encloses(touch_area) and not game.MINIMAP.intersects(touch_area)
 for control in game.buttons:
  if touch_area.intersects(control.rect):
   clear = false
 check(clear,"Opening camera leaves a full touch target on the "+node.kind+" site")
 await tap(screen_pos)
 check(game.placement_ready and game.ghost == node.pos,"Touch previews the designated "+node.kind+" site")
 await press("confirm_build")
 await press("select:"+node.kind)
 check(game.selected > 0 and game.sim.buildings[game.selected].kind == node.kind and not button("upgrade_local").is_empty(),
   "The existing producer opens directly for local investment")
 await press("construction")

func check_age_reveal() -> void:
 var hall: Dictionary = game.sim.buildings[0]
 check(is_zero_approx(game.age_reveal_progress(hall)), "The first paid frame still shows the standing Wood Hall")
 check(game.age_reveal_progress(game.sim.buildings[1]) == 1.0, "A producer under construction uses the new age directly")
 check(game.fx.all(func(effect): return effect.type != "age" and effect.get("text", "") != "Stone"),
   "The painting supplies age feedback without a floating construction label")
 await press("pause")
 game._process(0.3)
 check(is_zero_approx(game.age_reveal_progress(hall)), "Pause holds the visible architecture in place")
 await press("resume")
 var original_speed: int = game.speed
 game.speed = 10
 game._process(0.17)
 check(is_equal_approx(game.age_reveal_progress(hall), 0.17 / game.AGE_REVEAL_SECONDS),
   "The reveal advances in display seconds at 10x")
 game.speed = original_speed
 game.reduced_motion = true
 game._process(0.0)
 check(game.age_reveal_progress(hall) == 1.0 and game.previous_architecture.is_empty(),
   "Reduced motion resolves directly to the paid age and releases the old painting")
 game.reduced_motion = false

func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://test-results")
 root.size = Vector2i(1440,810)
 game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await frame()
 game.save_available = false
 await press("new")
 await press("start")
 game.sound_on = false
 game.set_process(false)
 game.reduced_motion = false
 await build_producer(0)
 await press("hall")
 await press("construction")
 await build_producer(1)
 await press("hall")
 check(game.selected == 0 and not button("advance_age").is_empty(),"Hall opens its age panel")
 var original_camera: Vector2 = game.camera_center
 var stock: Dictionary = game.sim.resources.duplicate()
 var cost: Array = game.sim.age_cost()
 await capture("wood-hall")
 await exercise_age_browsing()
 await press("advance_age")
 check(game.sim.settlement_age == 2 and game.camera_center == original_camera,"A single touch advances to Stone in place")
 for i in cost.size():
  var key: String = Sim.RESOURCE_NAMES[i]
  check(is_equal_approx(stock[key]-game.sim.resources[key],cost[i]),"Real opening price charged exactly once: "+key)
 await check_age_reveal()
 await capture("stone-hall")
 await press("hall_building")
 check(not button("upgrade_local").is_empty(),"Hall combat upgrade accessible from Building")
 await press("hall_age")
 await press("construction")
 await press("build:workshop")
 await tap(game.world_to_screen(Vector2(5200,2800)))
 await press("confirm_build")
 await press("cancel")
 game.sim.step(7)
 await tap(game.world_to_screen(Vector2(5200,2800)))
 await press("research:arrow")
 await press("track:arrow_range")
 # From this point a display fixture grants supplies to exercise every age.
 game.sim.resources = {"wood":1e8,"stone":1e8,"gold":1e8}
 await press("start_research")
 check(game.sim.track_level("arrow_range") == 2 and game.sim.track_level("arrow_damage") == 1,
   "Purchasing the selected arrow project changes only bow reach")
 await press("track:arrow_cadence")
 check(not button("start_research").is_empty() and not button("start_research").enabled,"The Iron project is visible and age locked")
 var locked_funds: Dictionary = game.sim.resources.duplicate()
 await tap(button("start_research").rect.get_center())
 check(game.sim.resources == locked_funds and game.sim.track_level("arrow_cadence") == 1,"Touching an age-locked quote leaves supplies and rank intact")
 await press("research:cannon")
 await press("track:cannon_splash")
 var project_rect: Rect2 = button("track:cannon_splash").rect
 await press("start_research")
 check(game.sim.track_level("cannon_splash") == 2 and game.sim.track_level("cannon_damage") == 1,
   "Cannon blast radius can be purchased independently")
 check(button("track:cannon_splash").rect == project_rect and project_rect.size.y >= 70,
   "The paid project retains its large touch target after purchase")
 await press("research:arrow")
 check(not button("start_research").enabled and button("start_research").caption == "Iron age required",
   "Returning to archery keeps the previously selected locked project")
 await press("research:cannon")
 await press("start_research")
 check(game.sim.track_level("cannon_splash") == 3 and game.sim.track_level("cannon_damage") == 1,
   "Returning to cannons retains the chosen branch for the next paid rank")
 await capture("stone-workshop")
 await press("hall")
 await press("advance_age")
 await capture("iron-hall")
 await press("construction")
 await tap(game.world_to_screen(Vector2(5200,2800)))
 await press("research:arrow")
 await press("track:arrow_cadence")
 await press("start_research")
 check(game.sim.track_level("arrow_cadence") == 2,"The same project unlocks in Iron")
 await capture("iron-workshop")
 await press("hall")
 for expected_age in range(4, Sim.AGE_NAMES.size()+1):
  await press("advance_age")
  check(game.sim.settlement_age == expected_age,"Single paid touch reaches "+Sim.AGE_NAMES[expected_age-1])
 await capture("crown-hall")
 await press("previous_age_painting")
 check(game.hall_preview_index==7,"The final age lets the player browse the Crown Workshop")
 check(button("advance_age").is_empty(),"Crown has no invalid further upgrade")
 game.save_game()
 game.sim = null
 game.load_saved_game()
 check(game.age_reveal_left == 0.0 and game.previous_architecture.is_empty(), "Reloaded game opens in its finished architecture")
 check(game.sim != null and game.sim.settlement_age == 8 and game.sim.track_level("arrow_range") == 2 and
   game.sim.track_level("arrow_cadence") == 2 and game.sim.track_level("cannon_splash") == 3,
   "On-disk reload restores Crown and the selected research branches")
 game.music_player.stop()
 game.sfx_player.stop()
 game.music_player.stream = null
 game.sfx_player.stream = null
 game.sounds.clear()
 await create_timer(0.25).timeout
 game.queue_free()
 await process_frame
 await process_frame
 print("AGE UI RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
