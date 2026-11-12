extends SceneTree
var game
func _init()->void:call_deferred("run")
func capture(label:String)->void:
 game.toast_left=0
 game.apply_camera()
 game.queue_redraw()
 game.world.queue_redraw()
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/stronghold-"+label+".png")
func run()->void:
 DirAccess.make_dir_recursive_absolute("res://test-results")
 root.size=Vector2i(1440,810)
 game=load("res://main.tscn").instantiate()
 root.add_child(game)
 await create_timer(1).timeout
 game.start_mission()
 await process_frame
 game.set_process(false)
 game.world_container.visible=true
 game.world.visible=true
 game.world.configure_ground(game.sim.terrain_revision)
 game.music_player.stop()
 game.sound_on=false
 game.zoom=0.65
 game.camera_center=Vector2(4770,2830)
 await capture("catalogue")
 game.act("build:wood")
 game.ghost=game.sim.snap_position(Vector2(4380,3030),"wood")
 game.placement_ready=true
 await capture("green-sites")
 # This visual fixture grants resources; normal-cost balance runs are separate.
 game.sim.resources={"wood":10000.0,"stone":10000.0,"gold":10000.0}
 game.build_kind=""
 for entry in [[Vector2(4380,3030),"wood"],[Vector2(5150,3110),"stone"],[Vector2(4520,2560),"arrow"],[Vector2(5200,2800),"workshop"],[Vector2(4800,3280),"market"]]:
  var error:String=game.sim.build_at(entry[0],entry[1])
  if error!="":printerr("VISUAL PLACEMENT ",entry," ",error)
 game.sim.build_wall(game.sim.wall_line(Vector2(4200,2640),Vector2(4200,2960)))
 for b in game.sim.buildings:
  if b!=null:b.age=10
 game.selected=3
 await capture("inspector")
 game.act("workshop")
 game.research_kind="arrow"
 await capture("workshop")
 game.sim.start_research("arrow")
 game.sim.step_research(12)
 await capture("research")
 game.act("construction")
 game.sim.wave=5
 game.sim.spawn_remaining=game.sim.wave_size(5)
 var elite:Dictionary=game.sim.spawn_enemy()
 elite.pos=Vector2(4380,2800)
 await capture("elite")
 game.sim.enemies.clear()
 game.zoom=0.3
 game.camera_center=Vector2(2920,2770)
 game.act("build:stone")
 await capture("outposts")
 game.music_player.stream=null
 game.sfx_player.stream=null
 game.sounds.clear()
 game.queue_free()
 await process_frame
 await process_frame
 print("STRONGHOLD CAPTURE COMPLETE")
 quit()
