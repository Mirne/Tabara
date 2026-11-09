extends Control
## Fixed logical canvas: touch and mouse share the same input coordinates.

const Sim = preload("res://scripts/simulation.gd")
const Atlas = preload("res://assets/art/buildings.png")
const Body = preload("res://assets/fonts/Body.ttf")
const Title = preload("res://assets/fonts/Title.ttf")
const INK := Color("253c36")
const MUTED := Color("788478")
const PAPER := Color("f3eddf")
const GOLD := Color("dba95a")
const TEAL := Color("357b6d")
const RED := Color("b65e49")
const SAVE_PATH := "user://settlement.json"
const SETTINGS_PATH := "user://settings.json"
const BUILD_ORDER := ["wood","stone","arrow","wall","cannon","market"]
const ART_SIZES := [Vector2(142,151),Vector2(105,106),Vector2(108,106),Vector2(97,126),Vector2(100,82),Vector2(102,116),Vector2(109,108),Vector2(132,115)]
var sim: Settlement
var screen := "menu"
var return_screen := "menu"
var selected := 0
var build_kind := ""
var buttons: Array = []
var mouse := Vector2(-100,-100)
var clock := 0.0
var accumulator := 0.0
var speed := 1
var autosave := 0.0
var fx: Array = []
var toast := ""
var toast_left := 0.0
var sound_on := true
var music_on := true
var reduced_motion := false
var confirm_new := false
var save_available := false
var best := 0.0
var victory_count := 0
var sfx_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var sounds: Dictionary = {}
var terrain_view: SubViewport
var style_cache: Dictionary = {}
var menu_settlement: Settlement
var license_label: RichTextLabel

func _ready() -> void:
 get_tree().auto_accept_quit = false
 load_settings()
 load_saved_game()
 menu_settlement = Sim.new(17)
 for entry in [[1,"wood"],[2,"stone"],[3,"market"],[4,"arrow"],[5,"arrow"],[6,"cannon"],[9,"wall"],[10,"wall"],[11,"arrow"]]:
  menu_settlement.buildings[entry[0]] = menu_settlement.make_building(entry[1])
 terrain_view = SubViewport.new()
 terrain_view.size = Vector2i(1120,690)
 terrain_view.transparent_bg = true
 terrain_view.render_target_update_mode = SubViewport.UPDATE_ONCE
 terrain_view.world_2d = World2D.new()
 terrain_view.disable_3d = true
 var terrain := Node2D.new()
 terrain.set_script(preload("res://scripts/terrain.gd"))
 terrain_view.add_child(terrain)
 add_child(terrain_view)
 sfx_player = AudioStreamPlayer.new()
 sfx_player.volume_db = -12
 add_child(sfx_player)
 for key in ["click","build","gather","cannon","victory","defeat"]:
  var path := "res://assets/audio/%s.wav" % key
  if ResourceLoader.exists(path): sounds[key] = load(path)
 music_player = AudioStreamPlayer.new()
 music_player.volume_db = -22
 add_child(music_player)
 if ResourceLoader.exists("res://assets/audio/hearth.ogg"):
  var ambience: AudioStreamOggVorbis = load("res://assets/audio/hearth.ogg")
  ambience.loop = true
  music_player.stream = ambience
  if music_on: music_player.play()
 if "--mission" in OS.get_cmdline_user_args(): start_mission()
 license_label = RichTextLabel.new()
 license_label.position = Vector2(396,336)
 license_label.size = Vector2(648,226)
 license_label.add_theme_font_override("normal_font",Body)
 license_label.add_theme_font_size_override("normal_font_size",12)
 license_label.add_theme_color_override("default_color",INK)
 license_label.text = "GODOT ENGINE — MIT LICENSE\n\n"+Engine.get_license_text()+"\n\nTHIRD-PARTY ENGINE NOTICES\n\n"+str(Engine.get_license_info())+"\n\nNOTO FONTS — SIL OPEN FONT LICENSE 1.1\n\n"+FileAccess.get_file_as_string("res://assets/fonts/OFL.txt")
 license_label.visible = false
 add_child(license_label)
 queue_redraw()

func _process(delta: float) -> void:
 if license_label != null: license_label.visible = screen == "credits"
 clock += delta
 toast_left = maxf(0,toast_left-delta)
 if screen == "mission" and sim != null:
  accumulator += minf(delta,0.15)*speed
  while accumulator >= 0.05:
   sim.step(0.05)
   accumulator -= 0.05
   consume_events()
   if sim.defeated or (sim.victory and not sim.victory_seen): break
  autosave += delta
  if autosave >= 10.0:
   save_game()
   autosave = 0.0
  if sim.defeated:
   screen = "defeat"
   best = maxf(best,sim.elapsed)
   save_settings()
   save_game()
   play_sound("defeat")
  elif sim.victory and not sim.victory_seen:
   screen = "victory"
   victory_count += 1
   best = maxf(best,sim.elapsed)
   sim.victory_seen = true
   save_settings()
   save_game()
   play_sound("victory")
 for i in range(fx.size()-1,-1,-1):
  fx[i].time -= delta
  if fx[i].time <= 0: fx.remove_at(i)
 mouse_default_cursor_shape = Control.CURSOR_ARROW
 for b in buttons:
  if b.rect.has_point(mouse) and b.enabled: mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 queue_redraw()

func consume_events() -> void:
 for e in sim.events:
  if e.type in ["shot","hit","kill","build","gather","ruin"]:
   e.time = 0.30 if e.type == "shot" else 1.1
   e.duration = e.time
   if fx.size() < 100: fx.append(e)
  if e.type == "wave" and sim.wave > 1: notify("Wave %d approaches · Defend the road" % sim.wave)
  if e.type == "ruin": notify("A building is ruined. Select it to repair.")
  if e.type == "shot" and e.cannon and clock-float(get_meta("last_boom",-10.0)) > 0.35:
   play_sound("cannon")
   set_meta("last_boom",clock)
 sim.events.clear()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
  if screen == "mission": screen = "pause"
  if is_node_ready(): save_game()
 if what == NOTIFICATION_WM_CLOSE_REQUEST:
  save_game()
  get_tree().quit()
 if what == NOTIFICATION_WM_GO_BACK_REQUEST:
  go_back()

func _input(event: InputEvent) -> void:
 if event is InputEventMouseMotion:
  mouse = event.position
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
  mouse = event.position
  click_at(event.position)
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_ESCAPE: go_back()
  if event.keycode == KEY_SPACE and screen in ["mission","pause"]: act("pause" if screen == "mission" else "resume")
  if screen == "mission":
   if event.keycode >= KEY_1 and event.keycode <= KEY_6: act("build:"+BUILD_ORDER[event.keycode-KEY_1])
   if event.keycode == KEY_U: act("upgrade")
   if event.keycode == KEY_R: act("repair")

func click_at(point: Vector2) -> void:
 # Modals only register their own buttons, preventing clicks on the world below.
 for i in range(buttons.size()-1,-1,-1):
  if buttons[i].rect.has_point(point):
   if buttons[i].enabled:
    play_sound("click")
    act(buttons[i].action)
   return
 if screen != "mission": return
 for i in Sim.DEPOSITS.size():
  if point.distance_to(Sim.DEPOSITS[i].pos) < 38:
   if sim.collect(i):
    consume_events()
    play_sound("gather")
   else: notify("Supplies replenish in %ds" % ceili(sim.deposits[i]))
   return
 # Favor an already selected construction tool when choosing empty plots.
 var chosen := -1
 var distance := 58.0
 for i in Sim.PADS.size():
  var p: Vector2 = Sim.PADS[i].pos
  var center := p-Vector2(0,30) if sim.buildings[i] != null else p
  var d := point.distance_to(center)
  if d < distance:
   distance = d
   chosen = i
 if chosen >= 0:
  selected = chosen
  if sim.buildings[chosen] == null and build_kind != "":
   var error := sim.build_at(chosen,build_kind)
   if error != "": notify(error)
   else:
    build_kind = ""
    play_sound("build")
    consume_events()
  else: build_kind = ""
 else:
  selected = -1
  build_kind = ""

func act(action: String) -> void:
 if action.begins_with("build:"):
  var kind := action.trim_prefix("build:")
  if selected > 0 and sim.buildings[selected] == null:
   var error := sim.build_at(selected,kind)
   if error != "":
    notify(error)
    build_kind = kind
   else:
    build_kind = ""
    consume_events()
    play_sound("build")
  else:
   build_kind = "" if build_kind == kind else kind
   if build_kind != "": notify("Tap a road checkpoint." if kind == "wall" else "Tap a glowing empty plot to build.")
  return
 match action:
  "new":
   if save_available:
    confirm_new = true
    screen = "confirm"
   else: screen = "briefing"
  "confirm_new":
   confirm_new = false
   screen = "briefing"
  "start": start_mission()
  "continue":
   if sim != null and not sim.defeated:
    screen = "mission"
    accumulator = 0
  "pause":
   screen = "pause"
   save_game()
  "resume": screen = "mission"
  "menu":
   save_game()
   screen = "menu"
   build_kind = ""
  "settings", "credits":
   return_screen = screen
   screen = action
  "guide":
   return_screen = screen
   screen = "guide"
  "back": screen = return_screen
  "menu_back": screen = "menu"
  "upgrade":
   var error := sim.upgrade_at(selected)
   if error != "": notify(error)
   else:
    consume_events()
    play_sound("build")
  "repair":
   var error := sim.repair_at(selected)
   if error != "": notify(error)
   else:
    consume_events()
    play_sound("build")
  "speed": speed = 2 if speed == 1 else 1
  "cancel": build_kind = ""
  "endless":
   screen = "mission"
   notify("Endless survival · Hold for as long as you can")
  "sound":
   sound_on = not sound_on
   save_settings()
  "music":
   music_on = not music_on
   if music_on: music_player.play()
   else: music_player.stop()
   save_settings()
  "motion":
   reduced_motion = not reduced_motion
   save_settings()
  "trade_wood", "trade_stone":
   if sim.trade(action.trim_prefix("trade_")):
    notify("Trade complete · Gold added to your treasury")
    play_sound("gather")
   else: notify("You need an active marketplace and 60 supplies.")

func go_back() -> void:
 match screen:
  "menu":
   save_game()
   get_tree().quit()
  "mission":
   if build_kind != "": build_kind = ""
   else: act("pause")
  "pause": act("resume")
  "settings","guide","credits": act("back")
  "briefing","confirm": screen = "menu"
  "victory": act("endless")
  "defeat": act("menu")

func start_mission() -> void:
 sim = Sim.new(int(Time.get_unix_time_from_system()) % 100000)
 screen = "mission"
 selected = 0
 speed = 1
 build_kind = ""
 fx.clear()
 accumulator = 0
 autosave = 0
 save_available = true
 notify("The enemy is on the road. Build an economy, then fortify the checkpoints.")
 save_game()

func notify(message: String) -> void:
 toast = message
 toast_left = 4.0

func play_sound(key: String) -> void:
 if sound_on and sounds.has(key):
  sfx_player.stream = sounds[key]
  sfx_player.play()

func save_game() -> void:
 if sim == null: return
 best = maxf(best,sim.elapsed)
 var file := FileAccess.open(SAVE_PATH+".tmp",FileAccess.WRITE)
 if file == null:
  notify("Could not save. Check available device storage.")
  return
 file.store_string(JSON.stringify(sim.snapshot()))
 file.close()
 var error := DirAccess.rename_absolute(SAVE_PATH+".tmp",SAVE_PATH)
 if error != OK: notify("Could not finish saving. Check device storage.")
 save_available = not sim.defeated
 save_settings()

func load_saved_game() -> void:
 if not FileAccess.file_exists(SAVE_PATH): return
 var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
 if not data is Dictionary: return
 sim = Sim.restore(data)
 if sim != null: save_available = not sim.defeated

func load_settings() -> void:
 if not FileAccess.file_exists(SETTINGS_PATH): return
 var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
 if not data is Dictionary: return
 sound_on = bool(data.get("sound",true))
 music_on = bool(data.get("music",true))
 reduced_motion = bool(data.get("motion",false))
 best = float(data.get("best",0))
 victory_count = int(data.get("victories",0))

func save_settings() -> void:
 var file := FileAccess.open(SETTINGS_PATH,FileAccess.WRITE)
 if file != null: file.store_string(JSON.stringify({"sound":sound_on,"music":music_on,"motion":reduced_motion,"best":best,"victories":victory_count}))

func _draw() -> void:
 buttons.clear()
 draw_rect(Rect2(0,0,1440,810),Color("172e2c"))
 if screen in ["menu","briefing","confirm"]:
  draw_menu()
  if screen == "briefing": draw_briefing()
  if screen == "confirm": draw_confirm()
 elif screen in ["settings","guide","credits"]:
  if return_screen == "menu": draw_menu()
  else: draw_mission()
  buttons.clear()
  if screen == "settings": draw_settings()
  elif screen == "credits": draw_credits()
  else: draw_guide()
 else:
  draw_mission()
  if screen != "mission":
   buttons.clear()
   draw_end_overlay()
 if toast_left > 0 and screen == "mission":
  var w := minf(1000,Body.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x+44)
  panel(Rect2((1120-w)/2,650,w,38),Color("243e35"),10)
  text_at(toast,Vector2((1120-w)/2+22,675),17,PAPER)

func panel(rect: Rect2, color: Color, radius: int = 12, border: Color = Color.TRANSPARENT, width: int = 1) -> void:
 var cache_key := "%s:%d:%s:%d" % [color.to_html(),radius,border.to_html(),width]
 var style: StyleBoxFlat
 if style_cache.has(cache_key): style = style_cache[cache_key]
 else:
  style = StyleBoxFlat.new()
  style.bg_color = color
  style.set_corner_radius_all(radius)
  style.border_color = border
  style.set_border_width_all(width)
  # Transient effect colors should not grow this cache without bound.
  if style_cache.size() < 160: style_cache[cache_key] = style
 draw_style_box(style,rect)

func text_at(value: String, pos: Vector2, size_px: int = 18, color: Color = INK, heading: bool = false) -> void:
 draw_string(Title if heading else Body,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func centered(value: String, rect: Rect2, size_px: int, color: Color = INK, heading: bool = false) -> void:
 var font: Font = Title if heading else Body
 var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x
 text_at(value,Vector2(rect.position.x+(rect.size.x-width)/2,rect.position.y+rect.size.y/2+size_px*0.34),size_px,color,heading)

func wrapped(value: String, pos: Vector2, width: float, size_px: int = 17, color: Color = MUTED, line_height: int = 27) -> void:
 var line := ""
 var y := pos.y
 for word in value.split(" "):
  if Body.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x > width and line != "":
   text_at(line.strip_edges(),Vector2(pos.x,y),size_px,color)
   y += line_height
   line = ""
  line += word+" "
 text_at(line.strip_edges(),Vector2(pos.x,y),size_px,color)

func button(rect: Rect2, label: String, action: String, primary: bool = false, enabled: bool = true, font_size: int = 18) -> void:
 var over := rect.has_point(mouse) and enabled
 var color := TEAL if primary else Color("e8e2d4")
 if over: color = color.lightened(0.10) if primary else Color("d9dfd0")
 if not enabled: color = Color("e3dfd5")
 panel(rect,color,9,Color("d7d5c7") if not primary else Color.TRANSPARENT)
 centered(label,rect,font_size,PAPER if primary else (INK if enabled else Color("aaa99d")))
 buttons.append({"rect":rect,"action":action,"enabled":enabled})

func line(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
 draw_line(from,to,color,width,true)

func bar(rect: Rect2, fraction: float, color: Color) -> void:
 panel(rect,Color("d9dbcb"),int(rect.size.y/2))
 if fraction > 0: panel(Rect2(rect.position,Vector2(maxf(rect.size.y,rect.size.x*clampf(fraction,0,1)),rect.size.y)),color,int(rect.size.y/2))

func icon(kind: String, pos: Vector2, radius: float = 9.0) -> void:
 match kind:
  "wood":
   line(pos+Vector2(-radius,5),pos+Vector2(radius,-4),Color("986c44"),radius)
   draw_circle(pos+Vector2(radius,-4),radius*0.52,Color("dbb77f"))
   draw_arc(pos+Vector2(radius,-4),radius*0.27,0,TAU,16,Color("986c44"),1.2,true)
  "stone":
   draw_colored_polygon(PackedVector2Array([pos+Vector2(-radius,6),pos+Vector2(-radius*0.6,-5),pos+Vector2(3,-radius),pos+Vector2(radius,0),pos+Vector2(6,radius)]),Color("99a29b"))
   line(pos+Vector2(-6,-3),pos+Vector2(1,2),Color("d9dfd0"),2)
  "gold":
   draw_circle(pos,radius,Color("d9a246"))
   draw_arc(pos,radius*0.7,0,TAU,20,Color("f6d895"),1.5,true)
  "heart":
   draw_colored_polygon(PackedVector2Array([pos+Vector2(0,8),pos+Vector2(-10,-1),pos+Vector2(-6,-7),pos+Vector2(0,-3),pos+Vector2(6,-7),pos+Vector2(10,-1)]),RED)

func sprite(art: int, base: Vector2, scale_value: float = 1.0, tint: Color = Color.WHITE) -> void:
 var dimensions: Vector2 = ART_SIZES[art]*scale_value
 var source := Rect2((art%4)*384,floori(float(art)/4.0)*512,384,512)
 draw_texture_rect_region(Atlas,Rect2(base.x-dimensions.x/2,base.y-dimensions.y,dimensions.x,dimensions.y),source,tint)

func pretty(value: float) -> String:
 if value >= 1e9: return "%.1fB" % (value/1e9)
 if value >= 1e6: return "%.1fM" % (value/1e6)
 if value >= 10000: return "%.1fk" % (value/1000)
 return str(int(value))

func time_label(seconds: float) -> String:
 return "%02d:%02d" % [int(seconds)/60,int(seconds)%60]

func cost_row(cost: Array, pos: Vector2, small: bool = false) -> void:
 var x := pos.x
 for i in 3:
  if cost[i] <= 0: continue
  icon(Sim.RESOURCE_NAMES[i],Vector2(x+4 if small else x+8,pos.y-4 if small else pos.y-5),5 if small else 8)
  var label := pretty(cost[i])
  text_at(label,Vector2(x+14 if small else x+23,pos.y),11 if small else 16,INK if sim == null or sim.resources[Sim.RESOURCE_NAMES[i]] >= cost[i] else RED)
  x += (22 if small else 39)+Body.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,11 if small else 16).x

func draw_menu() -> void:
 draw_rect(Rect2(0,0,1440,810),Color("1e3832"))
 # A living miniature of the same frontier, behind the menu card.
 var old_sim = sim
 if sim == null: sim = menu_settlement
 draw_set_transform(Vector2(405,60),0,Vector2(0.9,0.9))
 draw_world(true)
 draw_set_transform(Vector2.ZERO)
 sim = old_sim
 draw_rect(Rect2(0,0,640,810),Color("1b342f"))
 panel(Rect2(38,29,47,47),GOLD,13)
 centered("T",Rect2(38,29,47,47),30,INK,true)
 text_at("TABARA",Vector2(101,60),20,PAPER)
 text_at("A FRONTIER SURVIVAL GAME",Vector2(46,175),14,GOLD)
 text_at("One road.",Vector2(42,260),64,PAPER,true)
 text_at("One last hearth.",Vector2(42,335),64,PAPER,true)
 wrapped("Raise a settlement. Gather what you need. Hold the road against the coming tide.",Vector2(47,390),470,20,Color("bcc8b7"),32)
 button(Rect2(47,491,418,62),"Continue settlement  →" if save_available else "Begin your story  →","continue" if save_available else "new",true,true,20)
 if save_available: button(Rect2(47,566,202,52),"New mission","new")
 button(Rect2(263 if save_available else 47,566,202,52),"How to play","guide")
 button(Rect2(47,635,202,48),"Settings","settings")
 button(Rect2(263,635,202,48),"Credits","credits")
 text_at("OFFLINE  ·  NO ADS  ·  JUST YOUR SETTLEMENT",Vector2(47,757),12,Color("93a596"))
 panel(Rect2(926,647,455,110),Color("f1ebdd"),14)
 text_at("MISSION 01",Vector2(950,675),12,TEAL)
 text_at("The Pinewatch Road",Vector2(950,709),25,INK,true)
 text_at("Survive 15 minutes. Stay as long as you dare.",Vector2(950,736),15,MUTED)
 if best > 0: text_at("BEST HOLD  "+time_label(best),Vector2(1110,57),15,Color("cfdbbf"))

func draw_world(menu_preview: bool = false) -> void:
 draw_texture(terrain_view.get_texture(),Vector2.ZERO)
 # Plots beneath entities.
 for i in Sim.PADS.size():
  if sim.buildings[i] != null: continue
  var p: Vector2 = Sim.PADS[i].pos
  var gate: bool = Sim.PADS[i].role == "gate"
  var allowed := build_kind != "" and ((build_kind == "wall") == gate)
  var color := Color("f1d38f") if allowed or selected == i else Color("bdc59a")
  diamond(p,Vector2(36,18),Color(0.3,0.39,0.23,0.3))
  diamond(p-Vector2(0,3),Vector2(34,17),Color(color,0.45 if allowed else 0.20))
  draw_polyline(PackedVector2Array([p+Vector2(-34,-3),p+Vector2(0,-20),p+Vector2(34,-3),p+Vector2(0,14),p+Vector2(-34,-3)]),color,1.5,true)
  centered("▥" if gate else "+",Rect2(p.x-20,p.y-23,40,34),23,color)
 # Depth-sort buildings and enemies together by foot position.
 var entities: Array = []
 for i in sim.buildings.size():
  if sim.buildings[i] != null: entities.append({"y":Sim.PADS[i].pos.y,"building":i})
 for e in sim.enemies: entities.append({"y":sim.enemy_position(e).y,"enemy":e})
 entities.sort_custom(func(a,b): return a.y < b.y)
 for entity in entities:
  if entity.has("building"): draw_building(entity.building,menu_preview)
  else: draw_enemy(entity.enemy)
 # Collectible supplies: clear warm rings, cooldown label, and resource symbols.
 for i in Sim.DEPOSITS.size():
  var d: Dictionary = Sim.DEPOSITS[i]
  var p: Vector2 = d.pos
  draw_circle(p+Vector2(0,3),25,Color(0.18,0.25,0.17,0.25))
  var ready: bool = sim.deposits[i] <= 0
  draw_circle(p,23,Color("eee0b1") if ready else Color("adb58b"))
  draw_arc(p,26,0,TAU,32,Color("e7c579") if ready else Color("85946a"),2,true)
  icon(d.kind,p,11)
  if not menu_preview:
   panel(Rect2(p.x-31,p.y+28,62,22),Color("304c3b"),6)
   centered("GATHER" if ready else "%ds" % ceili(sim.deposits[i]),Rect2(p.x-31,p.y+28,62,22),10,PAPER)
 draw_effects()

func diamond(pos: Vector2, half: Vector2, color: Color) -> void:
 draw_colored_polygon(PackedVector2Array([pos+Vector2(-half.x,0),pos+Vector2(0,-half.y),pos+Vector2(half.x,0),pos+Vector2(0,half.y)]),color)

func draw_building(index: int, preview: bool) -> void:
 var b: Dictionary = sim.buildings[index]
 var p: Vector2 = Sim.PADS[index].pos
 var active: bool = b.hp > 0
 if selected == index and not preview:
  diamond(p,Vector2(57,26),Color(0.97,0.84,0.48,0.35))
  if active and Sim.DEFINITIONS[b.kind].has("range"):
   draw_arc(p,sim.stat(b,"range"),0,TAU,100,Color(0.96,0.89,0.65,0.28),1.5,true)
 draw_set_transform(p,0,Vector2(1,0.38))
 draw_circle(Vector2(4,0),45 if b.kind == "hall" else 33,Color(0.18,0.23,0.13,0.23))
 draw_set_transform(Vector2.ZERO)
 if active:
  var anim := 1.0
  if b.age < 0.45 and not reduced_motion: anim = 0.85+0.15*minf(1,b.age/0.45)
  sprite(Sim.DEFINITIONS[b.kind].art,p,anim)
  if not reduced_motion and b.kind in ["hall","wood","stone"]:
   for j in 3:
    var phase := fmod(clock*0.35+j*0.33+index*0.21,1.0)
    var smoke_p := p+Vector2(16+sin(phase*4)*8,-92-phase*34)
    draw_circle(smoke_p,3+phase*6,Color(0.93,0.91,0.78,(1-phase)*0.20))
  if not reduced_motion and b.kind in ["wood","stone"]:
   var worker := p+Vector2(29+sin(clock*0.7+index)*8,-2)
   draw_circle(worker-Vector2(0,9),3.5,Color("dab081"))
   line(worker-Vector2(0,5),worker+Vector2(0,2),Color("476359"),5)
   line(worker-Vector2(0,3),worker+Vector2(8,-8-sin(clock*5)*4),Color("8b6944"),2)
 else:
  sprite(Sim.DEFINITIONS[b.kind].art,p,0.68,Color(0.48,0.46,0.37,0.55))
  for j in 4:
   diamond(p+Vector2(j*13-20,j%2*8-6),Vector2(9,6),Color("a99b78"))
  panel(Rect2(p.x-37,p.y-53,74,25),RED,6)
  centered("RUINED",Rect2(p.x-37,p.y-53,74,25),11,PAPER)
 if not preview:
  var y := p.y+10
  panel(Rect2(p.x-25,y,50,21),INK if active else RED,6)
  centered("Lv. %d" % b.level,Rect2(p.x-25,y,50,21),11,PAPER)
  if active and b.hp < sim.stat(b,"hp")-0.5:
   bar(Rect2(p.x-31,y+25,62,5),b.hp/sim.stat(b,"hp"),TEAL if b.hp/sim.stat(b,"hp") > 0.4 else RED)

func draw_enemy(e: Dictionary) -> void:
 var p := sim.enemy_position(e)
 var moving := 1.0 if e.cooldown <= 0 else 0.35
 var bob := sin(clock*9+e.phase)*2.0*moving if not reduced_motion else 0.0
 var scale_value := 1.0
 if e.kind == "brute": scale_value = 1.35
 if e.kind == "siege": scale_value = 1.7
 draw_set_transform(p,0,Vector2(scale_value,scale_value))
 draw_set_transform(p,0,Vector2(scale_value,scale_value*0.4))
 draw_circle(Vector2(0,2),10,Color(0.13,0.18,0.12,0.28))
 draw_set_transform(p,0,Vector2(scale_value,scale_value))
 var cloak := Color("914d43")
 if e.kind == "runner": cloak = Color("b88343")
 if e.kind == "brute": cloak = Color("65566b")
 if e.kind == "siege": cloak = Color("3c4c55")
 var step_size := sin(clock*10+e.phase)*3 if not reduced_motion else 0.0
 line(Vector2(-3,-5+bob),Vector2(-4+step_size,1),Color("383d31"),3)
 line(Vector2(3,-5+bob),Vector2(4-step_size,1),Color("383d31"),3)
 draw_colored_polygon(PackedVector2Array([Vector2(-7,-6+bob),Vector2(-5,-18+bob),Vector2(5,-18+bob),Vector2(8,-5+bob)]),cloak)
 draw_circle(Vector2(0,-21+bob),5.8,Color("b4b69a"))
 draw_arc(Vector2(0,-21+bob),6,PI,TAU,14,cloak,3.5,true)
 line(Vector2(2,-20+bob),Vector2(4,-20+bob),Color("3a3b2f"),1.8)
 draw_circle(Vector2(-6,-10+bob),5,Color("6e6d58"))
 line(Vector2(8,-10+bob),Vector2(13,-22+bob),Color("d2cdb4"),2.5)
 draw_set_transform(Vector2.ZERO)
 if e.hp < e.max_hp: bar(Rect2(p.x-14,p.y-38*scale_value,28,4),e.hp/e.max_hp,RED)

func draw_effects() -> void:
 for e in fx:
  var alpha: float = clampf(e.time/e.duration,0,1)
  if e.type == "shot":
   var t: float = 1-alpha
   var start: Vector2 = e.from
   var end: Vector2 = e.pos-Vector2(0,12)
   var p := start.lerp(end,minf(1,t*1.7))
   if e.cannon:
    p.y -= sin(t*PI)*55
    draw_circle(p,4,Color("3c3e31"))
    if t > 0.55:
     draw_arc(end,65*(t-0.55)*2,0,TAU,24,Color(0.95,0.66,0.27,alpha),3,true)
     draw_circle(end,22*alpha,Color(0.97,0.79,0.44,alpha*0.55))
   else: line(p,p+(end-start).normalized()*11,Color(0.98,0.91,0.65,alpha),2)
  elif e.type == "kill":
   for j in 4:
    draw_circle(e.pos+Vector2(cos(j*TAU/4),sin(j*TAU/4))*(1-alpha)*20,3*alpha,Color(0.89,0.77,0.47,alpha))
  elif e.type == "hit":
   draw_arc(e.pos-Vector2(0,20),19*(1-alpha),0,TAU,16,Color(0.79,0.28,0.19,alpha*0.8),2,true)
  else:
   var p: Vector2 = e.pos-Vector2(0,55+(1-alpha)*35)
   var label: String = e.text
   var w := Body.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
   panel(Rect2(p.x-w/2-9,p.y-21,w+18,30),Color(0.15,0.28,0.22,alpha),7)
   text_at(label,Vector2(p.x-w/2,p.y),16,Color(0.99,0.91,0.68,alpha))

func draw_mission() -> void:
 if sim == null: return
 draw_rect(Rect2(0,0,1440,810),Color("223d35"))
 draw_world()
 # Top bar and settlement identity.
 panel(Rect2(19,17,1402,86),PAPER,13)
 panel(Rect2(31,29,58,58),INK,11)
 centered("T",Rect2(31,29,58,58),36,GOLD,true)
 text_at("Pinewatch",Vector2(103,52),24,INK,true)
 text_at("MISSION 01  /  "+("ENDLESS" if sim.victory else "HOLD THE ROAD"),Vector2(104,76),11,MUTED)
 var rates := sim.income_rates()
 for i in 3:
  var x := 345+i*171
  icon(Sim.RESOURCE_NAMES[i],Vector2(x,57),12)
  text_at(pretty(sim.resources[Sim.RESOURCE_NAMES[i]]),Vector2(x+25,56),24)
  text_at("+%.1f / sec" % rates[Sim.RESOURCE_NAMES[i]],Vector2(x+25,78),12,TEAL)
 line(Vector2(844,35),Vector2(844,83),Color("d8d8c7"))
 text_at(time_label(sim.elapsed)+(" / 15:00" if not sim.victory else "  +"),Vector2(867,53),22,INK)
 text_at("WAVE %02d  ·  %d DEFEATED" % [sim.wave,sim.kills],Vector2(867,77),11,MUTED)
 button(Rect2(1094,35,69,49),"%d×" % speed,"speed",false,true,19)
 button(Rect2(1175,35,64,49),"?","guide")
 button(Rect2(1251,35,150,49),"Ⅱ  Pause","pause")
 # Mission progress and world header.
 text_at("THE PINEWATCH ROAD",Vector2(39,133),12,Color("c4d0ac"))
 text_at("Single approach · Enemies arrive from the west",Vector2(254,133),12,Color("91a68f"))
 var remaining := maxf(0,Sim.VICTORY_TIME-sim.elapsed)
 text_at("ENDLESS SURVIVAL" if sim.victory else "HOLD FOR "+time_label(remaining),Vector2(888,133),12,GOLD)
 bar(Rect2(39,683,1073,4),fmod(sim.elapsed,30.0)/30.0,Color("c9b16c"))
 draw_side_panel()
 draw_build_bar()

func draw_side_panel() -> void:
 panel(Rect2(1131,118,290,569),PAPER,13)
 var x := 1151.0
 if build_kind != "":
  var d: Dictionary = Sim.DEFINITIONS[build_kind]
  text_at("CONSTRUCTION",Vector2(x,149),11,TEAL)
  text_at(d.name,Vector2(x,184),27,INK,true)
  sprite(d.art,Vector2(1276,329),1.03)
  wrapped(d.desc,Vector2(x,355),247,16,MUTED,25)
  text_at("BUILD COST",Vector2(x,454),11,MUTED)
  cost_row(d.cost,Vector2(x,482))
  wrapped("Tap a road checkpoint to place your wall." if build_kind == "wall" else "Tap any glowing plot to place this building.",Vector2(x,532),245,16,INK,26)
  button(Rect2(x,615,250,49),"Cancel placement","cancel")
  return
 if selected >= 0 and sim.buildings[selected] != null:
  var b: Dictionary = sim.buildings[selected]
  var d: Dictionary = Sim.DEFINITIONS[b.kind]
  text_at(d.tag,Vector2(x,148),10,TEAL)
  text_at(d.name,Vector2(x,184),27,INK,true)
  text_at("LEVEL %d / 100" % b.level,Vector2(x,211),12,MUTED)
  panel(Rect2(1344,195,56,24),Color("e6dbc3"),6)
  centered("Lv. %d" % b.level,Rect2(1344,195,56,24),11,INK)
  icon("heart",Vector2(x+8,244),9)
  text_at(pretty(b.hp)+" / "+pretty(sim.stat(b,"hp")),Vector2(x+28,249),17,RED if b.hp <= 0 else INK)
  bar(Rect2(x,262,250,7),b.hp/sim.stat(b,"hp"),TEAL if b.hp > 0 else RED)
  var desc: String = d.desc
  if b.hp <= 0: desc = "This building is ruined. Its foundations and upgrades remain. Repair it to restore operation."
  wrapped(desc,Vector2(x,298),247,15,MUTED,23)
  if d.has("damage"):
   text_at("DAMAGE",Vector2(x,389),10,MUTED)
   text_at(pretty(sim.stat(b,"damage")),Vector2(x,418),24)
   text_at("RANGE",Vector2(x+132,389),10,MUTED)
   text_at(pretty(sim.stat(b,"range"))+" m",Vector2(x+132,418),24)
  elif d.has("income"):
   text_at("PRODUCTION",Vector2(x,389),10,MUTED)
   var bonus := 1.25 if (b.kind == "wood" and Sim.PADS[selected].role == "forest") or (b.kind == "stone" and Sim.PADS[selected].role == "quarry") else 1.0
   text_at("+%.1f %s / s" % [sim.stat(b,"income")*bonus,d.resource],Vector2(x,418),21)
  else:
   text_at("ROAD CHECKPOINT",Vector2(x,389),10,MUTED)
   text_at("Blocks the enemy",Vector2(x,418),20)
  line(Vector2(x,435),Vector2(x+250,435),Color("d5d7c8"))
  if b.level < 100:
   cost_row(sim.upgrade_cost(b),Vector2(x,467))
   var enabled: bool = b.hp > 0 and sim.can_afford(sim.upgrade_cost(b))
   button(Rect2(x,480,250,49),"Upgrade to level %d  ↑" % (b.level+1),"upgrade",true,enabled,16)
  else:
   button(Rect2(x,480,250,49),"Maximum level reached","upgrade",false,false,16)
  if b.hp < sim.stat(b,"hp")-0.01:
   cost_row(sim.repair_cost(b),Vector2(x,560),true)
   button(Rect2(x,573,250,45),"Repair building","repair",false,sim.can_afford(sim.repair_cost(b)),16)
  else:
   text_at("✓  Building in good condition",Vector2(x,568),13,TEAL)
  if b.kind == "market" and b.hp > 0:
   button(Rect2(x,630,121,38),"60 wood → gold","trade_wood",false,sim.resources.wood>=60,11)
   button(Rect2(x+129,630,121,38),"60 stone → gold","trade_stone",false,sim.resources.stone>=60,11)
  else: text_at("Upgrades increase health & output.",Vector2(x,652),12,MUTED)
 elif selected > 0:
  var role: String = Sim.PADS[selected].role
  text_at("EMPTY PLOT",Vector2(x,151),11,TEAL)
  text_at("Room to grow",Vector2(x,190),28,INK,true)
  diamond(Vector2(1276,290),Vector2(70,36),Color("d4dac4"))
  centered("+",Rect2(1236,253,80,70),47,TEAL)
  var desc := "Choose a building from the build bar below. Every structure can reach level 100."
  if role == "gate": desc = "A road checkpoint. Place a wall here to stop enemies while your towers fire."
  elif role == "forest": desc = "The pine grove. A woodcutter built here produces 25% more timber."
  elif role == "quarry": desc = "The stone quarry. A stonemason built here produces 25% more stone."
  wrapped(desc,Vector2(x,365),242,17,INK,28)
  text_at("BUILD • UPGRADE • REPAIR",Vector2(x,642),11,MUTED)
 else:
  text_at("YOUR OBJECTIVE",Vector2(x,151),11,TEAL)
  text_at("Keep the fire lit.",Vector2(x,192),26,INK,true)
  sprite(0,Vector2(1276,365),1.05)
  wrapped("Survive until 15:00 to secure Pinewatch. Then keep defending in endless survival.",Vector2(x,401),243,16,INK,27)
  wrapped("Tap buildings to upgrade or repair. Tap supply caches to gather. Your hall attacks automatically.",Vector2(x,506),243,15,MUTED,25)
  button(Rect2(x,615,250,49),"Field guide","guide")

func draw_build_bar() -> void:
 panel(Rect2(19,702,1402,91),PAPER,13)
 text_at("BUILD",Vector2(36,731),12,TEAL)
 text_at("Tap a plot",Vector2(36,755),11,MUTED)
 text_at("to place",Vector2(36,772),11,MUTED)
 for i in BUILD_ORDER.size():
  var kind: String = BUILD_ORDER[i]
  var d: Dictionary = Sim.DEFINITIONS[kind]
  var rect := Rect2(133+i*213,711,204,73)
  var enabled := sim.can_afford(d.cost)
  var active := build_kind == kind
  panel(rect,Color("d7e2cd") if active else Color("ebe7d9"),8,TEAL if active else Color("dad9ca"),2 if active else 1)
  if rect.has_point(mouse): panel(rect,Color(0.3,0.45,0.3,0.08),8)
  sprite(d.art,Vector2(rect.position.x+30,rect.position.y+61),0.40,Color.WHITE if enabled else Color(0.7,0.7,0.65))
  text_at(d.name,Vector2(rect.position.x+59,rect.position.y+27),15,INK)
  cost_row(d.cost,Vector2(rect.position.x+60,rect.position.y+52),true)
  buttons.append({"rect":rect,"action":"build:"+kind,"enabled":true})

func overlay(rect: Rect2, tag: String, heading: String, subheading: String = "") -> void:
 draw_rect(Rect2(0,0,1440,810),Color(0.055,0.10,0.08,0.77))
 panel(rect,PAPER,19)
 text_at(tag,rect.position+Vector2(38,40),12,TEAL)
 text_at(heading,rect.position+Vector2(36,91),35,INK,true)
 if subheading != "": wrapped(subheading,rect.position+Vector2(38,128),rect.size.x-76,17,MUTED,27)

func draw_briefing() -> void:
 buttons.clear()
 overlay(Rect2(360,116,720,578),"MISSION 01 / THE PINEWATCH ROAD","A small settlement. A long night.","The western road is stirring. Raise your defenses and keep the main hall standing for 15 minutes.")
 var items := [["01","Gather & grow","Tap supply caches. Build a woodcutter and stonemason for steady income."],["02","Hold the checkpoints","Build arrow towers and walls along the single enemy approach."],["03","Keep the hearth alive","Upgrade and repair. Victory at 15:00 unlocks endless survival."]]
 for i in 3:
  var y := 337+i*86
  panel(Rect2(398,y-26,42,42),Color("dce2d0"),10)
  centered(items[i][0],Rect2(398,y-26,42,42),15,TEAL)
  text_at(items[i][1],Vector2(458,y-7),19,INK)
  wrapped(items[i][2],Vector2(458,y+20),565,14,MUTED,21)
 button(Rect2(398,611,157,49),"Back","menu_back")
 button(Rect2(572,611,469,49),"Light the hearth  →","start",true)

func draw_confirm() -> void:
 buttons.clear()
 overlay(Rect2(450,230,540,350),"NEW MISSION","Start a new settlement?","This replaces your saved settlement. Your best survival time and settings will stay.")
 button(Rect2(487,485,204,50),"Keep my settlement","menu_back",false,true,15)
 button(Rect2(707,485,245,50),"Start fresh","confirm_new",true)

func draw_end_overlay() -> void:
 var tag := "TAKE A BREATHER"
 var heading := "The hearth can wait."
 var description := "Your settlement is saved. The enemy waits while you are away."
 if screen == "victory":
  tag = "MISSION COMPLETE • 15 MINUTES HELD"
  heading = "The hearth endures."
  description = "Pinewatch is safe for tonight. The road remains dangerous. Continue into endless survival and see how long you can hold."
 if screen == "defeat":
  tag = "THE SETTLEMENT HAS FALLEN"
  heading = "Every hearth leaves a story."
  description = "Your buildings remain as ruins, but the main hall has fallen. Return with a new plan and rebuild Pinewatch."
 overlay(Rect2(402,151,636,508),tag,heading,description)
 var a := "TIME HELD"
 var value := time_label(sim.elapsed)
 for i in 3:
  if i == 1:
   a = "ENEMIES DEFEATED"
   value = str(sim.kills)
  if i == 2:
   a = "WAVE REACHED"
   value = str(sim.wave)
  text_at(a,Vector2(442+i*193,411),10,MUTED)
  text_at(value,Vector2(442+i*193,453),31,INK,true)
 if screen == "pause":
  button(Rect2(440,492,560,53),"Return to the settlement","resume",true)
  button(Rect2(440,564,176,49),"Settings","settings")
  button(Rect2(632,564,176,49),"Field guide","guide")
  button(Rect2(824,564,176,49),"Save & menu","menu",false,true,16)
 elif screen == "victory":
  button(Rect2(440,493,560,54),"Continue in endless survival  →","endless",true)
  button(Rect2(440,564,560,49),"Save & return to menu","menu")
 else:
  button(Rect2(440,493,560,54),"Try again  →","start",true)
  button(Rect2(440,564,560,49),"Return to menu","menu")

func draw_settings() -> void:
 overlay(Rect2(420,138,600,534),"MAKE YOURSELF AT HOME","Settings")
 var rows := [["Sound effects","Construction, gathering & combat","sound",sound_on],["Music","A quiet frontier soundtrack","music",music_on],["Reduce motion","Calmer scenery and building animations","motion",reduced_motion]]
 for i in 3:
  var y := 292+i*96
  text_at(rows[i][0],Vector2(459,y),21)
  text_at(rows[i][1],Vector2(459,y+28),13,MUTED)
  button(Rect2(872,y-27,108,48),"On" if rows[i][3] else "Off",rows[i][2],rows[i][3])
 button(Rect2(459,578,520,53),"Done","back",true)

func draw_credits() -> void:
 overlay(Rect2(357,112,726,570),"MADE FOR THE FRONTIER","Tabara: Last Hearth")
 text_at("Original image-generated building art & synthesized audio.",Vector2(396,255),17,INK)
 text_at("Built with Godot 4.6 · Noto Sans & Noto Serif Display.",Vector2(396,284),16,MUTED)
 text_at("LICENSES & NOTICES — SCROLL BELOW",Vector2(396,321),11,TEAL)
 button(Rect2(396,592,648,50),"Back","back",true)

func draw_guide() -> void:
 overlay(Rect2(235,66,970,678),"THE PINEWATCH FIELD GUIDE","A little planning goes a long way.")
 var entries := [
  ["Gather resources","Tap the round wood, stone and gold caches on the map. They refill every 12 seconds. Buildings produce supplies automatically."],
  ["Build your economy","The pine grove boosts woodcutters by 25%. The quarry boosts stonemasons by 25%. Marketplaces produce gold and enable trading."],
  ["Defend the road","The hall fires from the start. Arrow towers shoot quickly; cannons deal area damage. Walls block the two road checkpoints."],
  ["Upgrade & repair","Select a structure to upgrade it, up to level 100. Ruins keep their level. Repair them to restore production and attacks."],
  ["Survive the night","Enemies arrive immediately and new waves grow stronger every 30 seconds. Hold until 15:00 to win, then choose endless survival."],
  ["Leave & return","Your game saves every 10 seconds and when paused. App switching pauses the mission. Continue from the menu, fully offline."]]
 for i in entries.size():
  var col := i%2
  var row := i/2
  var p := Vector2(275+col*464,246+row*140)
  text_at("0%d  %s" % [i+1,entries[i][0]],p,20,INK)
  wrapped(entries[i][1],p+Vector2(0,32),411,15,MUTED,24)
 text_at("DESKTOP: 1–6 build · U upgrade · R repair · Space pause · Esc back",Vector2(275,673),13,MUTED)
 button(Rect2(984,661,182,48),"Got it","back",true)
