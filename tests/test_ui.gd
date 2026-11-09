extends SceneTree

var game
var checks := 0
var failures := 0

func _init() -> void:
 call_deferred("run")

func check(condition: bool, label: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  printerr("FAIL UI: "+label)

func frame() -> void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw

func capture(name: String) -> void:
 await frame()
 var image := root.get_texture().get_image()
 image.save_png("res://test-results/"+name+".png")

func tap(point: Vector2) -> void:
 var event := InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.position = point
 event.pressed = true
 Input.parse_input_event(event)
 await frame()
 event = InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.position = point
 event.pressed = false
 Input.parse_input_event(event)
 await frame()

func run() -> void:
 root.size = Vector2i(1440,810)
 game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await frame()
 check(game.sfx_player!=null and game.music_player!=null,"Scene initialization completes")
 if game.sfx_player==null or game.music_player==null:
  quit(1)
  return
 var terrain_image: Image = game.terrain_view.get_texture().get_image()
 check(terrain_image!=null and terrain_image.get_pixel(450,550).a>.9,"Cached terrain actually renders")
 check(game.screen=="menu","Starts at main menu")
 check(game.music_player.stream.loop,"Ambient soundtrack loops")
 await capture("01-menu")
 await tap(Vector2(350,656))
 check(game.screen=="credits","Credits button opens notices")
 check(game.license_label.visible and game.license_label.text.length()>1000,"Licenses are visible and included")
 await capture("11-credits")
 await tap(Vector2(710,615))
 check(game.screen=="menu","Credits returns to main menu")
 # Clean test profile guarantees a new-game action.
 game.save_available = false
 await frame()
 await tap(Vector2(220,520))
 check(game.screen=="briefing","Begin button opens mission briefing")
 await capture("02-briefing")
 await tap(Vector2(770,635))
 check(game.screen=="mission","Briefing launches mission")
 check(game.sim.enemies.size()>0,"Enemy visible immediately")
 await capture("03-mission-start")
 # Build using the real build bar followed by a map tap.
 await tap(Vector2(220,747))
 check(game.build_kind=="wood","Woodcutter tool selected from build bar")
 await tap(Vector2(335,242))
 check(game.sim.buildings[1]!=null and game.sim.buildings[1].kind=="wood","Touch placement constructs woodcutter")
 await tap(Vector2(440,747))
 await tap(Vector2(817,217))
 check(game.sim.buildings[2]!=null,"Touch placement constructs stonemason")
 await tap(Vector2(640,747))
 await tap(Vector2(425,342))
 check(game.sim.buildings[4]!=null,"Touch placement constructs arrow tower")
 game.sim.step(45)
 game.consume_events()
 game.selected = 4
 await capture("04-settlement")
 # Upgrade through the actual inspector button.
 var old_level: int = game.sim.buildings[4].level
 await tap(Vector2(1270,504))
 check(game.sim.buildings[4].level==old_level+1,"Inspector upgrades tower")
 game.sim.buildings[4].hp = 0
 await frame()
 await capture("05-ruins")
 await tap(Vector2(1260,595))
 check(game.sim.buildings[4].hp>0,"Inspector repairs ruined tower")
 var wood_before: float = game.sim.resources.wood
 await tap(Vector2(192,198))
 check(game.sim.resources.wood>wood_before+19,"Touch resource collection adds supplies")
 await tap(Vector2(1320,58))
 check(game.screen=="pause","Pause button works")
 var frozen: float = game.sim.elapsed
 await create_timer(.2).timeout
 check(game.sim.elapsed==frozen,"Pause stops simulation")
 await capture("06-pause")
 await tap(Vector2(510,587))
 check(game.screen=="settings","Pause opens settings")
 await capture("07-settings")
 await tap(Vector2(920,270))
 check(not game.sound_on,"Sound toggle works")
 await tap(Vector2(700,605))
 check(game.screen=="pause","Done returns to pause")
 await tap(Vector2(702,589))
 check(game.screen=="guide","Field guide opens")
 await capture("08-guide")
 game.go_back()
 game.act("resume")
 # Trigger the boundary in the visual app, preserving a valid simulation clock.
 game.sim.elapsed = 899.95
 game.sim.wave = 30
 game.sim.enemies.clear()
 game.sim.spawn_remaining = 0
 game.sim.victory = false
 game.sim.victory_seen = false
 game.accumulator = .1
 await frame()
 check(game.screen=="victory","Mission shows 15-minute victory overlay")
 await capture("09-victory")
 await tap(Vector2(730,516))
 check(game.screen=="mission" and game.sim.victory_seen,"Continue enters endless mode")
 game.sim.buildings[0].hp = 0
 game.sim.defeated = true
 await frame()
 check(game.screen=="defeat","Main hall defeat shows end screen")
 await capture("10-defeat")
 print("UI RESULT: %d checks, %d failures" % [checks,failures])
 game.music_player.stop()
 game.music_player.stream = null
 game.sfx_player.stop()
 game.sfx_player.stream = null
 await create_timer(.15).timeout
 game.queue_free()
 await process_frame
 quit(1 if failures>0 else 0)
