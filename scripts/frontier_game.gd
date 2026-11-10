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
const VIEW=Rect2(0,84,1440,546)
const MINIMAP=Rect2(1183,642,226,140)
const ORDER=["wood","stone","arrow","wall","cannon","market"]
const SAVE_PATH="user://frontier-settlement.json"
const SETTINGS_PATH="user://settings.json"
var sim
var screen:="menu"
var return_screen:="menu"
var selected:=0
var build_kind:=""
var ghost:=Map.HALL-Vector2(220,0)
var camera_center:=Map.HALL-Vector2(110,0)
var zoom:=0.85
var world_container:Control
var world:Node2D
var buttons:Array=[]
var mouse:=Vector2(-100,-100)
var clock:=0.0
var accumulator:=0.0
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
var trade_feedback:=""
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
    camera_center-=event.relative/zoom
    apply_camera()
  elif screen=="mission" and VIEW.has_point(mouse): ghost=sim.snap_position(screen_to_world(mouse))
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
   elif pointer_down:
    pointer_down=false
    if not dragged and VIEW.has_point(mouse): click_world(mouse)
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
   elif touches.size()==2:
    dragged=true
    var points:Array=touches.values()
    pinch_distance=points[0].distance_to(points[1])
  else:
   touches.erase(event.index)
   if touches.is_empty():
    if pointer_down and not dragged and VIEW.has_point(event.position): click_world(event.position)
    pointer_down=false
    pinch_distance=0
 if event is InputEventScreenDrag and touches.has(event.index):
  touches[event.index]=event.position
  if not pointer_down or screen!="mission": return
  if touches.size()>=2:
   var points:Array=touches.values()
   var distance:float=points[0].distance_to(points[1])
   if pinch_distance>0: zoom_at((points[0]+points[1])/2,zoom*distance/pinch_distance)
   pinch_distance=distance
   dragged=true
  else:
   if event.position.distance_to(pointer_start)>8: dragged=true
   if dragged:
    camera_center-=event.relative/zoom
    apply_camera()
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE: go_back()
  elif event.keycode==KEY_SPACE and screen in ["mission","pause"]: act("pause" if screen=="mission" else "resume")
  elif screen=="mission":
   if event.keycode>=KEY_1 and event.keycode<=KEY_6: act("build:"+ORDER[event.keycode-KEY_1])
   if event.keycode==KEY_U: act("upgrade")
   if event.keycode==KEY_R: act("repair")
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
  ghost=sim.snap_position(at)
  var error:String=sim.build_at(ghost,build_kind)
  if error!="": notify(error)
  else:
   for i in sim.buildings.size():
    if sim.buildings[i]!=null and sim.buildings[i].pos==ghost: selected=i
   play_sound("build")
   consume_events()
  return
 var candidates:Array=[]
 for i in sim.buildings.size():
  var b=sim.buildings[i]
  if b==null: continue
  var size:Vector2=Art.BUILD_SIZES[Sim.DEFINITIONS[b.kind].art]
  if b.hp<=0: size=Vector2(140,100)
  var rect:=Rect2(b.pos-Vector2(size.x/2,size.y),size+Vector2(0,20))
  if rect.has_point(at): candidates.append(i)
 if not candidates.is_empty():
  candidates.sort_custom(func(a,b):return sim.buildings[a].pos.y>sim.buildings[b].pos.y)
  selected=candidates[0]
  return
 for i in sim.resource_nodes.size():
  if at.distance_to(sim.resource_nodes[i].pos)<75:
   if sim.collect(i):
    play_sound("gather")
    consume_events()
   else: notify("This deposit replenishes in %ds."%ceili(sim.deposits[i]))
   return
 selected=-1

func act(action:String)->void:
 if action.begins_with("build:"):
  var kind:String=action.trim_prefix("build:")
  build_kind="" if build_kind==kind else kind
  ghost=sim.snap_position(camera_center)
  if build_kind!="": notify("Choose open ground. Drag to move the camera. Back cancels construction.")
  return
 match action:
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
  "settings","guide","credits","trade":
   return_screen=screen
   screen=action
   trade_feedback=""
  "back": screen=return_screen
  "upgrade","repair":
   var error:String=sim.upgrade_at(selected) if action=="upgrade" else sim.repair_at(selected)
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
  "speed": speed=2 if speed==1 else 1
  "cancel": build_kind=""
  "endless":
   screen="mission"
   notify("The frontier is secured. The endless siege continues.")
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
  "trade_wood","trade_stone":
   trade_feedback="Supplies sold." if sim.trade(action.trim_prefix("trade_")) else "An active marketplace and 60 supplies are required."
  "buy_wood","buy_stone":
   trade_feedback="Supplies purchased." if sim.buy(action.trim_prefix("buy_")) else "An active marketplace and 60 gold are required."

func go_back()->void:
 match screen:
  "menu":
   save_game()
   get_tree().quit()
  "mission":
   if build_kind!="": build_kind=""
   else: act("pause")
  "pause": act("resume")
  "settings","guide","credits","trade": act("back")
  "briefing","confirm": screen="menu"
  "dismantle": screen="mission"
  "victory": act("endless")
  "defeat": act("menu")

func start_mission()->void:
 sim=Sim.new(int(Time.get_unix_time_from_system())%100000)
 screen="mission"
 selected=0
 speed=1
 build_kind=""
 camera_center=Map.HALL-Vector2(120,0)
 zoom=0.85
 apply_camera()
 fx.clear()
 accumulator=0
 autosave=0
 save_available=true
 notify("Raiders are already approaching. The main hall will fire. Establish your economy.")
 save_game()

func consume_events()->void:
 for e in sim.events:
  if e.type in ["shot","hit","kill","build","gather","ruin"]:
   e.time=0.35 if e.type=="shot" else 1.2
   e.duration=e.time
   if fx.size()<180: fx.append(e)
  if e.type=="wave" and sim.wave>1: notify("Wave %d · %s"%[sim.wave,"A great horde is coming" if sim.wave%5==0 else "Movement on the western road"])
  if e.type=="ruin":
   notify("Ground cleared. New foundations can be placed here." if e.text=="Ground cleared" else "A structure has collapsed. Repair its ruins or clear the ground.")
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
 buttons.append({"rect":rect,"action":action,"enabled":enabled})

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
 elif screen=="trade": draw_trade()
 elif screen=="dismantle":
  overlay(Rect2(410,215,620,370),"DISMANTLE STRUCTURE","Clear these foundations?","The building and its upgrades are removed. Standing structures return 25% of their original construction materials. Ruins can also be repaired.")
  button(Rect2(450,495,250,55),"Keep building","cancel_clear")
  button(Rect2(720,495,270,55),"Clear the ground","confirm_clear",true)
 if toast_left>0 and screen=="mission":
  var w:float=minf(1040,Body.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+48)
  var rect:=Rect2((1440-w)/2,96,w,40)
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
 button(Rect2(80,580,185,50),"Field guide","guide",false,true,17)
 button(Rect2(280,580,190,50),"Settings","settings",false,true,17)
 button(Rect2(80,646,185,46),"Credits","credits",false,true,16)
 label("SINGLE PLAYER   /   OFFLINE",Vector2(83,754),13,MUTED)
 Art.skin(self,Rect2(971,620,414,142),Color(0.87,0.9,0.83))
 label("MISSION 01",Vector2(997,650),13,GOLD)
 label("The Pinewatch Frontier",Vector2(996,685),26,IVORY,true)
 wrapped("A vast valley. One approach. Fifteen minutes to secure your foothold.",Vector2(997,716),360,15,MUTED,23)
 if best>0:
  Art.skin(self,Rect2(1170,27,230,43),Color(0.86,0.9,0.83),9)
  centered("BEST HOLD  "+time_label(best),Rect2(1170,27,230,43),14,IVORY)

func draw_hud()->void:
 Art.skin(self,Rect2(-4,-5,1448,94),Color(0.82,0.87,0.8),14)
 Art.icon(self,4,Rect2(21,18,46,46))
 label("PINEWATCH",Vector2(79,34),23,IVORY,true)
 label("FRONTIER  /  ENDLESS" if sim.victory else "HOLD THE MAIN HALL",Vector2(80,58),11,GOLD)
 var rates:Dictionary=sim.income_rates()
 for i in 3:
  var x:float=284+i*173
  Art.icon(self,i,Rect2(x,17,43,43))
  label(pretty(sim.resources[Sim.RESOURCE_NAMES[i]]),Vector2(x+52,38),25,IVORY)
  label("+%.1f / sec"%rates[Sim.RESOURCE_NAMES[i]],Vector2(x+52,61),12,GREEN)
 Art.icon(self,5,Rect2(811,20,35,35))
 label(time_label(sim.elapsed)+( " +" if sim.victory else " / 15:00"),Vector2(854,39),22,IVORY)
 label("WAVE %02d   ·   %d DEFEATED"%[sim.wave,sim.kills],Vector2(854,62),11,GOLD)
 button(Rect2(1066,15,69,55),"%d×"%speed,"speed",false,true,18)
 button(Rect2(1145,15,101,55),"Guide","guide",false,true,16)
 button(Rect2(1257,15,162,55),"Ⅱ  Pause","pause",false,true,18)
 # Compact, persistent command deck leaves the landscape unobstructed.
 Art.skin(self,Rect2(-4,629,1448,187),Color(0.83,0.89,0.82),14)
 draw_inspector()
 for i in ORDER.size():
  var kind:String=ORDER[i]
  var definition:Dictionary=Sim.DEFINITIONS[kind]
  var rect:=Rect2(385+i*128,640,122,155)
  var active:bool=build_kind==kind
  Art.skin(self,rect,Color(1.4,1.22,0.86) if active else (Color(1.08,1.08,0.96) if rect.has_point(mouse) else Color(0.8,0.86,0.8)),8)
  var art_scale:float=0.29 if kind not in ["arrow","cannon"] else 0.25
  Art.building(self,definition.art,Vector2(rect.position.x+61,rect.position.y+78),art_scale)
  label(str(i+1),rect.position+Vector2(10,19),11,MUTED)
  centered(definition.name,Rect2(rect.position.x,rect.position.y+91,122,28),14,GOLD if active else IVORY)
  for r in 3:
   Art.icon(self,r,Rect2(rect.position.x+7+r*39,rect.position.y+129,14,14))
   label(pretty(definition.cost[r]),rect.position+Vector2(21+r*39,141),13,IVORY if sim.resources[Sim.RESOURCE_NAMES[r]]>=definition.cost[r] else RED)
  buttons.append({"rect":rect,"action":"build:"+kind,"enabled":true})
 draw_minimap()
 button(Rect2(1194,570,56,48),"−","zoom_out",false,true,24)
 button(Rect2(1256,570,56,48),"+","zoom_in",false,true,24)
 button(Rect2(1318,570,91,48),"Hall","hall",false,true,16)
 if build_kind!="":
  button(Rect2(19,574,213,46),"Cancel construction","cancel",false,true,15)
  var error:String=sim.placement_error(ghost,build_kind)
  if error!="": label(error,Vector2(249,605),14,RED)

func draw_inspector()->void:
 if build_kind!="":
  var d:Dictionary=Sim.DEFINITIONS[build_kind]
  label(d.name,Vector2(24,668),24,IVORY,true)
  wrapped(d.desc,Vector2(25,697),322,14,MUTED,22)
  cost_row(d.cost,Vector2(25,780),16)
  return
 if selected<0 or selected>=sim.buildings.size() or sim.buildings[selected]==null:
  label("THE PINEWATCH FRONTIER",Vector2(24,669),18,GOLD,true)
  wrapped("Expand into the valley. Select a structure to upgrade, repair or dismantle it.",Vector2(25,700),322,16,MUTED,26)
  return
 var b:Dictionary=sim.buildings[selected]
 var d:Dictionary=Sim.DEFINITIONS[b.kind]
 label(d.name,Vector2(24,669),23,IVORY,true)
 label("Lv. %d / 100"%b.level,Vector2(255,668),14,GOLD)
 var status:String="RUINS · REPAIR TO RESTORE" if b.hp<=0 else "%s / %s HP"%[pretty(b.hp),pretty(sim.stat(b,"hp"))]
 if b.hp>0 and d.has("income"): status+="  ·  +%.1f %s/s"%[sim.stat(b,"income")*sim.production_bonus(b),d.resource]
 elif b.hp>0 and d.has("damage"): status+="  ·  %s damage"%pretty(sim.stat(b,"damage"))
 if b.hp>0 and b.age<Sim.BUILD_TIME: status="CONSTRUCTION  ·  %.1fs remaining"%(Sim.BUILD_TIME-b.age)
 label(status,Vector2(25,695),13,RED if b.hp<=0 else MUTED)
 var upgrade:Array=sim.upgrade_cost(b) if b.level<100 else [0,0,0]
 var show_repair:bool=b.hp<sim.stat(b,"hp")*0.7
 var shown_cost:Array=sim.repair_cost(b) if show_repair else upgrade
 cost_row(shown_cost,Vector2(25,723),14)
 label("REPAIR" if show_repair else "UPGRADE",Vector2(285,723),10,MUTED)
 button(Rect2(22,739,112,56),"Upgrade ↑","upgrade",true,b.hp>0 and b.level<100 and sim.can_afford(upgrade),15)
 button(Rect2(141,739,105,56),"Repair","repair",false,b.hp<sim.stat(b,"hp")-0.01 and sim.can_afford(sim.repair_cost(b)),15)
 button(Rect2(253,739,104,56),"Clear ruins" if b.hp<=0 else "Dismantle","clear",false,selected>0,13)
 if b.kind=="market" and b.hp>0: button(Rect2(24,570,240,48),"Open marketplace","trade",true,true,17)

func draw_minimap()->void:
 Art.skin(self,Rect2(1170,630,253,166),Color(0.9,0.93,0.86),10)
 if world.ground_view!=null: draw_texture_rect(world.ground_view.get_texture(),MINIMAP,false,Color(0.79,0.88,0.75))
 var path:=PackedVector2Array()
 for p in Map.ROAD: path.append(MINIMAP.position+p/Map.SIZE*MINIMAP.size)
 draw_polyline(path,Color("c6ae7c"),1.3,true)
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
 overlay(Rect2(355,105,730,600),"MISSION 01  /  THE PINEWATCH FRONTIER","Carve a foothold in the valley.","The western road carries the first raiders. Keep your main hall standing for fifteen minutes, then continue the endless siege.")
 var rows:=[["01","Expand freely","Place buildings on any clear ground. A woodcutter near trees and a stonemason near a quarry earn a production bonus."],["02","Build a defensive line","Walls, arrow towers and cannons can be placed wherever your strategy needs them. Great hordes arrive every fifth wave."],["03","Recover from destruction","Collapsed buildings leave ruins. Repair them to keep their upgrades, or clear the ground and rebuild."]]
 for i in 3:
  var y:float=343+i*88
  label(rows[i][0],Vector2(395,y),27,GOLD,true)
  label(rows[i][1],Vector2(452,y-2),20,IVORY)
  wrapped(rows[i][2],Vector2(452,y+24),578,14,MUTED,22)
 button(Rect2(394,625,152,51),"Back","menu_back")
 button(Rect2(562,625,483,51),"Establish Pinewatch","start",true)

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
  button(Rect2(424,555,184,52),"Settings","settings",false,true,17)
  button(Rect2(628,555,184,52),"Field guide","guide",false,true,17)
  button(Rect2(832,555,184,52),"Save & menu","menu",false,true,16)
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
 var entries:=[["Explore the frontier","Drag the landscape to pan. Pinch or use the + / − buttons to zoom. Tap the minimap to travel; Hall returns to your main building."],["Place buildings freely","Choose a construction card, then tap clear ground. Water, ridges, deposits and existing foundations cannot be built over."],["Gather and produce","Tap timber, stone or gold deposits. They replenish in 12 seconds. Place producers near their resource for a 25% income bonus."],["Hold the western approach","Raiders follow one road. Place walls in their way and cover them with towers. Your main hall attacks from the beginning."],["Upgrade, repair or clear","All seven structures reach level 100. Destroyed buildings leave repairable ruins. Dismantling frees the ground but loses the upgrades."],["Secure the foothold","Survive 15 in-game minutes to win, then continue endlessly. Every fifth wave is a great horde. App switching pauses and saves."]]
 for i in entries.size():
  var p:=Vector2(274+(i%2)*462,245+(i/2)*141)
  label("0%d  %s"%[i+1,entries[i][0]],p,19,IVORY,true)
  wrapped(entries[i][1],p+Vector2(0,30),414,14,MUTED,24)
 label("DESKTOP   WASD / drag: pan   ·   Wheel: zoom   ·   1–6: build   ·   U: upgrade   ·   R: repair   ·   F: hall",Vector2(274,692),11,MUTED)
 button(Rect2(994,675,171,46),"Understood","back",true,true,16)

func draw_credits()->void:
 overlay(Rect2(325,94,790,600),"ART, AUDIO & ENGINE","Tabara: Last Hearth")
 label("Original image-generated scenery, unit sprites and interface art.",Vector2(363,241),17,IVORY)
 label("Godot 4.6.3  ·  Noto fonts  ·  Original synthesized audio",Vector2(363,270),15,MUTED)
 button(Rect2(363,600,714,52),"Return","back",true)

func draw_trade()->void:
 overlay(Rect2(360,110,720,590),"PINEWATCH MARKETPLACE","Keep the stores supplied.","Buy what you need or sell surplus production. The settlement is paused while you trade.")
 var level:=1
 for b in sim.buildings:
  if b!=null and b.kind=="market" and b.hp>0: level=maxi(level,b.level)
 var proceeds:=30+mini(25,level-1)
 for i in 3:
  Art.icon(self,i,Rect2(402+i*221,283,36,36))
  label(pretty(sim.resources[Sim.RESOURCE_NAMES[i]]),Vector2(447+i*221,311),24,IVORY)
 button(Rect2(401,349,310,60),"Buy 60 wood · 60 gold","buy_wood",true,sim.resources.gold>=60,17)
 button(Rect2(731,349,310,60),"Buy 60 stone · 60 gold","buy_stone",true,sim.resources.gold>=60,17)
 button(Rect2(401,430,310,60),"Sell 60 wood · +%d gold"%proceeds,"trade_wood",false,sim.resources.wood>=60,16)
 button(Rect2(731,430,310,60),"Sell 60 stone · +%d gold"%proceeds,"trade_stone",false,sim.resources.stone>=60,16)
 wrapped(trade_feedback if trade_feedback!="" else "Marketplace upgrades improve your selling price.",Vector2(402,543),630,16,GOLD,26)
 button(Rect2(401,610,640,51),"Return to the frontier","back",true)
