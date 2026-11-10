extends SceneTree
var game
func _init()->void:call_deferred("run")
func settle()->void:
 for i in 4: await process_frame
 await RenderingServer.frame_post_draw
func run()->void:
 root.size=Vector2i(1280,800)
 game=load("res://main.tscn").instantiate()
 root.add_child(game)
 await create_timer(1).timeout
 game.set_process(false)
 game.music_player.stop()
 game.sound_on=false
 var sim=load("res://scripts/simulation.gd").new(17)
 sim.buildings.clear()
 sim.enemies.clear()
 game.sim=sim
 game.screen="mission"
 game.selected=-1
 game.build_kind=""
 game.fx.clear()
 game.zoom=0.15625
 game.camera_center=sim.World.SIZE/2
 game.visible=false
 var view:=SubViewport.new()
 view.size=Vector2i(1280,800)
 view.disable_3d=true
 view.world_2d=World2D.new()
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 var world=game.world
 world.reparent(view,false)
 world.visible=true
 world.scale=Vector2.ONE*0.15625
 world.position=Vector2.ZERO
 world.queue_redraw()
 await settle()
 world.queue_redraw()
 await settle()
 view.get_texture().get_image().save_png("res://assets/world/overview.png")
 var icon_view:=SubViewport.new()
 icon_view.size=Vector2i(192,160)
 icon_view.disable_3d=true
 icon_view.transparent_bg=true
 icon_view.world_2d=World2D.new()
 icon_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(icon_view)
 var icon:=Node2D.new()
 icon.set_script(load("res://tools/draw_wall_icon.gd"))
 icon.position=Vector2(100,127)
 icon.scale=Vector2.ONE*0.94
 icon_view.add_child(icon)
 icon.queue_redraw()
 await settle()
 icon_view.get_texture().get_image().save_png("res://assets/world/wall-icon.png")
 print("AUTHORED PREVIEW BAKED: overview1280x800 and wall icon192x160")
 game.queue_free()
 view.queue_free()
 icon_view.queue_free()
 await process_frame
 quit()
