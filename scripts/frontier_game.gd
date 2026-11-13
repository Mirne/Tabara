extends Control
## Full-screen RTS presentation. World coordinates remain independent of the HUD.
const Sim=preload("res://scripts/simulation.gd")
const Map=preload("res://scripts/world_data.gd")
const Art=preload("res://scripts/frontier_art.gd")
const Body=preload("res://assets/fonts/Body.ttf")
const Title=preload("res://assets/fonts/Title.ttf")
const MENU=preload("res://assets/frontier/menu.png")
const IVORY=Color("eee3c9")
const GOLD=Color("d5b775")
const MUTED=Color("b2af9a")
const GREEN=Color("aabd7c")
const RED=Color("df9573")
const VIEW=Rect2(0,84,1104,726)
const MINIMAP=Rect2(22,648,226,140)
const ORDER=["wood","stone","arrow","wall","cannon","market","workshop"]
const RESEARCH_ORDER=Sim.GLOBAL_UPGRADES
const SAVE_PATH="user://frontier-settlement.json"
const SETTINGS_PATH="user://settings.json"
var sim
var screen:="menu"
var return_screen:="menu"
var selected:=-1
var research_kind:="arrow"
var workshop_tab:="research"
var build_kind:=""
var placement_ready:=false
var wall_points:Array=[]
var wall_anchor:=Vector2.ZERO
var wall_drawing:=false
var ghost:=Map.HALL-Vector2(220,0)
var camera_center:=Map.HALL-Vector2(110,0)
var zoom:=0.85
var world_container:Control
var world:Node2D
var buttons:Array=[]
var mouse:=Vector2(-100,-100)
var clock:=0.0
var accumulator:=0.0
const SPEEDS:=[1,2,5,10]
var speed:=1
var autosave:=0.0
var fx:Array=[]
var toast:=""
var toast_left:=0.0
var sound_on:=true
var music_on:=true
var reduced_motion:=false
var save_available:=false
var best:=0.0
var victory_count:=0
var sfx_player:AudioStreamPlayer
var music_player:AudioStreamPlayer
var sounds:Dictionary={}
var license_label:RichTextLabel
var pointer_down:=false
var pointer_start:=Vector2.ZERO
var dragged:=false
var touches:Dictionary={}
var pinch_distance:=0.0
var confirm_index:=-1
var hover_time:=0.0
var last_simulation_us:=0
var animation_clock:=0.0

func _ready()->void:
 get_tree().auto_accept_quit=false
 get_tree().quit_on_go_back=false
 load_settings()
 load_saved_game()
 world_container=Control.new()
 world_container.position=VIEW.position
 world_container.size=VIEW.size
 world_container.clip_contents=true
 world_container.mouse_filter=Control.MOUSE_FILTER_IGNORE
 world_container.z_index=-1
 add_child(world_container)
 world=Node2D.new()
 world.set_script(preload("res://scripts/frontier_view.gd"))
 world.game=self
 world_container.add_child(world)
 sfx_player=AudioStreamPlayer.new()
 sfx_player.volume_db=-12
 add_child(sfx_player)
 for key in ["click","build","gather","cannon","victory","defeat"]:
  sounds[key]=load("res://assets/audio/%s.wav"%key)
 music_player=AudioStreamPlayer.new()
 music_player.volume_db=-22
 add_child(music_player)
 var music:AudioStreamOggVorbis=load("res://assets/audio/hearth.ogg")
 music.loop=true
 music_player.stream=music
 if music_on: music_player.play()
 license_label=RichTextLabel.new()
 license_label.position=Vector2(363,291)
 license_label.size=Vector2(714,271)
 license_label.mouse_filter=Control.MOUSE_FILTER_STOP
 license_label.add_theme_font_override("normal_font",Body)
 license_label.add_theme_font_size_override("normal_font_size",13)
 license_label.add_theme_color_override("default_color",MUTED)
 license_label.text="GODOT ENGINE — MIT LICENSE\n\n"+Engine.get_license_text()+"\n\nTHIRD-PARTY NOTICES\n\n"+str(Engine.get_license_info())+"\n\nNOTO FONTS — SIL OPEN FONT LICENSE\n\n"+FileAccess.get_file_as_string("res://assets/fonts/OFL.txt")
 license_label.visible=false
 add_child(license_label)
 if "--mission" in OS.get_cmdline_user_args(): start_mission()
 apply_camera()

func _process(delta:float)->void:
 clock+=delta
 hover_time+=delta
 toast_left=maxf(0,toast_left-delta)
 license_label.visible=screen=="credits"
 world_container.visible=screen not in ["menu","briefing","confirm"] and not (screen in ["settings","credits","guide"] and return_screen=="menu")
 last_simulation_us=0
 if screen=="mission" and sim!=null:
  var pan:=Vector2.ZERO
  if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): pan.x-=1
  if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): pan.x+=1
  if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): pan.y-=1
  if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): pan.y+=1
  if pan!=Vector2.ZERO:
   camera_center+=pan.normalized()*delta*850/zoom
   apply_camera()
  accumulator+=minf(delta,0.15)*speed
  var simulation_started:=Time.get_ticks_usec()
  while accumulator>=0.05:
   sim.step(0.05)
   accumulator-=0.05
   consume_events()
   if sim.defeated or (sim.victory and not sim.victory_seen): break
  last_simulation_us=Time.get_ticks_usec()-simulation_started
  autosave+=delta
  if autosave>=10:
   save_game()
   autosave=0
  if sim.defeated:
   screen="defeat"
   save_game()
   play_sound("defeat")
  elif sim.victory and not sim.victory_seen:
   screen="victory"
   sim.victory_seen=true
   victory_count+=1
   save_game()
   play_sound("victory")
 if sim!=null: animation_clock=sim.elapsed
 var effect_delta:float=delta if screen in ["mission","victory","defeat"] else 0.0
 for i in range(fx.size()-1,-1,-1):
  fx[i].time-=effect_delta
  if fx[i].time<=0: fx.remove_at(i)
 mouse_default_cursor_shape=Control.CURSOR_ARROW
 for b in buttons:
  if b.rect.has_point(mouse) and b.enabled: mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 if world_container.visible: world.queue_redraw()
 queue_redraw()

func _notification(what:int)->void:
 if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_APPLICATION_FOCUS_OUT:
  if screen=="mission": screen="pause"
  pointer_down=false
  touches.clear()
  wall_drawing=false
  if is_node_ready(): save_game()
 if what==NOTIFICATION_APPLICATION_RESUMED and world!=null:
  world.ground_view.render_target_update_mode=SubViewport.UPDATE_ONCE
 if what==NOTIFICATION_WM_CLOSE_REQUEST:
  save_game()
  get_tree().quit()
 if what==NOTIFICATION_WM_GO_BACK_REQUEST: go_back()

func _exit_tree()->void:
 # These reusable styles belong to the current presentation, not the engine lifetime.
 Art.style_cache.clear()

func _input(event:InputEvent)->void:
 if event is InputEventMouseMotion:
  mouse=event.position
  hover_time=0
  if pointer_down:
   if mouse.distance_to(pointer_start)>8: dragged=true
   if dragged:
    if wall_drawing: update_wall(event.position)
    else:
     camera_center-=event.relative/zoom
     apply_camera()
  elif screen=="mission" and VIEW.has_point(mouse): ghost=sim.snap_position(screen_to_world(mouse),build_kind) if not placement_ready else ghost
 if event is InputEventMouseButton:
  mouse=event.position
  if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and screen=="mission" and VIEW.has_point(mouse):
   zoom_at(mouse,zoom*(1.13 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.13))
  if event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
   build_kind=""
  if event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed:
    if click_ui(mouse): return
    if screen=="mission" and VIEW.has_point(mouse):
     pointer_down=true
     dragged=false
     pointer_start=mouse
     if build_kind=="wall": begin_wall(mouse)
   elif pointer_down:
    pointer_down=false
    if wall_drawing: finish_wall(mouse)
    elif not dragged and VIEW.has_point(mouse): click_world(mouse)
 if event is InputEventScreenTouch:
  if event.pressed:
   touches[event.index]=event.position
   if touches.size()==1:
    if click_ui(event.position):
     pointer_down=false
     return
    pointer_down=screen=="mission" and VIEW.has_point(event.position)
    pointer_start=event.position
    dragged=false
    if pointer_down and build_kind=="wall": begin_wall(event.position)
   elif touches.size()==2:
    if wall_drawing:
     wall_drawing=false
     wall_points.clear()
     placement_ready=false
    dragged=true
    var points:Array=touches.values()
    pinch_distance=points[0].distance_to(points[1])
  else:
   touches.erase(event.index)
   if touches.is_empty():
    if wall_drawing: finish_wall(event.position)
    elif pointer_down and not dragged and VIEW.has_point(event.position): click_world(event.position)
    pointer_down=false
    pinch_distance=0
 if event is InputEventScreenDrag and touches.has(event.index):
  var old_points:Array=touches.values()
  var old_center:Vector2=Vector2.ZERO
  for point in old_points: old_center+=point
  old_center/=old_points.size()
  touches[event.index]=event.position
  if not pointer_down or screen!="mission": return
  if touches.size()>=2:
   var points:Array=touches.values()
   var center:Vector2=(points[0]+points[1])/2
   var distance:float=points[0].distance_to(points[1])
   camera_center-=(center-old_center)/zoom
   if pinch_distance>0: zoom_at(center,zoom*distance/pinch_distance)
   pinch_distance=distance
   dragged=true
  else:
   if event.position.distance_to(pointer_start)>8: dragged=true
   if wall_drawing: update_wall(event.position)
   elif dragged:
    camera_center-=event.relative/zoom
    apply_camera()
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE: go_back()
  elif event.keycode==KEY_SPACE and screen in ["mission","pause"]: act("pause" if screen=="mission" else "resume")
  elif screen=="mission":
   if event.keycode>=KEY_1 and event.keycode<=KEY_7: act("build:"+ORDER[event.keycode-KEY_1])
   if event.keycode==KEY_U: act("upgrade")
   if event.keycode==KEY_R: act("regeneration")
   if event.keycode==KEY_F: act("hall")

func screen_to_world(point:Vector2)->Vector2:
 return (point-VIEW.position-VIEW.size/2)/zoom+camera_center

func world_to_screen(point:Vector2)->Vector2:
 return (point-camera_center)*zoom+VIEW.position+VIEW.size/2

func apply_camera()->void:
 var half:=VIEW.size/(zoom*2)
 camera_center=Vector2(clampf(camera_center.x,half.x,Map.SIZE.x-half.x),clampf(camera_center.y,half.y,Map.SIZE.y-half.y))
 if world!=null:
  world.scale=Vector2.ONE*zoom
  world.position=VIEW.size/2-camera_center*zoom

func zoom_at(point:Vector2,value:float)->void:
 var before:=screen_to_world(point)
 zoom=clampf(value,0.28,1.6)
 camera_center+=before-screen_to_world(point)
 apply_camera()

func click_ui(point:Vector2)->bool:
 for i in range(buttons.size()-1,-1,-1):
  var b:Dictionary=buttons[i]
  if b.rect.has_point(point):
   if b.enabled:
    play_sound("click")
    act(b.action)
   return true
 if screen=="mission" and MINIMAP.has_point(point):
  camera_center=(point-MINIMAP.position)/MINIMAP.size*Map.SIZE
  apply_camera()
  return true
 return false

func click_world(point:Vector2)->void:
 if screen!="mission" or sim==null: return
 var at:=screen_to_world(point)
 if build_kind!="":
  if build_kind=="wall":
   wall_points=sim.wall_line(at,at)
   ghost=wall_points[0]
  else: ghost=sim.snap_position(at,build_kind)
  placement_ready=true
  return
 var candidates:Array=[]
 for i in sim.buildings.size():
  var b=sim.buildings[i]
  if b==null: continue
  var size:Vector2=Art.BUILD_SIZES[Sim.DEFINITIONS[b.kind].art]
  if b.hp<=0: size=Vector2(140,100)
  var rect:Rect2=Art.building_rect(Sim.DEFINITIONS[b.kind].art,b.pos).grow(8)
  if b.hp<=0: rect=Rect2(b.pos-Vector2(size.x/2,size.y),size+Vector2(0,20))
  if rect.has_point(at): candidates.append(i)
 if not candidates.is_empty():
  candidates.sort_custom(func(a,b):return sim.buildings[a].pos.y>sim.buildings[b].pos.y)
  selected=candidates[0]
  workshop_tab="research"
  return
 selected=-1

func begin_wall(point:Vector2)->void:
 wall_drawing=true
 wall_anchor=screen_to_world(point)
 wall_points=sim.wall_line(wall_anchor,wall_anchor)
 ghost=wall_points[-1]
 placement_ready=false

func update_wall(point:Vector2)->void:
 if not wall_drawing: return
 var clamped:=point.clamp(VIEW.position,VIEW.end-Vector2.ONE)
 wall_points=sim.wall_line(wall_anchor,screen_to_world(clamped))
 ghost=wall_points[-1]

func finish_wall(point:Vector2)->void:
 update_wall(point)
 wall_drawing=false
 placement_ready=true

func confirm_placement()->void:
 if not placement_ready or build_kind=="": return
 if build_kind!="wall" and not VIEW.has_point(world_to_screen(ghost)):
  notify("Bring the building preview back into view before confirming.")
  return
 var error:String=sim.build_wall(wall_points) if build_kind=="wall" else sim.build_at(ghost,build_kind)
 if error!="":
  notify(error)
  return
 selected=-1
 placement_ready=false
 wall_points.clear()
 play_sound("build")
 consume_events()

func act(action:String)->void:
 if action.begins_with("research:"):
  var kind:=action.trim_prefix("research:")
  if kind in RESEARCH_ORDER or kind=="regeneration": research_kind=kind
  return
 if action.begins_with("build:"):
  if screen!="mission" or sim==null: return
  var kind:String=action.trim_prefix("build:")
  if kind not in ORDER: return
  build_kind="" if build_kind==kind else kind
  placement_ready=false
  wall_points.clear()
  wall_drawing=false
  ghost=sim.snap_position(camera_center,kind)
  return
 match action:
  "confirm_build": confirm_placement()
  "new": screen="confirm" if save_available else "briefing"
  "confirm_new": screen="briefing"
  "start": start_mission()
  "continue":
   if sim!=null and not sim.defeated:
    screen="mission"
    accumulator=0
  "pause":
   screen="pause"
   build_kind=""
   save_game()
  "resume": screen="mission"
  "menu":
   save_game()
   build_kind=""
   screen="menu"
  "menu_back": screen="menu"
  "settings","guide","credits":
   return_screen=screen
   screen=action
  "back": screen=return_screen
  "construction":
   selected=-1
   build_kind=""
   placement_ready=false
   wall_points.clear()
  "upgrade_local":
   var error:String=sim.upgrade_at(selected)
   if error!="": notify(error)
   else:
    consume_events()
    play_sound("build")
  "workshop","upgrade":
   if selected>=0 and selected<sim.buildings.size() and sim.buildings[selected]!=null and sim.buildings[selected].kind in RESEARCH_ORDER: research_kind=sim.buildings[selected].kind
   var found:=-1
   for i in sim.buildings.size():
    if sim.buildings[i]!=null and sim.buildings[i].kind=="workshop": found=i
   if found<0: act("build:workshop")
   else:
    selected=found
    build_kind=""
    workshop_tab="research"
  "workshop_research": workshop_tab="research"
  "workshop_building": workshop_tab="building"
  "workshop_regeneration":
   workshop_tab="research"
   research_kind="regeneration"
  "regeneration":
   act("workshop")
   research_kind="regeneration"
   workshop_tab="research"
  "upgrade_regeneration":
   var error:String=sim.upgrade_regeneration()
   if error!="": notify(error)
   else:
    consume_events()
    play_sound("build")
  "start_research":
   var error:String=sim.start_research(research_kind)
   if error!="": notify(error)
   else:
    consume_events()
    play_sound("build")
  "clear":
   confirm_index=selected
   screen="dismantle"
  "confirm_clear":
   var error:String=sim.clear_at(confirm_index)
   if error!="": notify(error)
   else:
    selected=-1
    consume_events()
   screen="mission"
  "cancel_clear": screen="mission"
  "speed": speed=SPEEDS[(SPEEDS.find(speed)+1)%SPEEDS.size()]
  "cancel":
   build_kind=""
   wall_points.clear()
   wall_drawing=false
   placement_ready=false
  "endless":
   screen="mission"
  "hall":
   camera_center=Map.HALL
   selected=0
   apply_camera()
  "zoom_in": zoom_at(VIEW.get_center(),zoom*1.2)
  "zoom_out": zoom_at(VIEW.get_center(),zoom/1.2)
  "sound":
   sound_on=not sound_on
   save_settings()
  "music":
   music_on=not music_on
   if music_on: music_player.play()
   else: music_player.stop()
   save_settings()
  "motion":
   reduced_motion=not reduced_motion
   world.water.material.set_shader_parameter("motion_rate",0.0 if reduced_motion else 1.0)
   save_settings()

func go_back()->void:
 match screen:
  "menu":
   save_game()
   get_tree().quit()
  "mission":
   if build_kind!="": build_kind=""
   else: act("pause")
  "pause": act("resume")
  "settings","guide","credits": act("back")
  "briefing","confirm": screen="menu"
  "dismantle": screen="mission"
  "victory": act("endless")
  "defeat": act("menu")

func start_mission()->void:
 sim=Sim.new(int(Time.get_unix_time_from_system())%100000)
 screen="mission"
 selected=-1
 speed=1
 build_kind=""
 camera_center=Map.HALL+Vector2(40,0)
 zoom=0.72
 apply_camera()
 fx.clear()
 accumulator=0
 autosave=0
 save_available=true
 save_game()

func consume_events()->void:
 for e in sim.events:
  if e.type in ["shot","hit","kill","build","gather","ruin"]:
   e.time=0.35 if e.type=="shot" else 1.2
   e.duration=e.time
   if fx.size()<180: fx.append(e)
  if e.type=="boss":
   notify(e.text+" enters from the western approach.")
   play_sound("cannon")
  if e.type=="ruin":
   play_sound("cannon")
  if e.type=="shot" and e.cannon and clock-float(get_meta("last_boom",-10.0))>0.35:
   play_sound("cannon")
   set_meta("last_boom",clock)
 sim.events.clear()

func notify(message:String)->void:
 toast=message
 toast_left=4

func play_sound(key:String)->void:
 if sound_on and sounds.has(key):
  sfx_player.stream=sounds[key]
  sfx_player.play()

func save_game()->void:
 if sim==null: return
 best=maxf(best,sim.elapsed)
 var file:=FileAccess.open(SAVE_PATH+".tmp",FileAccess.WRITE)
 if file==null:
  notify("Could not save. Check available device storage.")
  return
 var data:Dictionary=sim.snapshot()
 data.camera=[camera_center.x,camera_center.y,zoom]
 file.store_string(JSON.stringify(data,"",true,true))
 file.close()
 if DirAccess.rename_absolute(SAVE_PATH+".tmp",SAVE_PATH)!=OK: notify("Could not finish saving. Check device storage.")
 save_available=not sim.defeated
 save_settings()

func load_saved_game()->void:
 if not FileAccess.file_exists(SAVE_PATH): return
 var data=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
 if not data is Dictionary: return
 sim=Sim.restore(data)
 if sim==null: return
 save_available=not sim.defeated
 var camera=data.get("camera",[])
 if camera is Array and camera.size()==3:
  if Sim._number(camera[0],0,Map.SIZE.x) and Sim._number(camera[1],0,Map.SIZE.y) and Sim._number(camera[2],0.28,1.6):
   camera_center=Vector2(camera[0],camera[1])
   zoom=camera[2]

func load_settings()->void:
 if not FileAccess.file_exists(SETTINGS_PATH): return
 var data=JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
 if not data is Dictionary: return
 sound_on=bool(data.get("sound",true))
 music_on=bool(data.get("music",true))
 reduced_motion=bool(data.get("motion",false))
 best=float(data.get("best",0))
 victory_count=int(data.get("victories",0))

func save_settings()->void:
 var file:=FileAccess.open(SETTINGS_PATH,FileAccess.WRITE)
 if file!=null: file.store_string(JSON.stringify({"sound":sound_on,"music":music_on,"motion":reduced_motion,"best":best,"victories":victory_count}))

func label(value:String,pos:Vector2,size_px:int=18,color:Color=IVORY,heading:bool=false)->void:
 draw_string(Title if heading else Body,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func centered(value:String,rect:Rect2,size_px:int=18,color:Color=IVORY,heading:bool=false)->void:
 var font:Font=Title if heading else Body
 var width:float=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x
 label(value,Vector2(rect.position.x+(rect.size.x-width)/2,rect.position.y+rect.size.y/2+size_px*0.34),size_px,color,heading)

func wrapped(value:String,pos:Vector2,width:float,size_px:int=17,color:Color=MUTED,line_height:int=27)->void:
 var line=""
 var y=pos.y
 for word in value.split(" "):
  if Body.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x>width and line!="":
   label(line.strip_edges(),Vector2(pos.x,y),size_px,color)
   y+=line_height
   line=""
  line+=word+" "
 label(line.strip_edges(),Vector2(pos.x,y),size_px,color)

func button(rect:Rect2,value:String,action:String,primary:bool=false,enabled:bool=true,size_px:int=18)->void:
 var tint:=Color(1.17,1.13,0.98) if primary else Color(0.88,0.92,0.88)
 if rect.has_point(mouse) and enabled: tint*=1.2
 if not enabled: tint=Color(0.64,0.65,0.6,0.92)
 Art.skin(self,rect,tint,10)
 centered(value,rect,size_px,GOLD if primary else (IVORY if enabled else MUTED))
 buttons.append({"rect":rect,"action":action,"enabled":enabled,"caption":value})

func pretty(value:float)->String:
 if value>=1e9: return "%.1fB"%(value/1e9)
 if value>=1e6: return "%.1fM"%(value/1e6)
 if value>=10000: return "%.1fk"%(value/1000)
 return str(int(value))

func time_label(seconds:float)->String:
 return "%02d:%02d"%[int(seconds)/60,int(seconds)%60]

func cost_row(cost:Array,pos:Vector2,size_px:int=13)->void:
 for i in 3:
  if cost[i]<=0: continue
  var color:=IVORY if sim==null or sim.resources[Sim.RESOURCE_NAMES[i]]>=cost[i] else RED
  Art.icon(self,i,Rect2(pos+Vector2(i*81,-17),Vector2(20,20)))
  label(pretty(cost[i]),pos+Vector2(i*81+23,0),size_px,color)

func _draw()->void:
 buttons.clear()
 var menu_base:bool=screen in ["menu","briefing","confirm"] or (screen in ["settings","guide","credits"] and return_screen=="menu")
 if menu_base: draw_menu()
 elif sim!=null: draw_hud()
 if screen=="briefing": draw_briefing()
 elif screen=="confirm":
  overlay(Rect2(410,215,620,370),"NEW SETTLEMENT","Leave the old frontier?","This replaces the current frontier save. Your best time and settings remain.")
  button(Rect2(450,484,250,56),"Keep settlement","menu_back")
  button(Rect2(720,484,270,56),"Start a new mission","confirm_new",true)
 elif screen in ["pause","victory","defeat"]: draw_end()
 elif screen=="settings": draw_settings()
 elif screen=="guide": draw_guide()
 elif screen=="credits": draw_credits()
 elif screen=="dismantle":
  overlay(Rect2(410,215,620,370),"DISMANTLE STRUCTURE","Clear these foundations?","Returns 25% of the building cost.")
  button(Rect2(450,495,250,55),"Keep building","cancel_clear")
  button(Rect2(720,495,270,55),"Clear the ground","confirm_clear",true)
 if toast_left>0 and screen=="mission":
  var w:float=minf(1040,Body.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+48)
  var rect:=Rect2((VIEW.size.x-w)/2,96,w,40)
  Art.skin(self,rect,Color(0.8,0.85,0.78),8)
  centered(toast,rect,16,IVORY)

func draw_menu()->void:
 draw_texture_rect(MENU,Rect2(0,0,1440,810),false)
 Art.icon(self,4,Rect2(79,47,42,42))
 label("F R O N T I E R   C O M M A N D",Vector2(133,74),15,GOLD)
 label("TABARA",Vector2(77,239),87,IVORY,true)
 label("L A S T   H E A R T H",Vector2(84,282),24,GOLD)
 wrapped("Build beyond the walls.\nHold against the tide.".replace("\n"," "),Vector2(86,337),370,22,IVORY,32)
 button(Rect2(80,431,390,62),"Continue settlement" if save_available else "Establish a settlement","continue" if save_available else "new",true,true,21)
 if save_available: button(Rect2(80,506,390,52),"New frontier","new",false,true,18)
 button(Rect2(80,580,390,50),"Settings","settings",false,true,17)
 button(Rect2(80,646,185,46),"Credits","credits",false,true,16)
 label("SINGLE PLAYER   /   OFFLINE",Vector2(83,754),13,MUTED)
 Art.skin(self,Rect2(971,620,414,142),Color(0.87,0.9,0.83))
 label("MISSION 01",Vector2(997,650),13,GOLD)
 label("The Hearthvale Basin",Vector2(996,685),26,IVORY,true)
 wrapped("A vast valley. One approach. Fifteen minutes to secure your foothold.",Vector2(997,716),360,15,MUTED,23)
 if best>0:
  Art.skin(self,Rect2(1170,27,230,43),Color(0.86,0.9,0.83),9)
  centered("BEST HOLD  "+time_label(best),Rect2(1170,27,230,43),14,IVORY)

func draw_hud()->void:
 Art.skin(self,Rect2(-4,-5,1448,94),Color(0.82,0.87,0.8),14)
 var rates:Dictionary=sim.income_rates()
 for i in 3:
  var x:float=28+i*220
  Art.icon(self,i,Rect2(x,17,43,43))
  label(pretty(sim.resources[Sim.RESOURCE_NAMES[i]]),Vector2(x+52,38),25,IVORY)
  label("+%.1f / sec"%rates[Sim.RESOURCE_NAMES[i]],Vector2(x+52,61),12,GREEN)
 Art.icon(self,5,Rect2(730,20,35,35))
 label(time_label(sim.elapsed)+( " +" if sim.victory else " / 15:00"),Vector2(776,39),22,IVORY)
 label("WAVE %02d   ·   %d DEFEATED"%[sim.wave,sim.kills],Vector2(776,62),11,GOLD)
 button(Rect2(1066,15,69,55),"%d×"%speed,"speed",false,true,18)
 button(Rect2(1145,15,101,55),"Hall","hall",false,true,16)
 button(Rect2(1257,15,162,55),"Ⅱ  Pause","pause",false,true,18)
 Art.skin(self,Rect2(1102,82,342,732),Color(0.83,0.89,0.82),14)
 if build_kind!="" or (selected>=0 and selected<sim.buildings.size() and sim.buildings[selected]!=null): draw_inspector()
 else: draw_construction()
 draw_minimap()
 if screen!="mission": buttons.clear()

func draw_construction()->void:
 label("BUILD STRUCTURES",Vector2(1121,124),21,GOLD,true)
 for i in ORDER.size():
  var kind:String=ORDER[i]
  var d:Dictionary=Sim.DEFINITIONS[kind]
  var wide:bool=kind=="workshop"
  var rect:=Rect2(1120+(i%2)*158,145+(i/2)*158,148,146)
  if wide: rect.size.x=306
  Art.skin(self,rect,Color(0.82,0.88,0.82),9)
  if kind=="wall" and Art.wall_icon!=null:
   draw_texture_rect(Art.wall_icon,Rect2(rect.position+Vector2(38,8),Vector2(74,60)),false)
  else:
   var scale_value:float=0.29 if kind not in ["arrow","cannon"] else 0.25
   Art.building(self,d.art,Vector2(rect.get_center().x,rect.position.y+75),scale_value)
  centered(d.name,Rect2(rect.position.x,rect.position.y+78,rect.size.x,25),17,IVORY)
  var left:float=rect.get_center().x-66
  for r in 3:
   Art.icon(self,r,Rect2(left+r*46,rect.position.y+115,16,16))
   label(pretty(d.cost[r]),Vector2(left+17+r*46,rect.position.y+130),13,IVORY if sim.resources[Sim.RESOURCE_NAMES[r]]>=d.cost[r] else RED)
  buttons.append({"rect":rect,"action":"build:"+kind,"enabled":true})

func draw_inspector()->void:
 if build_kind!="":
  var d:Dictionary=Sim.DEFINITIONS[build_kind]
  label("PLACE STRUCTURE",Vector2(1120,121),14,GOLD)
  wrapped(d.name,Vector2(1120,164),306,25,IVORY,30)
  var example:Dictionary=sim.make_building(build_kind,ghost)
  var rows:Array=current_stat_rows(example)
  for i in rows.size(): label(rows[i],Vector2(1120,224+i*29),17,IVORY)
  var wall:Dictionary=sim.wall_preview(wall_points) if build_kind=="wall" else {}
  var error:String=wall.error if build_kind=="wall" else sim.placement_error(ghost,build_kind)
  var cost:Array=wall.cost if build_kind=="wall" else d.cost
  var ready:bool=placement_ready and error=="" and sim.can_afford(cost) and (build_kind=="wall" or VIEW.has_point(world_to_screen(ghost)))
  var status:=""
  if placement_ready:
   status=error if error!="" else ("Ready to build." if sim.can_afford(cost) else "Not enough supplies.")
   if build_kind!="wall" and not VIEW.has_point(world_to_screen(ghost)): status="Bring the preview into view."
   if build_kind=="wall" and error=="": status="%d new sections · %d blocked skipped"%[wall.count,wall.skipped.size()]
  wrapped(status,Vector2(1120,477),304,18,GREEN if ready else GOLD,27)
  label("CONSTRUCTION COST",Vector2(1120,583),13,GOLD)
  cost_row(cost,Vector2(1122,618),15)
  button(Rect2(1120,652,306,66),"Build · Confirm","confirm_build",true,ready,21)
  button(Rect2(1120,734,306,58),"Done building","cancel",false,true,20)
  return
 if selected<0 or selected>=sim.buildings.size() or sim.buildings[selected]==null: return
 var b:Dictionary=sim.buildings[selected]
 var d:Dictionary=Sim.DEFINITIONS[b.kind]
 if b.kind=="workshop" and workshop_tab=="research":
  draw_research_panel(b)
  return
 label(d.name,Vector2(1120,133),25,IVORY,true)
 var offset:=0
 if b.kind=="workshop":
  draw_workshop_tabs()
  offset=76
 label("LEVEL %d / 100"%b.level,Vector2(1120,166+offset),16,GOLD)
 label("%s / %s HP"%[pretty(b.hp),pretty(sim.stat(b,"hp"))],Vector2(1120,211+offset),20,IVORY)
 draw_rect(Rect2(1120,229+offset,306,10),Color("252a20"))
 draw_rect(Rect2(1120,229+offset,306*clampf(b.hp/sim.stat(b,"hp"),0,1),10),GREEN)
 var rows:Array=current_stat_rows(b)
 for i in rows.size(): label(rows[i],Vector2(1120,272+offset+i*25),16,IVORY)
 if b.age<sim.build_time(b.kind): label("Construction · %.1fs"%(sim.build_time(b.kind)-b.age),Vector2(1120,369),16,GOLD)
 var effects:Array=upgrade_effect_rows(b)
 for i in effects.size(): label(effects[i],Vector2(1120,423+i*24),15,GOLD)
 cost_row(sim.upgrade_cost(b),Vector2(1122,538),15)
 var local:bool=b.kind in Sim.LOCAL_UPGRADES
 var caption:="Upgrade" if local else "Workshop"
 if b.level>=100: caption="Maximum level"
 var available:bool=b.level<100 and b.age>=sim.build_time(b.kind)
 if local:available=available and sim.can_afford(sim.upgrade_cost(b))
 button(Rect2(1120,554,306,60),caption,"upgrade_local" if local else "workshop",true,available,20)
 button(Rect2(1120,643,306,58),"Dismantle","clear",false,selected>0,19)
 button(Rect2(1120,734,306,58),"Build structures","construction",false,true,20)

func current_stat_rows(b:Dictionary)->Array:
 var rows:Array=[]
 var d:Dictionary=Sim.DEFINITIONS[b.kind]
 if d.has("income"): rows.append("%.2f %s / sec"%[sim.stat(b,"income")*sim.production_bonus(b),d.resource])
 if d.has("damage"):
  rows.append("%s damage · %.2fs"%[pretty(sim.stat(b,"damage")),sim.stat(b,"period")])
  rows.append("Range %d"%sim.stat(b,"range"))
 if sim.regeneration_level>0 and b.age>=sim.build_time(b.kind): rows.append("+%.1f HP / sec"%(sim.stat(b,"hp")*sim.regeneration_rate()))
 return rows

func upgrade_effect_rows(b:Dictionary)->Array:
 var next:Dictionary=b.duplicate()
 next.level=mini(100,b.level+1)
 var rows:Array=["HP  %s → %s"%[pretty(sim.stat(b,"hp")),pretty(sim.stat(next,"hp"))]]
 var d:Dictionary=Sim.DEFINITIONS[b.kind]
 if d.has("income"):
  rows.append("%s/sec  %.2f → %.2f"%[d.resource.capitalize(),sim.stat(b,"income")*sim.production_bonus(b),sim.stat(next,"income")*sim.production_bonus(next)])
 if d.has("damage"):
  rows.append("Damage  %s → %s"%[pretty(sim.stat(b,"damage")),pretty(sim.stat(next,"damage"))])
  rows.append("Range  %d → %d"%[sim.stat(b,"range"),sim.stat(next,"range")])
  rows.append("Attack/sec  %.2f → %.2f"%[1.0/sim.stat(b,"period"),1.0/sim.stat(next,"period")])
 return rows

func draw_research_panel(_b:Dictionary)->void:
 label("WORKSHOP",Vector2(1120,128),25,IVORY,true)
 draw_workshop_tabs()
 var subjects:Array=Array(RESEARCH_ORDER)+["regeneration"]
 var stride:=79 if subjects.size()<=6 else 63
 for i in subjects.size():
  var kind:String=subjects[i]
  var rect:=Rect2(1120+(i%2)*158,216+(i/2)*stride,148,stride-9)
  var active:bool=research_kind==kind
  Art.skin(self,rect,Color(1.25,1.16,0.82) if active else Color(0.79,0.85,0.79),8)
  var title:String="Regeneration" if kind=="regeneration" else Sim.DEFINITIONS[kind].name
  var level:int=sim.regeneration_level if kind=="regeneration" else sim.research_levels[kind]
  centered(title,Rect2(rect.position+Vector2(0,6),Vector2(148,25)),16,IVORY)
  centered("Level %d"%level,Rect2(rect.position+Vector2(0,30),Vector2(148,20)),14,GOLD)
  buttons.append({"rect":rect,"action":"research:"+kind,"enabled":true})
 if research_kind not in subjects: research_kind="arrow"
 var regen:bool=research_kind=="regeneration"
 var current:int=sim.regeneration_level if regen else sim.research_levels[research_kind]
 var heading:float=216+ceili(subjects.size()/2.0)*stride+26
 label("Level %d → %d"%[current,mini(current+1,100)],Vector2(1120,heading),18,IVORY)
 var rows:Array=[]
 if regen:
  rows.append("HP/sec  %.2f%% → %.2f%%"%[sim.regeneration_rate()*100,sim.regeneration_rate(mini(100,current+1))*100])
 else:
  var example:Dictionary={"kind":research_kind,"level":current,"pos":Vector2.ZERO}
  rows=upgrade_effect_rows(example)
 for i in rows.size(): label(rows[i],Vector2(1120,heading+27+i*23),15,GOLD)
 var cost:Array=sim.regeneration_cost() if regen else sim.research_cost(research_kind)
 cost_row(cost,Vector2(1122,619),15)
 var caption:="Upgrade" if current<100 else "Maximum level"
 var available:bool=sim.workshop_index()>=0 and current<100 and sim.can_afford(cost)
 button(Rect2(1120,646,306,64),caption,"upgrade_regeneration" if regen else "start_research",true,available,20)
 button(Rect2(1120,734,306,58),"Build structures","construction",false,true,20)

func draw_workshop_tabs()->void:
 button(Rect2(1120,149,148,48),"Upgrades","workshop_research",workshop_tab=="research",true,17)
 button(Rect2(1278,149,148,48),"Building","workshop_building",workshop_tab=="building",true,17)

func draw_minimap()->void:
 Art.skin(self,Rect2(10,635,251,165),Color(0.9,0.93,0.86),10)
 var map_image:Texture2D=world.legacy_overview if sim.terrain_revision==3 else (world.legacy_stronghold_overview if sim.terrain_revision==4 else world.overview)
 if sim.terrain_revision>=3 and map_image!=null: draw_texture_rect(map_image,MINIMAP,false,Color(0.9,0.94,0.88))
 elif world.ground_view!=null: draw_texture_rect(world.ground_view.get_texture(),MINIMAP,false,Color(0.79,0.88,0.75))
 for b in sim.buildings:
  if b!=null: draw_rect(Rect2(MINIMAP.position+b.pos/Map.SIZE*MINIMAP.size-Vector2(1.5,1.5),Vector2(3,3)),GOLD if b.hp>0 else RED)
 for e in sim.enemies:
  var p:Vector2=MINIMAP.position+sim.enemy_position(e)/Map.SIZE*MINIMAP.size
  draw_rect(Rect2(p,Vector2(1.5,1.5)),Color("cd755a"))
 var half:Vector2=VIEW.size/(zoom*2)
 var rect:=Rect2(MINIMAP.position+(camera_center-half)/Map.SIZE*MINIMAP.size,half*2/Map.SIZE*MINIMAP.size)
 draw_rect(rect,Color("f0dfad"),false,1.2)

func overlay(rect:Rect2,tag:String,title:String,description:String="")->void:
 buttons.clear()
 draw_rect(Rect2(0,0,1440,810),Color(0.035,0.045,0.035,0.78))
 Art.skin(self,rect,Color(0.98,1,0.93),19)
 label(tag,rect.position+Vector2(38,44),13,GOLD)
 label(title,rect.position+Vector2(36,94),34,IVORY,true)
 if description!="": wrapped(description,rect.position+Vector2(38,137),rect.size.x-76,17,MUTED,28)

func draw_briefing()->void:
 overlay(Rect2(355,105,730,600),"MISSION 01  /  THE HEARTHVALE BASIN","Carve a foothold in the valley.","The western road carries the first raiders. Keep your main hall standing for fifteen minutes, then continue the endless siege.")
 var rows:=[["01","Secure limited supplies","Two timber sites and two quarries are inside the base. Two more of each lie outside. Green tiles mark valid sites when placing a producer."],["02","Build a defensive line","Drag joined walls and cover them with arrow towers and cannons. Great hordes bring stronger elite raiders. Enemies retaliate against firing defenses."],["03","Keep the settlement standing","Destroyed buildings disappear. Defenses and Regeneration upgrade at the Workshop. Other buildings upgrade individually."]]
 for i in 3:
  var y:float=343+i*88
  label(rows[i][0],Vector2(395,y),27,GOLD,true)
  label(rows[i][1],Vector2(452,y-2),20,IVORY)
  wrapped(rows[i][2],Vector2(452,y+24),578,14,MUTED,22)
 button(Rect2(394,625,152,51),"Back","menu_back")
 button(Rect2(562,625,483,51),"Establish a settlement","start",true)

func draw_end()->void:
 var title="The frontier is still."
 var tag="SETTLEMENT PAUSED"
 var description="Your settlement is saved. Resume when you are ready."
 if screen=="victory":
  title="The foothold is secured."
  tag="MISSION COMPLETE  /  15 MINUTES HELD"
  description="Pinewatch has endured the first assault. Continue into endless survival as the hordes grow, or return to camp."
 elif screen=="defeat":
  title="The last hearth has fallen."
  tag="SETTLEMENT LOST"
  description="Your defenses leave ruins across the frontier. Return with a new plan and establish another settlement."
 overlay(Rect2(385,159,670,500),tag,title,description)
 for i in 3:
  var x:float=426+i*202
  label(["TIME HELD","RAIDERS DEFEATED","WAVE REACHED"][i],Vector2(x,398),11,MUTED)
  label([time_label(sim.elapsed),str(sim.kills),str(sim.wave)][i],Vector2(x,437),32,IVORY,true)
 button(Rect2(424,477,592,56),"Resume the settlement" if screen=="pause" else ("Continue endless survival" if screen=="victory" else "Establish a new settlement"),"resume" if screen=="pause" else ("endless" if screen=="victory" else "start"),true)
 if screen=="pause":
  button(Rect2(424,555,286,52),"Settings","settings",false,true,17)
  button(Rect2(730,555,286,52),"Save & menu","menu",false,true,16)
 else: button(Rect2(424,555,592,52),"Return to camp","menu",false,true,17)

func draw_settings()->void:
 overlay(Rect2(418,136,604,538),"SETTLEMENT OPTIONS","Settings")
 var rows:=[["Sound effects","Construction, resources and combat","sound",sound_on],["Music","The sounds of the frontier","music",music_on],["Reduce motion","Calmer smoke and sprite animations","motion",reduced_motion]]
 for i in 3:
  var y:float=288+i*95
  label(rows[i][0],Vector2(458,y),21,IVORY)
  label(rows[i][1],Vector2(458,y+28),13,MUTED)
  button(Rect2(871,y-25,110,49),"On" if rows[i][3] else "Off",rows[i][2],rows[i][3])
 button(Rect2(457,584,526,52),"Return","back",true)

func draw_guide()->void:
 overlay(Rect2(235,65,970,680),"FIELD MANUAL","Build a settlement worth defending.")
 var entries:=[["Explore the frontier","Drag the landscape to pan. While drawing walls, use two fingers to pan. Pinch to zoom. Tap the minimap to travel; Hall returns to your main building."],["Place buildings freely","Choose a right-hand card, tap a grid location to preview, then confirm Build. Woodcutters and stonemasons require matching deposits; one producer per deposit."],["Gather and produce","Resource sites are scenery. Build a woodcutter on a marked timber site or a stonemason on a quarry for automatic supplies. Defeated raiders award gold."],["Hold the western approach","Raiders take a direct land route to the main hall and destroy buildings blocking them. Drag connected wall lines to defend the approach."],["Upgrade, repair or clear","Upgrade walls, towers and Regeneration at the Workshop. Upgrade other buildings individually."],["Secure the foothold","Survive 15 in-game minutes to win, then continue endlessly. Minibosses enter every five minutes. App switching pauses and saves."]]
 for i in entries.size():
  var p:=Vector2(274+(i%2)*462,245+(i/2)*141)
  label("0%d  %s"%[i+1,entries[i][0]],p,19,IVORY,true)
  wrapped(entries[i][1],p+Vector2(0,30),414,14,MUTED,24)
 label("DESKTOP   WASD / drag: pan   ·   Wheel: zoom   ·   1–7: build   ·   U: Workshop   ·   R: regeneration   ·   F: hall",Vector2(274,692),11,MUTED)
 button(Rect2(994,675,171,46),"Understood","back",true,true,16)

func draw_credits()->void:
 overlay(Rect2(325,94,790,600),"ART, AUDIO & ENGINE","Tabara: Last Hearth")
 label("Original image-generated scenery, unit sprites and interface art.",Vector2(363,241),17,IVORY)
 label("Godot 4.6.3  ·  Noto fonts  ·  Original synthesized audio",Vector2(363,270),15,MUTED)
 button(Rect2(363,600,714,52),"Return","back",true)
