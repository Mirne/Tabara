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
 await press("advance_age")
 check(game.sim.settlement_age == 2 and game.camera_center == original_camera,"A single touch advances to Stone in place")
 for i in cost.size():
  var key: String = Sim.RESOURCE_NAMES[i]
  check(is_equal_approx(stock[key]-game.sim.resources[key],cost[i]),"Real opening price charged exactly once: "+key)
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
 await press("start_research")
 check(game.sim.track_level("cannon_splash") == 2 and game.sim.track_level("cannon_damage") == 1,
   "Cannon blast radius can be purchased independently")
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
 check(button("advance_age").is_empty(),"Crown has no invalid further upgrade")
 game.save_game()
 game.sim = null
 game.load_saved_game()
 check(game.sim != null and game.sim.settlement_age == 8 and game.sim.track_level("arrow_range") == 2 and
   game.sim.track_level("arrow_cadence") == 2 and game.sim.track_level("cannon_splash") == 2,
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
