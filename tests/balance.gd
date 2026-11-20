extends SceneTree
## Multi-seed balance sample with real costs; writes evidence rather than changing rules.
const Sim = preload("res://scripts/simulation.gd")
const Bot = preload("res://tests/player_bot.gd")
var results: Array = []
var seed_count:=12
var approach:="balanced"

func _init() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--approach="): approach=arg.trim_prefix("--approach=")
  if arg.begins_with("--seeds="): seed_count=clampi(int(arg.trim_prefix("--seeds=")),1,100)
 call_deferred("run")

func run() -> void:
 var started := Time.get_ticks_msec()
 for seed_number in range(1,seed_count+1):
  var sim = Sim.new(seed_number)
  var bot = Bot.new(sim,approach)
  var boss_kills: Array = []
  for second in 1500:
   bot.act()
   sim.step(1)
   for event in sim.events:
    if event.type == "kill" and event.kind == "boss":
     boss_kills.append(snappedf(sim.elapsed,0.05))
   sim.events.clear()
   if second%60==0:
    var saved = Sim.restore(JSON.parse_string(JSON.stringify(sim.snapshot(),"",true,true)))
    if saved == null:
     printerr("Invalid campaign snapshot at seed ",seed_number," second ",second)
     quit(1)
     return
   if sim.defeated: break
   if second%20==0: await process_frame
  var result := {"approach":approach,"seed":seed_number,"seconds":sim.elapsed,"wave":sim.wave,"kills":sim.kills,"victory":sim.victory,"defeated":sim.defeated,"resources":sim.resources.duplicate(),"age":sim.settlement_age,"age_seconds":bot.age_seconds,"boss_kills":boss_kills,"specializations":sim.tower_tracks.duplicate(),"rain_casts":bot.rain_casts,"research":sim.research_levels.duplicate(),"buildings":sim.active_building_count(),"hall_hp":sim.buildings[0].hp,"paid_orders":bot.paid_orders,"plan_next":bot.next}
  results.append(result)
  print("BALANCE ",JSON.stringify(result))
 var wins := 0
 for result in results:
  if result.victory: wins += 1
 var report := {"actual_seconds":(Time.get_ticks_msec()-started)/1000.0,"campaigns":results,"wins":wins,"total":results.size()}
 var report_path := "res://test-results/balance.json" if approach == "balanced" else "res://test-results/balance-"+approach+".json"
 var file := FileAccess.open(report_path,FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 file.close()
 print("BALANCE RESULT ",JSON.stringify({"wins":wins,"total":results.size()}))
 quit()
