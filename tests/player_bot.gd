extends RefCounted
## Uses the same public actions and costs as a human player, for balance/soak tests.
const Sim = preload("res://scripts/simulation.gd")
const PLAN := [[3,"market"],[9,"wall"],[5,"arrow"],[6,"cannon"],[10,"wall"],[11,"cannon"],[7,"wood"],[8,"stone"],[12,"market"]]
var next := 0
var sim: Settlement

func _init(settlement: Settlement) -> void:
 sim = settlement
 sim.build_at(1,"wood")
 sim.build_at(2,"stone")
 sim.build_at(4,"arrow")

func act() -> void:
 for i in 3: sim.collect(i)
 for i in sim.buildings.size():
  var b = sim.buildings[i]
  if b != null and b.hp < sim.stat(b,"hp")*0.65: sim.repair_at(i)
 if next<PLAN.size():
  if sim.build_at(PLAN[next][0],PLAN[next][1])=="": next += 1
 var choices: Array = []
 for i in sim.buildings.size():
  var b = sim.buildings[i]
  if b == null or b.hp<=0: continue
  var target := 5+int(sim.elapsed/75.0)
  if b.kind=="hall": target = 3+int(sim.elapsed/110.0)
  if b.kind=="wall": target = 3+int(sim.elapsed/140.0)
  if b.level >= target: continue
  var cost: Array = sim.upgrade_cost(b)
  if sim.can_afford(cost): choices.append({"i":i,"cost":cost[0]+cost[1]+cost[2]*1.5})
 choices.sort_custom(func(a,b): return a.cost < b.cost)
 if not choices.is_empty(): sim.upgrade_at(choices[0].i)
