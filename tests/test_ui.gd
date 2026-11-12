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
func visible_action(name:String)->bool:
 for b in game.buttons:
  if b.action==name:return true
 return false
func count_green(image:Image,area:Rect2i)->int:
 var count:=0
 for y in range(area.position.y,area.end.y,3):
  for x in range(area.position.x,area.end.x,3):
   var c:=image.get_pixel(x,y)
   if c.g>c.r*1.2 and c.g>c.b*1.15 and c.g>0.3:count+=1
 return count
func run()->void:
 DirAccess.make_dir_recursive_absolute("res://test-results")
 root.size=Vector2i(1440,810)
 game=load("res://main.tscn").instantiate()
 root.add_child(game)
 await create_timer(1).timeout
 await frame()
 check(game.screen=="menu","Application starts in menu")
 check(game.world!=null and game.music_player.stream.loop,"World and looping audio initialize")
 await action("credits")
 check(game.screen=="credits" and game.license_label.visible,"Credits retain engine and font notices")
 await action("back")
 game.save_available=false
 await frame()
 await action("new")
 check(game.screen=="briefing","New settlement opens the mission briefing")
 await action("start")
 check(game.screen=="mission" and game.sim.terrain_revision==4,"Mission selects the limited-resource stronghold")
 check(game.sim.enemies.size()>0 and game.sim.enemies[0].progress<100 and game.sim.enemies[0].pos.x<400,"The first enemy starts at the entrance")
 check(game.selected==-1 and visible_action("build:workshop"),"Initial panel shows the full construction catalogue")
 var big_cards:=true
 for b in game.buttons:
  if b.action.begins_with("build:") and (b.rect.size.y<140 or b.rect.size.x<140):big_cards=false
 check(big_cards,"All construction cards have larger mobile tap targets")
 var centered_art:=true
 for i in game.Art.BUILD_SIZES.size():
  var pos:=Vector2(500,500)
  var rect:Rect2=game.Art.building_rect(i,pos)
  if not (rect.position+rect.size*game.Art.BUILD_PIVOTS[i]).is_equal_approx(pos) or game.Art.dirt_rect(i,pos).get_center()!=pos:centered_art=false
 check(centered_art,"Workshop and existing buildings share their centered ground footprints")
 await capture("catalogue")
 game.camera_center=Vector2(4770,2900)
 game.apply_camera()
 await action("build:wood")
 check(not visible_action("build:stone") and visible_action("confirm_build"),"Selecting a build tool replaces the catalogue with placement controls")
 var stock:Dictionary=game.sim.resources.duplicate()
 var build_count:int=game.sim.active_building_count()
 await tap(game.world_to_screen(Vector2(4380,3030)))
 check(game.placement_ready and game.sim.active_building_count()==build_count,"Map tap previews without constructing")
 check(game.sim.resources.wood>=stock.wood,"The preview spends no supplies")
 await capture("green-wood")
 var image:Image=root.get_texture().get_image()
 var center:Vector2=game.world_to_screen(game.sim.snap_position(Vector2(4380,3030),"wood"))
 var pixels:=Rect2i(Vector2i(center-Vector2(65,65)),Vector2i(130,130))
 check(count_green(image,pixels)>50,"Available wood sites render filled green tiles and their rectangle")
 await action("cancel")
 check(game.sim.active_building_count()==build_count and visible_action("build:stone"),"Cancel returns to the catalogue without spending")
 await action("build:wood")
 await tap(game.world_to_screen(Vector2(4380,3030)))
 await action("confirm_build")
 check(game.sim.buildings[1].kind=="wood" and not visible_action("build:stone"),"Confirmed building selection hides the construction catalogue")
 check(visible_action("repair") and visible_action("workshop") and not visible_action("upgrade"),"Selected buildings expose local repair and Workshop navigation, not individual upgrades")
 var repair_button:=Rect2()
 for b in game.buttons:
  if b.action=="repair":repair_button=b.rect
 check(repair_button.size.y>=60 and repair_button.size.x>=300,"Selected-building buttons have large mobile tap targets")
 await action("construction")
 await action("build:stone")
 await tap(game.world_to_screen(Vector2(5150,3110)))
 await capture("green-stone")
 image=root.get_texture().get_image()
 center=game.world_to_screen(game.sim.snap_position(Vector2(5150,3110),"stone"))
 pixels=Rect2i(Vector2i(center-Vector2(65,65)),Vector2i(130,130))
 check(count_green(image,pixels)>50,"Available quarry sites render green placement tiles")
 await action("confirm_build")
 check(game.sim.buildings[2].kind=="stone","A quarry is constructed only after confirmation")
 await action("construction")
 # Controlled supplies isolate UI behavior from campaign balancing.
 game.sim.resources={"wood":10000.0,"stone":10000.0,"gold":10000.0}
 await action("build:arrow")
 var touch_site:Vector2=game.world_to_screen(Vector2(4520,2560))
 touch(0,touch_site,true)
 await frame()
 touch(0,touch_site,false)
 await frame()
 check(game.placement_ready and game.sim.active_building_count()==3,"Native touch previews a tower before confirmation")
 check(game.world.preview_range==game.Sim.DEFINITIONS.arrow.range,"Tower placement shows attack range")
 await action("confirm_build")
 check(game.sim.buildings[3].kind=="arrow","Native touch confirms the snapped tower")
 game.sim.buildings[3].age=10
 game.sim.buildings[3].hp=100
 await frame()
 var hp:float=game.sim.buildings[3].hp
 await action("repair")
 check(game.sim.buildings[3].repair_left>0 and game.sim.buildings[3].hp<hp+100,"Local repair begins a timed order")
 game.sim.enemies.clear()
 game.sim.spawn_remaining=0
 game.sim.step(9)
 await frame()
 check(is_equal_approx(game.sim.buildings[3].hp,game.sim.stat(game.sim.buildings[3],"hp")),"Local repair reaches full health")
 await action("construction")
 await action("build:workshop")
 await tap(game.world_to_screen(Vector2(5200,2800)))
 await action("confirm_build")
 check(game.sim.buildings[4].kind=="workshop" and visible_action("research:arrow"),"Workshop selection opens the global research panel")
 game.sim.enemies.clear()
 game.sim.spawn_remaining=0
 game.sim.step(7)
 await frame()
 await action("research:arrow")
 await capture("workshop")
 await action("start_research")
 check(not game.sim.research_job.is_empty() and game.sim.buildings[3].level==1,"Workshop starts timed research without an instant upgrade")
 await capture("research")
 game.sim.step_research(36)
 await frame()
 check(game.sim.buildings[3].level==2,"Completed Workshop research updates the existing tower")
 await action("workshop_building")
 check(visible_action("repair") and not visible_action("research:arrow"),"Workshop building tab retains its own local repair controls")
 await action("workshop")
 check(visible_action("research:stone"),"Workshop navigation returns to research")
 # Trading quotes and disabled states follow the real 90-gold purchase/cooldown.
 check(game.sim.build_at(Vector2(6100,2800),"market")=="","Trade fixture builds a paid marketplace")
 var market_index:int=game.sim.buildings.size()-1
 game.sim.buildings[market_index].age=10
 game.selected=market_index
 game.sim.resources.gold=89
 await frame()
 await action("trade")
 for control in game.buttons:
  if control.action in ["buy_wood","buy_stone"]: check(not control.enabled,"Purchase is disabled below its quoted 90 gold")
 game.sim.resources.gold=90
 var timber_before:float=game.sim.resources.wood
 await frame()
 await action("buy_wood")
 check(game.sim.resources.gold==0 and game.sim.resources.wood==timber_before+60,"Purchase spends exactly 90 gold for 60 timber")
 await frame()
 for control in game.buttons:
  if control.action.begins_with("trade_"): check(not control.enabled,"Sale controls respect the shared order cooldown")
 await action("back")
 game.sim.clear_at(market_index)
 game.selected=-1
 game.sim.resources={"wood":10000.0,"stone":10000.0,"gold":10000.0}
 await frame()
 # Wall gestures preserve preview/confirmation and shared endpoints.
 game.camera_center=Vector2(6200,2900)
 game.zoom=0.85
 game.apply_camera()
 await action("build:wall")
 var from:Vector2=game.world_to_screen(Vector2(6000,2800))
 var to:Vector2=game.world_to_screen(Vector2(6240,2800))
 var count:int=game.sim.active_building_count()
 touch(0,from,true)
 await frame()
 drag_touch(0,to,to-from)
 await frame()
 touch(0,to,false)
 await frame()
 check(game.wall_points.size()==4 and game.sim.active_building_count()==count,"Dragging walls previews four joined sections")
 await action("confirm_build")
 check(game.sim.active_building_count()==count+4,"One confirmation builds the entire wall stroke")
 var middle:int=game.sim.wall_at(Vector2(6080,2800))
 check(game.sim.wall_neighbors(middle).size()==2,"Constructed wall sections join into one run")
 await capture("wall-run")
 # Destroyed structures vanish and the panel returns to construction.
 game.selected=3
 var destroyer:Dictionary=game.sim.spawn_enemy()
 destroyer.cooldown=0
 destroyer.damage=1e9
 game.sim.attack_building(destroyer,3)
 game.sim.enemies.clear()
 game.sim.step(0.05)
 await frame()
 check(game.sim.buildings[3]==null and visible_action("build:arrow") and not visible_action("repair"),"Destruction removes the building and its controls instead of showing rebuildable ruins")
 for expected in [2,5,10,1]:
  await action("speed")
  check(game.speed==expected,"Speed cycles through mobile-supported rates")
 check(not visible_action("guide") and not visible_action("zoom_in") and not visible_action("zoom_out"),"Unused guide and zoom buttons remain removed")
 game.speed=1
 var before_zoom:float=game.zoom
 touch(0,Vector2(400,300),true)
 touch(1,Vector2(700,300),true)
 await frame()
 drag_touch(1,Vector2(860,300),Vector2(160,0))
 await frame()
 touch(0,Vector2(400,300),false)
 touch(1,Vector2(860,300),false)
 await frame()
 check(game.zoom>before_zoom,"Two-finger pinch zoom remains available")
 var saved_count:int=game.sim.active_building_count()
 var saved_camera:Vector2=game.camera_center
 game.save_game()
 game.sim=null
 game.load_saved_game()
 check(game.sim!=null and game.sim.active_building_count()==saved_count and game.sim.research_levels.arrow==2,"Disk restore retains structures and global research")
 check(game.camera_center.is_equal_approx(saved_camera),"Disk restore retains camera position")
 game.apply_camera()
 await action("pause")
 var frozen:float=game.sim.elapsed
 await create_timer(0.25).timeout
 check(game.sim.elapsed==frozen,"Pause freezes the simulation")
 check(not quit_on_go_back,"Android Back remains handled by the game")
 game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 await create_timer(0.25).timeout
 check(game.screen=="mission" and game.sim.elapsed>frozen,"Hardware Back resumes from pause")
 game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 frozen=game.sim.elapsed
 await create_timer(0.25).timeout
 check(game.screen=="pause" and game.sim.elapsed==frozen,"Next hardware Back pauses combat")
 await action("settings")
 var sound:bool=game.sound_on
 await action("sound")
 check(game.sound_on!=sound,"Sound controls remain usable")
 await action("motion")
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
 check(game.screen=="victory","Fifteen-minute boundary opens victory")
 await action("endless")
 check(game.screen=="mission" and game.sim.victory_seen,"Endless play continues after victory")
 game.sim.buildings[0].hp=0
 game.sim.defeated=true
 await frame()
 check(game.screen=="defeat","Loss of the hall opens defeat")
 game.music_player.stop()
 game.sfx_player.stop()
 game.music_player.stream=null
 game.sfx_player.stream=null
 game.sounds.clear()
 await create_timer(0.2).timeout
 game.queue_free()
 await process_frame
 await process_frame
 print("UI RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
