extends "res://docs/verification/settlement-ages/replay-arrow-campaign.gd"
## Replays the mixed arrow/cannon campaign and the real victory-to-Endless flow.
const WINNING_TAPE := "res://docs/verification/settlement-ages/paid-victory.json"
const CLEAN_TAPE := "res://docs/verification/settlement-ages/clean-campaigns.json"
const Game = preload("res://scripts/frontier_game.gd")

func replay() -> void:
 if FileAccess.file_exists(Game.SAVE_PATH) or FileAccess.file_exists(Game.SETTINGS_PATH):
  push_error("Run with an empty, temporary XDG_DATA_HOME, as shown in the recording.")
  quit(1)
  return
 var options := OS.get_cmdline_user_args()
 var clean := "--clean" in options
 var path := CLEAN_TAPE if clean else WINNING_TAPE
 var tape: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
 var finish_save := "--finish-save" in options
 if clean and finish_save:
  push_error("Use --clean or --finish-save for a single recording.")
  quit(1)
  return
 var app_ticks := clean
 var game: Game = preload("res://main.tscn").instantiate()
 game.sound_on = false
 game.music_on = false
 root.add_child(game)
 game.set_process(false)
 game.sim = Simulation.new(int(tape.seed))
 game.screen = "mission"
 var cursor := 0
 var boss_kills: Array[int] = []
 for second in range(1100):
  if not clean and second == int(tape.checkpoint_second):
   game.save_game()
   game.sim = null
   game.load_saved_game()
   if game.sim == null or absf(game.sim.elapsed - second) > 0.01:
    push_error("The game's saved 10-minute settlement did not load.")
    quit(1)
    return
  if cursor < tape.commands.size() and second == int(tape.commands[cursor][0]):
   var error := place_order(game.sim, tape.commands[cursor])
   if not error.is_empty():
    push_error("Rejected command %d at %d seconds: %s" % [cursor, second, error])
    quit(1)
    return
   cursor += 1
  if finish_save and cursor == tape.commands.size() and not app_ticks:
   game.save_game()
   var destination := ProjectSettings.globalize_path("user://paid-warlord-at-986.json")
   var copy_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH), destination)
   if copy_error != OK:
    push_error("Could not preserve the live Warlord save. Error %d." % copy_error)
    quit(1)
    return
   print("Live Warlord save ", destination, " ", FileAccess.get_sha256(destination))
   game.sim = null
   game.load_saved_game()
   if game.sim == null or game.sim.final_boss_defeated:
    push_error("The live Warlord save could not be restored.")
    quit(1)
    return
   app_ticks = true
  if app_ticks:
   # The app advances in 50 ms steps and pauses on the Warlord's death frame.
   for tick in 20:
    game.sim.step(0.05)
    if game.sim.victory or game.sim.defeated:
     break
  else:
   # The search observed player orders and boss kills at one-second boundaries.
   game.sim.step(1.0)
  for event in game.sim.events:
   if event.type == "kill" and event.kind == "boss":
    boss_kills.append(roundi(game.sim.elapsed))
  game.sim.events.clear()
  if game.sim.victory or game.sim.defeated:
   break
 var victory: bool = game.sim.victory and game.sim.final_boss_defeated and not game.sim.defeated
 var hall_hp: float = game.sim.buildings[0].hp
 var elapsed: float = game.sim.elapsed
 var kills: int = game.sim.kills
 var wave: int = game.sim.wave
 var matched: bool = victory and cursor == tape.commands.size() and hall_hp > 0
 if victory:
  game._process(0.0)
  matched = matched and game.screen == "victory" and game.sim.victory_seen
  game.act("endless")
  for frame in 80:
   game._process(0.1)
  matched = matched and game.screen == "mission" and game.sim.wave > wave and not game.sim.defeated
 var expected: Dictionary = tape.expected if clean else (tape.finish_save if finish_save else tape.one_second_sample)
 matched = matched and absf(elapsed - float(expected.victory_time)) < 0.01
 matched = matched and kills == int(expected.kills) and wave == int(expected.wave)
 matched = matched and absf(hall_hp - float(expected.hall_hp)) < 0.01
 matched = matched and boss_kills == Array(expected.boss_kill_seconds, TYPE_INT, "", null)
 var result := {
  "uninterrupted_app_ticks": clean, "finish_save": finish_save, "accepted_commands": cursor,
  "victory": victory, "victory_time": elapsed, "kills": kills, "wave": wave,
  "hall_hp": hall_hp, "boss_kill_seconds": boss_kills, "endless_screen": game.screen,
  "endless_time": game.sim.elapsed, "endless_wave": game.sim.wave,
  "endless_hall_hp": game.sim.buildings[0].hp
 }
 print("PAID_VICTORY ", JSON.stringify(result))
 game.music_player.stop()
 game.sfx_player.stop()
 game.music_player.stream = null
 game.sfx_player.stream = null
 game.sounds.clear()
 game.queue_free()
 await process_frame
 await process_frame
 quit(0 if matched else 1)
