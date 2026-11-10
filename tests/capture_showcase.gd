extends SceneTree
var game
func _init()->void:
 call_deferred("run")
func frame()->void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
func capture(name:String)->void:
 await frame()
 root.get_texture().get_image().save_png("res://test-results/frontier-"+name+".png")
func run()->void:
 root.size=Vector2i(1440,810)
 game=load("res://main.tscn").instantiate()
 root.add_child(game)
 await create_timer(2).timeout
 await capture("menu")
 game.start_mission()
 await capture("initial")
 # Explicit visual fixture; balance tests never grant these supplies.
 game.sim.resources={"wood":10000.0,"stone":10000.0,"gold":10000.0}
 for entry in [[Vector2(4496,3232),"wood"],[Vector2(5280,2880),"stone"],[Vector2(4976,2992),"market"],[Vector2(4512,2576),"arrow"],[Vector2(4720,3056),"cannon"],[Vector2(4384,2640),"wall"],[Vector2(4400,2720),"wall"],[Vector2(4368,2560),"wall"],[Vector2(4656,2528),"arrow"]]:
  var error:String=game.sim.build_at(entry[0],entry[1])
  if error!="": printerr("SHOWCASE PLACEMENT: ",entry," ",error)
 for b in game.sim.buildings:
  if b!=null: b.age=10
 game.camera_center=Vector2(4780,2820)
 game.apply_camera()
 game.sim.step(6)
 game.consume_events()
 await create_timer(1).timeout
 await capture("settlement")
 game.build_kind="cannon"
 game.ghost=Vector2(4770,2510).snapped(Vector2(16,16))
 await capture("placement")
 game.build_kind=""
 game.zoom=0.32
 game.camera_center=Vector2(4400,2600)
 game.apply_camera()
 await capture("overview")
 game.zoom=0.85
 game.camera_center=Vector2(6300,1850)
 game.apply_camera()
 await capture("lake")
 game.camera_center=Vector2(4780,2820)
 game.apply_camera()
 game.selected=1
 game.sim.buildings[1].hp=0
 game.sim.buildings[1].ruined_at=game.sim.elapsed
 await capture("ruins")
 game.act("pause")
 await capture("pause")
 game.act("settings")
 await capture("settings")
 game.music_player.stop()
 game.sfx_player.stop()
 game.music_player.stream=null
 game.sfx_player.stream=null
 game.sounds.clear()
 await create_timer(0.25).timeout
 game.queue_free()
 await process_frame
 await process_frame
 print("SHOWCASE COMPLETE")
 quit()
