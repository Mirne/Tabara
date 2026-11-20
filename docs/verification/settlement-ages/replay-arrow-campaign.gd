extends SceneTree
## Replays the closest paid arrow-tower campaign from its actual player commands.
const Simulation = preload("res://scripts/simulation.gd")
const RECORDING = "res://docs/verification/settlement-ages/arrow-campaigns.json"

func _init() -> void:
 call_deferred("replay")

func place_order(sim: Simulation, command: Array) -> String:
 match command[1]:
  "build":
   return sim.build_at(Vector2(command[3], command[4]), command[2])
  "rain":
   return sim.cast_rain(Vector2(command[2], command[3]))
  "wall":
   var cells: Array = []
   for cell in command[2]:
    cells.append(Vector2(cell[0], cell[1]))
   return sim.build_wall(cells)
  "track":
   return sim.research_track(command[2])
  "local":
   return sim.upgrade_at(sim.singleton_index(command[2]))
  "regen":
   return sim.upgrade_regeneration()
  "age":
   return sim.advance_age()
  "wall_grade":
   return sim.start_research("wall")
 return "Unknown order " + str(command[1])

func replay() -> void:
 var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RECORDING))
 var tape: Dictionary = report.closest_campaign_replay
 var sim := Simulation.new(int(tape.seed))
 var cursor := 0
 var boss_kills: Array[int] = []
 for second in range(1100):
  if second == int(tape.restore_at_second):
   # Match the save/load between the original opening and this continuation.
   var saved: String = JSON.stringify(sim.snapshot(), "", true, true)
   sim = Simulation.restore(JSON.parse_string(saved))
   if sim == null:
    push_error("The recorded checkpoint could not be restored.")
    quit(1)
    return
  if cursor < tape.commands.size() and second == int(tape.commands[cursor][0]):
   var error := place_order(sim, tape.commands[cursor])
   if not error.is_empty():
    push_error("Rejected command at %d seconds: %s" % [second, error])
    quit(1)
    return
   cursor += 1
  sim.step(1.0)
  for event in sim.events:
   if event.type == "kill" and event.kind == "boss":
    boss_kills.append(roundi(sim.elapsed))
  sim.events.clear()
  if sim.defeated or sim.victory:
   break
 var warlord_hp := -1.0
 for enemy in sim.enemies:
  if enemy.get("mission_boss", false):
   warlord_hp = enemy.hp
 var expected: Dictionary = tape.expected
 var matched: bool = sim.defeated and not sim.victory and cursor == tape.commands.size()
 matched = matched and sim.kills == int(expected.kills) and sim.wave == int(expected.wave)
 matched = matched and absf(sim.elapsed - float(expected.hall_fell_second)) < 0.01
 matched = matched and absf(warlord_hp - float(expected.warlord_hp)) < 0.01
 matched = matched and boss_kills == Array(expected.miniboss_kill_seconds, TYPE_INT, "", null)
 print("Paid arrow campaign: %d commands, %.2f game seconds, %d kills, wave %d, Warlord %.2f HP. Match: %s" % [cursor, sim.elapsed, sim.kills, sim.wave, warlord_hp, matched])
 quit(0 if matched else 1)
