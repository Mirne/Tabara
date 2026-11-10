extends SceneTree
## A real-clock soak of the rendered game, with normal-cost player actions.
## -- --seconds=14400 runs four actual hours, not four simulated hours.
const Sim = preload("res://scripts/simulation.gd")
const Bot = preload("res://tests/player_bot.gd")
var game
var bot
var started := 0
var duration := 14400
var report_at := 0
var act_at := 0
var sessions := 0
var wins := 0
var resumes := 0
var steps := 0
var max_memory := 0
var errors: Array = []
var session_seconds := 0
var report_path := "res://test-results/frontier-soak.json"
var resume_requested := false
var prior_seconds := 0.0
var segments := 1
var camera_tours := 0
var min_fps := 10000.0
var max_process_ms := 0.0
var active_seconds := 0.0
var last_tick := 0
var excluded_stall_seconds := 0.0

func _init() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--seconds="): duration = maxi(1,int(arg.trim_prefix("--seconds=")))
  if arg.begins_with("--report-name="): report_path = "res://test-results/"+arg.trim_prefix("--report-name=").get_file()+".json"
  if arg == "--resume": resume_requested = true
 call_deferred("run")

func run() -> void:
 root.size = Vector2i(1280,720)
 game = load("res://main.tscn").instantiate()
 root.add_child(game)
 game.sound_on = false
 game.music_on = false
 game.music_player.stop()
 game.music_player.stream = null
 started = Time.get_ticks_msec()
 last_tick=started
 if resume_requested and FileAccess.file_exists(report_path):
  var previous = JSON.parse_string(FileAccess.get_file_as_string(report_path))
  if previous is Dictionary and previous.get("errors",[]).is_empty():
   prior_seconds = maxf(0,float(previous.get("actual_real_seconds",0)))
   segments = int(previous.get("segments",1))+1
   sessions = int(previous.get("sessions",0))
   wins = int(previous.get("victories",0))
   resumes = int(previous.get("disk_resumes",0))
   steps = int(previous.get("action_cycles",0))
   max_memory = int(previous.get("max_static_memory_bytes",0))
   excluded_stall_seconds=float(previous.get("excluded_stall_seconds",0))
 if prior_seconds > 0 and game.sim != null and not game.sim.defeated:
  # A fresh attempt may have started after the last report but before shutdown.
  if game.sim.seed_value == 1000+sessions+1: sessions += 1
  game.screen = "mission"
  game.selected = 0
  game.accumulator = 0
  game.speed = 1
  bot = Bot.new(game.sim)
  session_seconds = int(game.sim.elapsed)
  resumes += 1
  print("RESUMED SOAK: ",prior_seconds," confirmed seconds; segment ",segments)
 else: start_session()
 report_at = started+50000
 act_at = started
 process_frame.connect(tick)

func start_session() -> void:
 sessions += 1
 game.sim = Sim.new(1000+sessions)
 game.screen = "mission"
 game.selected = 0
 game.accumulator = 0
 game.fx.clear()
 game.speed = 1
 game.autosave = 0
 game.camera_center=Sim.World.HALL
 game.zoom=0.85
 game.apply_camera()
 bot = Bot.new(game.sim)
 session_seconds = 0

func tick() -> void:
 var now := Time.get_ticks_msec()
 var gap:float=(now-last_tick)/1000.0
 active_seconds+=minf(gap,2.0)
 excluded_stall_seconds+=maxf(0,gap-2.0)
 last_tick=now
 if now >= act_at:
  act_at = now+1000
  if game.screen == "victory":
   wins += 1
   game.act("endless")
  if game.screen == "defeat":
   start_session()
  bot.act()
  steps += 1
  session_seconds += 1
  validate()
  if session_seconds%60==0:
   # Exercise the actual filesystem save and cold-restore path repeatedly.
   game.save_game()
   var original: Dictionary = game.sim.snapshot()
   game.sim = null
   game.load_saved_game()
   if game.sim == null:
    errors.append("Save restore failed at second %d" % session_seconds)
   else:
    bot.sim = game.sim
    resumes += 1
    if not is_equal_approx(game.sim.elapsed,float(original.elapsed)): errors.append("Resume clock mismatch")
    if game.sim.enemies.size()!=original.enemies.size(): errors.append("Resume enemy mismatch")
    if game.sim.buildings.size()!=original.buildings.size(): errors.append("Resume structure count mismatch")
    for i in original.buildings.size():
     if original.buildings[i]!=null:
      if game.sim.buildings[i]==null or game.sim.buildings[i].pos!=Vector2(original.buildings[i].pos[0],original.buildings[i].pos[1]): errors.append("Resume world position mismatch")
    game.apply_camera()
  if session_seconds%24==0:
   var stops:=[Sim.World.HALL,Vector2(3050,1900),Vector2(6500,1600),Vector2(7400,4300),Vector2(1000,1700)]
   game.camera_center=stops[camera_tours%stops.size()]
   game.zoom=[0.85,0.4,1.25][camera_tours%3]
   game.apply_camera()
   camera_tours+=1
  if session_seconds%240==0:
   game.act("pause")
   game.act("settings")
   game.act("motion")
   game.act("back")
   game.act("resume")
 if now >= report_at:
  report_at = now+50000
  report()
 if prior_seconds+active_seconds >= duration:
  report(true)
  game.music_player.stop()
  quit(1 if not errors.is_empty() else 0)
 elif not errors.is_empty():
  report()
  quit(1)

func validate() -> void:
 if game.sim == null: return
 var s: Settlement = game.sim
 for kind in Sim.RESOURCE_NAMES:
  if not is_finite(s.resources[kind]) or s.resources[kind]<0: errors.append("Invalid resource: "+kind)
 for b in s.buildings:
  if b == null: continue
  if not is_finite(b.pos.x) or not is_finite(b.pos.y) or not Rect2(Vector2.ZERO,Sim.World.SIZE).has_point(b.pos): errors.append("World position invariant")
  if b.level<1 or b.level>100 or not is_finite(b.hp) or b.hp<0 or b.hp>s.stat(b,"hp")+0.01: errors.append("Building invariant")
 for e in s.enemies:
  if not is_finite(e.hp) or e.hp<=0 or e.progress<0 or e.progress>s.total_length: errors.append("Enemy invariant")
 if s.events.size()>250 or game.fx.size()>180 or s.buildings.size()>Sim.MAX_BUILDINGS or s.enemies.size()>Sim.MAX_ENEMIES or s.cleared_ground.size()>10240: errors.append("Unbounded transient state")
 if not is_finite(game.zoom) or game.zoom<0.28 or game.zoom>1.6: errors.append("Camera zoom invariant")
 if game.Art.style_cache.size()>64: errors.append("Unbounded interface style cache")
 if steps>20:
  min_fps=minf(min_fps,Performance.get_monitor(Performance.TIME_FPS))
  max_process_ms=maxf(max_process_ms,Performance.get_monitor(Performance.TIME_PROCESS)*1000)
 max_memory = maxi(max_memory,int(Performance.get_monitor(Performance.MEMORY_STATIC)))

func report(finished: bool = false) -> void:
 if finished: game.save_game()
 var segment_seconds := active_seconds
 var data := {"complete":finished,"requested_real_seconds":duration,"actual_real_seconds":prior_seconds+segment_seconds,"current_segment_real_seconds":segment_seconds,"prior_confirmed_real_seconds":prior_seconds,"segments":segments,"sessions":sessions,"current_session_seed":game.sim.seed_value if game.sim!=null else -1,"victories":wins,"disk_resumes":resumes,"action_cycles":steps,"max_static_memory_bytes":max_memory,"current_static_memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"fps":Performance.get_monitor(Performance.TIME_FPS),"current_mission_seconds":game.sim.elapsed if game.sim!=null else -1,"errors":errors,"camera_tours":camera_tours,"min_fps_after_warmup":min_fps,"max_process_ms_after_warmup":max_process_ms,"camera":[game.camera_center.x,game.camera_center.y,game.zoom]}
 data.current_segment_wall_seconds=(Time.get_ticks_msec()-started)/1000.0
 data.excluded_stall_seconds=excluded_stall_seconds
 data.source_commit=OS.get_environment("TABARA_SOURCE_COMMIT")
 data.game_version=ProjectSettings.get_setting("application/config/version","development")
 var file := FileAccess.open(report_path+".tmp",FileAccess.WRITE)
 if file != null:
  file.store_string(JSON.stringify(data,"  "))
  file.close()
  DirAccess.rename_absolute(report_path+".tmp",report_path)
 print("SOAK ",JSON.stringify(data))
