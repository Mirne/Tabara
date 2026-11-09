extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
var failures := 0
var checks := 0

func _init() -> void:
 test_start_and_economy()
 test_building_rules()
 test_upgrades_and_ruins()
 test_combat()
 test_victory_and_save()
 test_campaign()
 print("RESULT: %d checks, %d failures" % [checks,failures])
 quit(1 if failures > 0 else 0)

func check(condition: bool, label: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  printerr("FAIL: "+label)

func rich(sim) -> void:
 for key in Sim.RESOURCE_NAMES: sim.resources[key] = 1e14

func test_start_and_economy() -> void:
 var s = Sim.new(3)
 check(s.enemies.size()==1,"Enemies start immediately")
 check(s.buildings[0].kind=="hall","Main hall starts built")
 var before: float = s.resources.wood
 s.step(1.0)
 check(is_equal_approx(s.resources.wood,before+1.5),"Passive economy follows elapsed seconds")
 check(s.collect(0),"First resource collection succeeds")
 check(not s.collect(0),"Resource cache cannot be spammed")
 s.step(12.0)
 check(s.collect(0),"Resource cache replenishes")
 rich(s)
 s.build_at(1,"wood")
 s.build_at(2,"stone")
 s.build_at(3,"market")
 check(is_equal_approx(s.income_rates().wood,6.5),"Forest gives woodcutter 25% bonus")
 check(is_equal_approx(s.income_rates().stone,4.65),"Quarry gives stonemason 25% bonus")
 check(is_equal_approx(s.income_rates().gold,2.45),"Marketplace produces gold")
 var gold_before: float = s.resources.gold
 var wood_before: float = s.resources.wood
 check(s.trade("wood"),"Active marketplace enables trading")
 check(s.resources.wood==wood_before-60 and s.resources.gold==gold_before+30,"Trading exchanges the exact resources")
 s.buildings[3].hp = 0.0
 check(not s.trade("wood"),"Ruined marketplace cannot trade")

func test_building_rules() -> void:
 var s = Sim.new(4)
 var before := JSON.stringify(s.resources)
 check(s.build_at(0,"wood")!="","Hall plot cannot be overwritten")
 check(s.build_at(-1,"wood")!="","Negative plot rejected")
 check(s.build_at(90,"wood")!="","Out of range plot rejected")
 check(s.build_at(4,"unknown")!="","Unknown building rejected")
 check(s.build_at(4,"wall")!="","Wall requires checkpoint")
 check(s.build_at(9,"arrow")!="","Checkpoint requires wall")
 check(JSON.stringify(s.resources)==before,"Invalid placement never spends resources")
 rich(s)
 check(s.build_at(9,"wall")=="","Wall can occupy checkpoint")
 check(s.build_at(4,"arrow")=="","Tower can occupy normal plot")
 s.resources = {"wood":0.0,"stone":0.0,"gold":0.0}
 check(s.build_at(5,"cannon")!="" and s.buildings[5]==null,"Unaffordable construction is atomic")

func test_upgrades_and_ruins() -> void:
 for kind in Sim.DEFINITIONS:
  var s = Sim.new(5)
  rich(s)
  var index := 0 if kind=="hall" else (9 if kind=="wall" else 4)
  if index>0: s.build_at(index,kind)
  var b: Dictionary = s.buildings[index]
  var old_max: float = s.stat(b,"hp")
  b.hp = old_max*0.5
  check(s.upgrade_at(index)=="","Upgrade works: "+kind)
  check(is_equal_approx(b.hp/s.stat(b,"hp"),0.5),"Upgrade preserves damage fraction: "+kind)
  for level in range(3,101):
   var error: String = s.upgrade_at(index)
   check(error=="" and b.level==level,"Reach level %d: %s" % [level,kind])
   check(is_finite(s.stat(b,"hp")),"Finite level health: "+kind)
  check(s.upgrade_at(index)!="" and b.level==100,"Level 100 cap: "+kind)
  b.hp = 0.0
  check(s.upgrade_at(index)!="","Ruins cannot upgrade: "+kind)
  check(s.repair_at(index)=="" and b.level==100 and b.hp==s.stat(b,"hp"),"Repair preserves level 100: "+kind)

func test_combat() -> void:
 var s = Sim.new(6)
 s.enemies.clear()
 s.spawn_remaining = 0
 s.spawn_enemy()
 var e: Dictionary = s.enemies[0]
 e.progress = s.total_length-200
 var hp: float = e.hp
 s.step(0.2)
 check(e.hp < hp,"Main hall attacks without player input")
 var wall = Sim.new(7)
 rich(wall)
 wall.build_at(9,"wall")
 wall.enemies.clear()
 wall.spawn_remaining = 0
 wall.spawn_enemy()
 var attacker: Dictionary = wall.enemies[0]
 # The first checkpoint lies on the horizontal road segment.
 attacker.progress = wall.path_lengths[1]+101.0
 var progress_before: float = attacker.progress
 wall.step(2.0)
 check(is_equal_approx(attacker.progress,progress_before),"Standing wall stops progress")
 check(wall.buildings[9].hp < wall.stat(wall.buildings[9],"hp"),"Enemies damage the wall")
 wall.buildings[9].hp = 0
 wall.step(1.0)
 check(attacker.progress>progress_before,"Enemies pass ruined wall")
 check(wall.repair_at(9)=="","Ruined wall repairs during combat")
 var aoe = Sim.new(8)
 rich(aoe)
 aoe.build_at(4,"cannon")
 aoe.enemies.clear()
 aoe.spawn_remaining = 0
 for i in 3:
  aoe.spawn_enemy()
  aoe.enemies[-1].progress = aoe.path_lengths[1]+55+i*5
 aoe.step(0.2)
 check(aoe.kills==3,"Cannon blast hits clustered enemies")
 var pressure = Sim.new(9)
 pressure.enemies[0].progress = pressure.total_length
 pressure.enemies[0].hp = 1e9
 pressure.enemies[0].damage = 1e9
 pressure.step(1.0)
 check(pressure.defeated and pressure.buildings[0].hp==0,"Destroyed main hall ends mission and stays as ruin")
 var frozen: float = pressure.elapsed
 pressure.step(10.0)
 check(pressure.elapsed==frozen,"Defeat freezes simulation")

func test_victory_and_save() -> void:
 var s = Sim.new(10)
 rich(s)
 s.build_at(1,"wood")
 s.build_at(9,"wall")
 s.upgrade_at(9)
 s.collect(1)
 s.step(5.0)
 var json := JSON.stringify(s.snapshot())
 var restored = Sim.restore(JSON.parse_string(json))
 check(restored!=null,"JSON save restores")
 check(restored.buildings[9].level==2,"Save preserves building upgrades")
 check(is_equal_approx(restored.elapsed,s.elapsed),"Save preserves elapsed time")
 check(restored.enemies.size()==s.enemies.size(),"Save preserves active enemies")
 for i in 20:
  s.step(0.05)
  restored.step(0.05)
 check(is_equal_approx(s.enemies[0].progress,restored.enemies[0].progress),"Restored combat stays deterministic")
 check(Sim.restore({})==null,"Empty save rejected")
 var bad: Dictionary = JSON.parse_string(json)
 bad.buildings[0].level = 101
 check(Sim.restore(bad)==null,"Invalid upgrade level rejected")
 bad = JSON.parse_string(json)
 bad.enemies[0].erase("damage")
 check(Sim.restore(bad)==null,"Incomplete enemies rejected")
 bad = JSON.parse_string(json)
 bad.resources.wood = -1
 check(Sim.restore(bad)==null,"Negative resources rejected")
 bad = JSON.parse_string(json)
 bad.wave = 999
 check(Sim.restore(bad)==null,"Inconsistent wave rejected")
 for key in ["seed","kills","spawn_remaining","spawn_clock","next_id","rng_state","victory_seen"]:
  bad = JSON.parse_string(json)
  bad[key] = {"broken":true}
  check(Sim.restore(bad)==null,"Corrupt root field rejected safely: "+key)
 var clock_test = Sim.new(11)
 rich(clock_test)
 for i in 30: clock_test.upgrade_at(0)
 # Isolate time boundary from combat for an exact victory check.
 clock_test.elapsed = 899.9
 clock_test.wave = 30
 clock_test.enemies.clear()
 clock_test.spawn_remaining = 0
 clock_test.step(0.05)
 check(not clock_test.victory,"Victory does not fire early")
 clock_test.step(0.1)
 check(clock_test.victory and clock_test.wave==31,"Victory starts at 900 seconds")
 clock_test.step(60)
 check(clock_test.elapsed>960 and clock_test.wave>=33,"Endless mode continues after victory")
 check(Sim.restore(JSON.parse_string(JSON.stringify(clock_test.snapshot())))!=null,"Post-victory save restores")

func test_campaign() -> void:
 # A fair deterministic player: no grants, no invulnerability, real costs and repairs.
 var s = Sim.new(12)
 s.build_at(1,"wood")
 s.build_at(2,"stone")
 s.build_at(4,"arrow")
 var build_plan := [[3,"market"],[9,"wall"],[5,"arrow"],[6,"cannon"],[10,"wall"],[11,"cannon"],[7,"wood"],[8,"stone"],[12,"market"]]
 var next := 0
 for second in 1200:
  for i in 3: s.collect(i)
  for i in s.buildings.size():
   var b = s.buildings[i]
   if b != null and b.hp < s.stat(b,"hp")*0.65: s.repair_at(i)
  if next<build_plan.size():
   if s.build_at(build_plan[next][0],build_plan[next][1])=="": next += 1
  # Keep economy growing alongside defenses; purchase cheapest useful upgrade.
  var choices: Array = []
  for i in s.buildings.size():
   var b = s.buildings[i]
   if b == null or b.hp <= 0: continue
   var target := 5+int(second/75.0)
   if b.kind == "hall": target = 3+int(second/110.0)
   if b.kind == "wall": target = 3+int(second/140.0)
   if b.level >= target: continue
   var cost: Array = s.upgrade_cost(b)
   if s.can_afford(cost):
    choices.append({"i":i,"cost":cost[0]+cost[1]+cost[2]*1.5})
  choices.sort_custom(func(a,b): return a.cost < b.cost)
  if not choices.is_empty(): s.upgrade_at(choices[0].i)
  s.step(1.0)
  s.events.clear()
  if s.defeated: break
 print("CAMPAIGN: %.1fs wave %d kills %d resources %s" % [s.elapsed,s.wave,s.kills,str(s.resources)])
 var levels: Array = []
 for b in s.buildings: levels.append(0 if b==null else b.level)
 print("CAMPAIGN LEVELS: ",levels)
 check(s.victory,"Economy and defense strategy can complete the 15-minute mission")
 check(s.elapsed>Sim.VICTORY_TIME and (s.defeated or s.elapsed>=1200.0-0.1),"Endless combat continues until defeat or the test endpoint")
