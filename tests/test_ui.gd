extends SceneTree
var game
var checks:=0
var failures:=0
func _init()->void:
 call_deferred("run")
func check(condition:bool,label:String)->void:
 checks+=1
 if not condition:
  failures+=1
  printerr("FAIL UI: ",label)
func frame()->void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
func capture(name:String)->void:
 await frame()
 root.get_texture().get_image().save_png("res://test-results/frontier-ui-"+name+".png")
func mouse_event(at:Vector2,pressed:bool)->void:
 var e:=InputEventMouseButton.new()
 e.button_index=MOUSE_BUTTON_LEFT
 e.position=at
 e.pressed=pressed
 Input.parse_input_event(e)
func tap(at:Vector2)->void:
 mouse_event(at,true)
 await frame()
 mouse_event(at,false)
 await frame()
func action(name:String)->void:
 await frame()
 for button in game.buttons:
  if button.action==name:
   check(button.enabled,"Enabled control: "+name)
   await tap(button.rect.get_center())
   return
 check(false,"Visible control: "+name)
func touch(index:int,at:Vector2,pressed:bool)->void:
 var e:=InputEventScreenTouch.new()
 e.index=index
 e.position=at
 e.pressed=pressed
 Input.parse_input_event(e)
func drag_touch(index:int,at:Vector2,relative:Vector2)->void:
 var e:=InputEventScreenDrag.new()
 e.index=index
 e.position=at
 e.relative=relative
 Input.parse_input_event(e)
func run()->void:
 root.size=Vector2i(1440,810)
 game=load("res://main.tscn").instantiate()
 root.add_child(game)
 await create_timer(1).timeout
 await frame()
 check(game.screen=="menu","Application starts in menu")
 check(game.world!=null and game.music_player.stream.loop,"World and looping audio initialize")
 var ground:Image=game.world.ground_view.get_texture().get_image()
 check(ground!=null and ground.get_size()==Vector2i(4096,2560),"Large terrain texture actually renders")
 check(ground.get_pixel(3250,800)!=ground.get_pixel(2400,1400),"Lake and meadow render distinct terrain")
 await capture("menu")
 await action("credits")
 check(game.screen=="credits" and game.license_label.visible and game.license_label.text.length()>1000,"Credits show engine and font notices")
 await action("back")
 game.save_available=false
 await frame()
 await action("new")
 check(game.screen=="briefing","New settlement opens briefing")
 await capture("briefing")
 await action("start")
 check(game.screen=="mission" and game.sim.enemies.size()>0 and game.sim.enemies[0].progress<game.sim.total_length*0.2,"Mission starts enemies at the path entrance")
 check(game.VIEW.end.x<=1152,"The construction rail sits to the right of the world")
 check(game.world.RESOURCE_SITES!=null and game.world.scenery.size()<1100,"Each forest and quarry uses one compact resource image")
 await capture("initial")
 game.camera_center=Vector2(4780,3000)
 game.apply_camera()
 await action("build:wood")
 var before_stock:Dictionary=game.sim.resources.duplicate()
 await tap(game.world_to_screen(Vector2(4380,3030)))
 check(game.sim.buildings.size()==1 and game.placement_ready,"A mobile tap previews without constructing")
 check(game.sim.resources.wood>=before_stock.wood,"Preview spends no resources")
 await capture("grid-preview")
 await action("cancel")
 check(game.sim.buildings.size()==1,"Cancel discards the preview without construction")
 await action("build:wood")
 await tap(game.world_to_screen(Vector2(4380,3030)))
 await action("confirm_build")
 check(game.sim.buildings.size()==2 and game.sim.buildings[1].kind=="wood","Real pointer input places a woodcutter on free ground")
 check(game.sim.buildings[1].pos==game.sim.snap_position(Vector2(4380,3030),"wood"),"Building uses chosen world position")
 await action("build:stone")
 await tap(game.world_to_screen(Vector2(5150,3110)))
 await action("confirm_build")
 check(game.sim.buildings.size()==3 and game.sim.buildings[2].kind=="stone","Pointer places stonemason without a fixed plot")
 await action("build:arrow")
 game.act("hall")
 await frame()
 var touch_count:int=game.sim.active_building_count()
 var touch_site:Vector2=game.world_to_screen(Vector2(4512,2576))
 touch(0,touch_site,true)
 await frame()
 touch(0,touch_site,false)
 await frame()
 check(game.placement_ready and game.sim.active_building_count()==touch_count,"Native-style touch only previews the snapped foundation")
 await action("cancel")
 await action("build:arrow")
 var count:int=game.sim.active_building_count()
 var before:Vector2=game.camera_center
 mouse_event(Vector2(750,310),true)
 await frame()
 var motion:=InputEventMouseMotion.new()
 motion.position=Vector2(900,350)
 motion.relative=Vector2(150,40)
 Input.parse_input_event(motion)
 await frame()
 mouse_event(Vector2(900,350),false)
 await frame()
 check(game.camera_center.distance_to(before)>100,"Mouse dragging pans the camera")
 check(game.sim.active_building_count()==count,"Camera drag never constructs a building")
 game.act("hall")
 await frame()
 await tap(game.world_to_screen(Vector2(4512,2576)))
 await action("confirm_build")
 check(game.sim.buildings.size()==4 and game.sim.buildings[3].kind=="arrow","Tower placement follows camera transform")
 game.act("cancel")
 game.selected=3
 game.sim.step(30)
 game.consume_events()
 await frame()
 var level:int=game.sim.buildings[3].level
 await action("upgrade")
 check(game.sim.buildings[3].level==level+1,"Inspector upgrades the selected structure")
 game.sim.buildings[3].hp=0
 game.sim.buildings[3].ruined_at=game.sim.elapsed
 await capture("ruins")
 await action("repair")
 check(game.sim.buildings[3].hp>0 and game.sim.buildings[3].level==level+1,"Inspector repairs ruins while retaining upgrades")
 await action("clear")
 check(game.screen=="dismantle","Removing a building requires the in-game confirmation")
 await action("cancel_clear")
 check(game.sim.buildings[3]!=null,"Cancel keeps the structure")
 await action("clear")
 await action("confirm_clear")
 check(game.sim.buildings[3]==null,"Confirmed dismantle completely frees the ground")
 await action("build:wall")
 await tap(game.world_to_screen(Vector2(4512,2576)))
 await action("confirm_build")
 check(game.sim.buildings[3]!=null and game.sim.buildings[3].kind=="wall","A different building fits on the freed foundation")
 await action("build:market")
 await tap(game.world_to_screen(Vector2(4976,2992)))
 await action("confirm_build")
 check(game.sim.buildings[4].kind=="market","Marketplace placement works")
 game.act("cancel")
 game.selected=4
 game.sim.step(3)
 game.sim.resources.gold=500
 await frame()
 await action("trade")
 check(game.screen=="trade","Selected marketplace opens trading")
 var frozen:float=game.sim.elapsed
 await create_timer(0.25).timeout
 check(game.sim.elapsed==frozen,"Trading pauses combat")
 var stock:float=game.sim.resources.stone
 var gold:float=game.sim.resources.gold
 await action("buy_stone")
 check(game.sim.resources.stone==stock+60 and game.sim.resources.gold==gold-60,"Buy button charges the stated price")
 stock=game.sim.resources.wood
 gold=game.sim.resources.gold
 await action("trade_wood")
 check(game.sim.resources.wood==stock-60 and game.sim.resources.gold==gold+30,"Sell button pays the stated amount")
 await capture("marketplace")
 await action("back")
 check(game.screen=="mission","Trade returns to the game")
 var resource_stock:Dictionary=game.sim.resources.duplicate()
 game.set_process(false)
 var free_gold:int=game.Map.GROVES.size()+game.Map.QUARRIES.size()
 await tap(game.world_to_screen(game.sim.resource_nodes[free_gold].pos))
 check(game.sim.resources==resource_stock,"Resource art has no tap-to-gather interaction")
 game.set_process(true)
 # The minimap routes input before world placement and reaches distant geography.
 var target:=Vector2(6500,1600)
 await tap(game.MINIMAP.position+target/game.Map.SIZE*game.MINIMAP.size)
 check(game.camera_center.distance_to(target)<2,"Minimap tap navigates to the distant lake")
 await capture("lake")
 await action("build:cannon")
 var safe_count:int=game.sim.active_building_count()
 await tap(game.world_to_screen(game.Map.LAKE_CENTER))
 var confirm_controls:Array=game.buttons.filter(func(b):return b.action=="confirm_build")
 check(confirm_controls.size()==1 and not confirm_controls[0].enabled,"Invalid water preview disables confirmation")
 if not confirm_controls.is_empty(): await tap(confirm_controls[0].rect.get_center())
 check(game.sim.active_building_count()==safe_count,"Tapping disabled confirmation spends no construction")
 await action("cancel")
 await action("hall")
 check(game.camera_center.distance_to(game.Map.HALL)<1,"Hall control recenters the settlement")
 var old_zoom:float=game.zoom
 await action("zoom_out")
 check(game.zoom<old_zoom,"Zoom-out control changes the view")
 await action("zoom_in")
 check(absf(game.zoom-old_zoom)<0.0001,"Zoom controls round trip")
 # Actual native-style two-finger events, with mouse emulation disabled.
 count=game.sim.active_building_count()
 old_zoom=game.zoom
 touch(0,Vector2(560,300),true)
 touch(1,Vector2(880,350),true)
 await frame()
 drag_touch(1,Vector2(980,370),Vector2(100,20))
 await frame()
 touch(0,Vector2(560,300),false)
 touch(1,Vector2(980,370),false)
 await frame()
 check(game.zoom>old_zoom,"Two-finger pinch zoom works")
 check(game.sim.active_building_count()==count,"Pinch never creates an accidental building")
 # One-finger panning must also suppress the release tap.
 before=game.camera_center
 touch(0,Vector2(700,350),true)
 await frame()
 drag_touch(0,Vector2(800,350),Vector2(100,0))
 await frame()
 touch(0,Vector2(800,350),false)
 await frame()
 check(game.camera_center.distance_to(before)>30,"One-finger drag pans")
 # A mobile wall stroke previews multiple joined cells and waits for confirmation.
 game.camera_center=Vector2(6200,3800)
 game.zoom=0.85
 game.apply_camera()
 game.sim.resources={"wood":1000.0,"stone":1000.0,"gold":1000.0}
 await action("build:wall")
 var wall_start:Vector2=game.world_to_screen(Vector2(6000,3680))
 var wall_end:Vector2=game.world_to_screen(Vector2(6240,3680))
 var wall_count:int=game.sim.active_building_count()
 var wall_camera:Vector2=game.camera_center
 touch(0,wall_start,true)
 await frame()
 drag_touch(0,wall_end,wall_end-wall_start)
 await frame()
 touch(0,wall_end,false)
 await frame()
 check(game.wall_points.size()==4 and game.sim.active_building_count()==wall_count,"Dragging a wall previews four pieces without spending")
 check(game.camera_center==wall_camera,"A wall drag draws instead of panning")
 await capture("wall-preview")
 await action("confirm_build")
 check(game.sim.active_building_count()==wall_count+4,"One confirmation builds the whole wall stroke")
 var last_wall:int=game.sim.wall_at(Vector2(6080,3680))
 check(last_wall>=0 and game.sim.wall_neighbors(last_wall).size()==2,"Built wall pieces form a continuous joined run")
 game.sim.step(3)
 await capture("joined-wall")
 await action("build:wall")
 var turn_end:Vector2=game.world_to_screen(Vector2(6240,3920))
 touch(0,wall_end,true)
 await frame()
 drag_touch(0,turn_end,turn_end-wall_end)
 await frame()
 touch(0,turn_end,false)
 await frame()
 check(game.sim.wall_preview(game.wall_points).count==3,"Corner extension reuses the existing wall endpoint")
 await action("confirm_build")
 var corner:int=game.sim.wall_at(Vector2(6240,3680))
 check(game.sim.wall_neighbors(corner).size()==2,"Perpendicular wall strokes join at the corner")
 game.sim.step(3)
 await capture("wall-corner")
 # View state and model state both survive actual filesystem persistence.
 var saved_camera:Vector2=game.camera_center
 var saved_zoom:float=game.zoom
 var saved_count:int=game.sim.active_building_count()
 game.save_game()
 game.sim=null
 game.camera_center=Vector2.ZERO
 game.zoom=0.3
 game.load_saved_game()
 check(game.sim!=null and game.sim.active_building_count()==saved_count,"Cold file restore retains free-placed structures")
 check(game.camera_center==saved_camera and absf(game.zoom-saved_zoom)<0.00001,"Cold restore retains camera and zoom")
 game.apply_camera()
 await capture("settlement")
 await action("pause")
 frozen=game.sim.elapsed
 await create_timer(0.25).timeout
 check(game.sim.elapsed==frozen,"Pause freezes the simulation")
 check(not get_tree_auto_quit(),"Android Back is handled by the game")
 game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 await create_timer(0.25).timeout
 check(game.screen=="mission" and game.sim.elapsed>frozen,"System Back resumes from pause")
 game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 frozen=game.sim.elapsed
 await create_timer(0.25).timeout
 check(game.screen=="pause" and game.sim.elapsed==frozen,"Next system Back pauses")
 await action("settings")
 var sound:bool=game.sound_on
 await action("sound")
 check(game.sound_on!=sound,"Sound setting toggles")
 var motion_reduced:bool=game.reduced_motion
 await action("motion")
 check(game.reduced_motion!=motion_reduced,"Reduced-motion setting toggles")
 await capture("settings")
 await action("back")
 check(game.screen=="pause","Settings returns to pause")
 await action("guide")
 check(game.screen=="guide","Field manual opens")
 await capture("guide")
 await action("back")
 await action("resume")
 game.sim.elapsed=899.95
 game.sim.wave=30
 game.sim.enemies.clear()
 game.sim.spawn_remaining=0
 game.sim.victory=false
 game.sim.victory_seen=false
 game.accumulator=0.1
 await frame()
 check(game.screen=="victory","Exact mission boundary opens victory screen")
 await capture("victory")
 await action("endless")
 check(game.screen=="mission" and game.sim.victory_seen,"Continue enters endless survival")
 game.sim.buildings[0].hp=0
 game.sim.defeated=true
 await frame()
 check(game.screen=="defeat","Destroyed main hall opens defeat screen")
 await capture("defeat")
 game.music_player.stop()
 game.sfx_player.stop()
 game.music_player.stream=null
 game.sfx_player.stream=null
 game.sounds.clear()
 await create_timer(0.25).timeout
 game.queue_free()
 await process_frame
 await process_frame
 print("UI RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures>0 else 0)
func get_tree_auto_quit()->bool:
 return quit_on_go_back
