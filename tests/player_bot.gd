extends RefCounted
## Normal costs, nearby gathering, and at most one paid action per second.
const Sim=preload("res://scripts/simulation.gd")
const PLAN=[
 [Vector2(4544,3264),"wood"],[Vector2(5280,2880),"stone"],[Vector2(4512,2576),"arrow"],
 [Vector2(4976,2992),"market"],[Vector2(4384,2640),"wall"],[Vector2(4400,2720),"wall"],[Vector2(4368,2560),"wall"],
 [Vector2(4720,3056),"cannon"],[Vector2(4656,2528),"arrow"],[Vector2(4464,2864),"cannon"],
 [Vector2(4240,3232),"wood"],[Vector2(5296,3296),"stone"],[Vector2(4912,2528),"arrow"],
 [Vector2(5010,3200),"market"],[Vector2(4736,2400),"cannon"],[Vector2(4160,2784),"arrow"]
]
var sim
var next:=0
var nearby_nodes:Array=[]
func _init(settlement)->void:
 sim=settlement
 for i in sim.resource_nodes.size():
  if sim.resource_nodes[i].pos.distance_to(sim.World.HALL)<650: nearby_nodes.append(i)
 # Resume the plan from existing, paid-for structures rather than duplicating them.
 while next<PLAN.size():
  var present:=false
  for b in sim.buildings:
   if b!=null and b.pos==sim.snap_position(PLAN[next][0]) and b.kind==PLAN[next][1]: present=true
  if not present: break
  next+=1
func act()->void:
 for i in nearby_nodes:
  if sim.collect(i): break
 var repair_index:=-1
 var fraction:=0.58
 for i in sim.buildings.size():
  var b=sim.buildings[i]
  if b==null: continue
  var ratio:float=b.hp/sim.stat(b,"hp")
  if ratio<fraction and sim.can_afford(sim.repair_cost(b)):
   fraction=ratio
   repair_index=i
 if repair_index>=0:
  sim.repair_at(repair_index)
  return
 if sim.resources.stone<100 and sim.resources.gold>260:
  if sim.buy("stone"): return
 if next<PLAN.size() and sim.can_afford(Sim.DEFINITIONS[PLAN[next][1]].cost):
  if sim.build_at(PLAN[next][0],PLAN[next][1])=="":
   next+=1
   return
 var choices:Array=[]
 for i in sim.buildings.size():
  var b=sim.buildings[i]
  if b==null or b.hp<=0: continue
  var target:=5+int(sim.elapsed/70)
  if b.kind=="hall": target=3+int(sim.elapsed/140)
  elif b.kind=="wall": target=3+int(sim.elapsed/160)
  if b.level>=mini(target,100): continue
  var cost:Array=sim.upgrade_cost(b)
  if sim.can_afford(cost): choices.append({"i":i,"cost":cost[0]+cost[1]+cost[2]*1.5})
 choices.sort_custom(func(a,b):return a.cost<b.cost)
 if not choices.is_empty(): sim.upgrade_at(choices[0].i)
