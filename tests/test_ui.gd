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
 await action("credits")
 check(game.license_label.visible,"Credits retain engine and font notices")
 await action("back")
 game.save_available=false
 await frame()
 await action("new")
 check(game.screen=="briefing","New settlement opens the briefing")
 await action("start")
 check(game.screen=="mission" and game.sim.terrain_revision==5,"Mission selects the open approach")
 check(game.sim.enemies[0].progress<100 and game.sim.enemies[0].pos.x<400,"Enemies start at the western entrance")
 check(game.selected==-1 and visible_action("build:workshop"),"Initial catalogue shows all construction tools")
 var big:=true
 for control in game.buttons:
  if control.action.begins_with("build:") and (control.rect.size.y<140 or control.rect.size.x<140):big=false
 check(big,"Construction cards keep large mobile targets")
 await capture("catalogue")
 await action("build:wood")
 check(game.toast=="","Selecting a construction tool adds no tutorial toast")
 check(not visible_action("build:stone") and visible_action("confirm_build"),"Selecting a tool replaces the catalogue")
 var stock:Dictionary=game.sim.resources.duplicate()
 await tap(game.world_to_screen(Vector2(4760,2440)))
 check(game.placement_ready and game.sim.active_building_count()==1,"A tap previews without construction")
 check(game.sim.resources.wood>=stock.wood,"Preview spends no supplies")
 await capture("green-wood")
 var image:Image=root.get_texture().get_image()
 var center:Vector2=game.world_to_screen(Vector2(4760,2440))
 check(count_green(image,Rect2i(Vector2i(center-Vector2(65,65)),Vector2i(130,130)))>50,"Producer sites show filled green tiles")
 await action("confirm_build")
 check(game.build_kind=="wood" and game.selected==-1 and not game.placement_ready,"Construction keeps the tool active without selecting the new building")
 check(not visible_action("repair") and not visible_action("build:stone"),"Placement stays in its full-size mobile panel")
 await action("cancel")
 await action("build:stone")
 await tap(game.world_to_screen(Vector2(5480,3240)))
 await action("confirm_build")
 check(game.sim.buildings[2].kind=="stone" and game.build_kind=="stone","Quarry placement also remains active")
 await action("cancel")
 # Explicit UI fixture supplies; normal-cost campaign checks are separate.
 game.sim.resources={"wood":100000.0,"stone":100000.0,"gold":100000.0}
 game.camera_center=Vector2(6120,2840)
 game.apply_camera()
 await action("build:arrow")
 var sites:Array=[]
 for y in range(2600,3081,120):
  for x in range(5800,6281,120):
   if game.sim.placement_error(Vector2(x,y),"arrow")=="":sites.append(Vector2(x,y))
 check(sites.size()>=15,"Repeat-placement fixture has fifteen legal foundations")
 for i in 15:
  await tap(game.world_to_screen(sites[i]))
  check(game.placement_ready and game.world.preview_range>0,"Repeated tower preview shows range")
  await action("confirm_build")
  check(game.build_kind=="arrow" and game.selected==-1 and not game.placement_ready,"Tower %d keeps construction active"%(i+1))
 check(game.sim.active_building_count()==18,"Fifteen towers use one tool selection and fifteen preview/confirm pairs")
 await action("cancel")
 game.selected=3
 await frame()
 check(not visible_action("repair") and visible_action("workshop"),"Building inspector has no manual repair button")
 game.camera_center=Vector2(4840,2800)
 game.apply_camera()
 await action("construction")
 await action("build:workshop")
 await tap(game.world_to_screen(Vector2(5200,2800)))
 await action("confirm_build")
 var workshop_index:int=game.sim.buildings.size()-1
 check(game.build_kind=="workshop" and game.selected==-1,"Workshop placement does not auto-select it")
 await action("cancel")
 game.sim.enemies.clear()
 game.sim.spawn_remaining=0
 game.sim.step(7)
 await tap(game.world_to_screen(Vector2(5200,2800)))
 check(game.selected==workshop_index and visible_action("research:arrow"),"Tapping the Workshop opens global upgrades")
 await action("research:arrow")
 for control in game.buttons:
  if control.action=="start_research": check(control.caption=="Upgrade","Workshop purchase caption is simply Upgrade")
 await action("start_research")
 check(game.sim.research_levels.arrow==2 and game.sim.buildings[3].level==2,"Workshop upgrade applies immediately to every tower")
 await action("start_research")
 check(game.sim.research_levels.arrow==3,"A second global upgrade has no timer or queue")
 await capture("workshop-instant")
 await action("research:regeneration")
 check(not visible_action("workshop_regeneration") and not visible_action("research:wood") and not visible_action("research:stone"),"Workshop only lists defenses and Regeneration, with no Regen tab")
 game.sim.buildings[3].age=10
 game.sim.buildings[3].hp=100
 await action("upgrade_regeneration")
 check(game.sim.regeneration_level==1,"Workshop unlocks automatic regeneration")
 var hp:float=game.sim.buildings[3].hp
 game.sim.enemies.clear()
 game.sim.spawn_remaining=0
 game.sim.step(10)
 await frame()
 check(game.sim.buildings[3].hp>hp,"Standing buildings heal without local repair input")
 await capture("regeneration")
 await action("workshop_building")
 check(not visible_action("repair") and visible_action("clear"),"Workshop maintenance offers dismantling and automatic regeneration status")
 await action("workshop_research")
 check(visible_action("research:regeneration"),"Workshop navigation returns to upgrades")
 # Marketplace shows concrete income upgrades and no trade actions.
 check(game.sim.build_at(Vector2(5500,2920),"market")=="","Fixture builds a paid marketplace")
 var market_index:int=game.sim.buildings.size()-1
 game.sim.buildings[market_index].age=10
 game.selected=market_index
 await frame()
 check(visible_action("upgrade_local") and not visible_action("trade"),"Marketplace offers income upgrades and no trade screen")
 for control in game.buttons:
  if control.action=="upgrade_local": check(control.caption=="Upgrade","Local purchase caption is simply Upgrade")
 var previous_income:float=game.sim.income_rates().gold
 await action("upgrade_local")
 check(game.sim.income_rates().gold>previous_income,"Marketplace upgrade increases displayed passive gold")
 await capture("marketplace")
 game.sim.clear_at(market_index)
 game.selected=-1
 game.sim.resources={"wood":100000.0,"stone":100000.0,"gold":100000.0}
 # Producer panels expose local upgrades and concrete next-level effects.
 game.selected=1
 await frame()
 check(visible_action("upgrade_local") and not visible_action("workshop"),"Woodcutter upgrades are local")
 var producer_level:int=game.sim.buildings[1].level
 await action("upgrade_local")
 check(game.sim.buildings[1].level==producer_level+1,"Producer panel upgrades only that building")
 await capture("local-producer")
 # Equal-depth entity additions cannot move a quarry's rocks in front of it.
 game.selected=2
 game.sim.enemies.clear()
 game.sim.events.clear()
 game.accumulator=0
 game.sim.buildings[2].age=10
 var old_camera:Vector2=game.camera_center
 var old_motion:bool=game.reduced_motion
 game.reduced_motion=true
 game.set_process(false)
 var quarry:Vector2=game.sim.buildings[2].pos
 game.camera_center=quarry-Vector2(100,100)
 game.apply_camera()
 game.queue_redraw()
 game.world.queue_redraw()
 await frame()
 var area:=Rect2i(game.world_to_screen(quarry)-Vector2(110,180),Vector2(220,240))
 var baseline:PackedByteArray=root.get_texture().get_image().get_region(area).get_data()
 var old_count:int=game.sim.buildings.size()
 for i in 16:
  var extra:Dictionary=game.sim.make_building("arrow",quarry-Vector2(500,0))
  extra.age=10
  game.sim.buildings.append(extra)
  game.world.queue_redraw()
  await frame()
  check(root.get_texture().get_image().get_region(area).get_data()==baseline,"Quarry/rocks keep identical layering after equal-depth entity "+str(i+1))
 await capture("quarry-layering")
 game.sim.buildings.resize(old_count)
 game.reduced_motion=old_motion
 game.set_process(true)
 game.selected=-1
 game.camera_center=old_camera
 game.camera_center=Vector2(7080,2880)
 game.apply_camera()
 await action("build:wall")
 var before_count:int=game.sim.active_building_count()
 for y in [2800,2880,2960]:
  var start:Vector2=game.world_to_screen(Vector2(7000,y))
  var finish:Vector2=game.world_to_screen(Vector2(7160,y))
  touch(0,start,true)
  await frame()
  drag_touch(0,finish,finish-start)
  await frame()
  touch(0,finish,false)
  await frame()
  check(game.sim.wall_preview(game.wall_points).count==3,"Dragging another row previews three valid sections")
  await action("confirm_build")
  check(game.build_kind=="wall" and game.selected==-1,"Wall tool stays active for the next row")
 check(game.sim.active_building_count()==before_count+9,"Three strokes build a solid 3x3 fortification")
 var middle:int=game.sim.wall_at(Vector2(7080,2880))
 check(game.sim.wall_neighbors(middle).size()==4,"Interior wall tile joins all four neighbors")
 await capture("wall-mass")
 game.camera_center=Vector2(4160,2800)
 game.apply_camera()
 var start:Vector2=game.world_to_screen(Vector2(4160,2400))
 var finish:Vector2=game.world_to_screen(Vector2(4160,3200))
 touch(0,start,true)
 await frame()
 drag_touch(0,finish,finish-start)
 await frame()
 touch(0,finish,false)
 await frame()
 var preview:Dictionary=game.sim.wall_preview(game.wall_points)
 check(preview.count==6 and preview.skipped.size()>0 and preview.error=="","A stroke through red mountains previews only six available pass sections")
 await capture("wall-skip-red")
 await action("confirm_build")
 await action("cancel")
 check(game.sim.wall_at(Vector2(4160,2600))>=0 and game.sim.wall_at(Vector2(4160,3000))>=0,"Filtered stroke fills the entire mountain opening")
 # Destroyed buildings disappear; regeneration never leaves rebuildable ruins.
 game.selected=3
 var destroyer:Dictionary=game.sim.spawn_enemy()
 destroyer.cooldown=0
 destroyer.damage=1e9
 game.sim.attack_building(destroyer,3)
 game.sim.enemies.clear()
 game.sim.step(0.05)
 await frame()
 check(game.sim.buildings[3]==null and visible_action("build:arrow") and not visible_action("repair"),"Destroyed structures leave no local repair controls")
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
 check(game.sim!=null and game.sim.active_building_count()==saved_count and game.sim.research_levels.arrow==3,"Disk restore retains structures and global research")
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
