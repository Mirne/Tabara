extends RefCounted
## Normal costs, passive producers, and at most one paid action per second.
const Sim=preload("res://scripts/simulation.gd")
const PLAN=[
 [Vector2(4380,3030),"wood"],[Vector2(5150,3110),"stone"],[Vector2(4512,2576),"arrow"],
 [Vector2(4976,2992),"market"],[Vector2(4200,2720),"wall"],[Vector2(4200,2800),"wall"],[Vector2(4200,2880),"wall"],
 [Vector2(4720,3056),"cannon"],[Vector2(4656,2528),"arrow"],[Vector2(4464,2864),"cannon"],
 [Vector2(5110,2420),"wood"],[Vector2(3760,2080),"stone"],[Vector2(4912,2528),"arrow"],
 [Vector2(5010,3200),"market"],[Vector2(4736,2400),"cannon"],[Vector2(4160,2784),"arrow"]
]
var sim
var next:=0
var nearby_nodes:Array=[]
func _init(settlement)->void:
 sim=settlement
 for i in sim.resource_nodes.size():
  if sim.resource_nodes[i].pos.distance_to(sim.World.HALL)<650: nearby_nodes.append(i)
 # Recover a plan prefix by paid building counts, including adjusted grid sites.
 var present:Dictionary={}
 for b in sim.buildings:
  if b!=null: present[b.kind]=present.get(b.kind,0)+1
 var needed:Dictionary={}
 while next<PLAN.size():
  var kind:String=PLAN[next][1]
  needed[kind]=needed.get(kind,0)+1
  if present.get(kind,0)<needed[kind]: break
  next+=1

func planned_site(position:Vector2,kind:String)->Vector2:
 var center:Vector2=sim.snap_position(position,kind)
 if sim.placement_error(center,kind)=="" or kind in ["wood","stone"]: return center
 for ring in range(1,11):
  for y in range(-ring,ring+1):
   for x in range(-ring,ring+1):
    if absi(x)!=ring and absi(y)!=ring: continue
    var site:Vector2=center+Vector2(x,y)*sim.GRID_SIZE
    if sim.placement_error(site,kind)=="": return site
 return center

func act()->void:
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
  if sim.build_at(planned_site(PLAN[next][0],PLAN[next][1]),PLAN[next][1])=="":
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
