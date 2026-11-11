extends SceneTree
const Bot=preload("res://tests/player_bot.gd")
var game
func _init()->void:call_deferred("run")
func capture(label:String)->void:
 game.apply_camera()
 game.queue_redraw()
 game.world.queue_redraw()
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/woodland-"+label+".png")
func run()->void:
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
 game.camera_center=Vector2(4740,2830)
 await capture("initial")
 var bot=Bot.new(game.sim)
 for second in 93:
  bot.act()
  game.sim.step(1)
  game.sim.events.clear()
 game.fx.clear()
 await capture("settlement")
 game.build_kind="cannon"
 game.ghost=Vector2(4460,2880)
 await capture("range")
 game.build_kind="wall"
 game.ghost=Vector2(4120,2360)
 await capture("blocked")
 game.build_kind=""
 game.zoom=0.6
 game.camera_center=Vector2(6900,2420)
 await capture("shore")
 game.camera_center=Vector2(1800,2650)
 await capture("approach")
 game.music_player.stream=null
 game.sfx_player.stream=null
 game.sounds.clear()
 game.queue_free()
 await process_frame
 await process_frame
 print("WOODLAND CAPTURE COMPLETE")
 quit()
