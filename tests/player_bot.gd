extends RefCounted
## A normal-cost defender: one paid order per second, local repairs and global research.
const Sim=preload("res://scripts/simulation.gd")
const PLAN=[
 [Vector2(4380,3030),"wood"],[Vector2(5150,3110),"stone"],[Vector2(4520,2560),"arrow"],
 [Vector2(5480,2760),"stone"],
 [Vector2(4160,2600),"wall"],[Vector2(4160,2680),"wall"],[Vector2(4160,2760),"wall"],
 [Vector2(4160,2840),"wall"],[Vector2(4160,2920),"wall"],[Vector2(4160,3000),"wall"],
 [Vector2(4480,2880),"cannon"],[Vector2(5200,2800),"workshop"],
 [Vector2(5110,2420),"wood"],[Vector2(4500,3120),"arrow"],
 [Vector2(4720,3056),"cannon"],[Vector2(4520,2720),"arrow"],
 [Vector2(4700,2520),"arrow"],[Vector2(4800,3280),"market"],
 [Vector2(4920,2520),"arrow"],[Vector2(4800,2560),"cannon"],
 [Vector2(4680,3240),"arrow"],[Vector2(4460,3280),"arrow"],
 [Vector2(5000,3120),"arrow"],[Vector2(5000,3280),"arrow"]
]
var sim
var next:=0
var sites:Dictionary={}
var paid_orders:=0
func _init(settlement)->void:
 sim=settlement
 # Continue a saved army by checking how many planned structures remain.
 var present:Dictionary={}
 for b in sim.buildings:
  if b!=null:present[b.kind]=present.get(b.kind,0)+1
 var needed:Dictionary={}
 while next<PLAN.size():
  var kind:String=PLAN[next][1]
  needed[kind]=needed.get(kind,0)+1
  if present.get(kind,0)<needed[kind]:break
  next+=1
func planned_site(position:Vector2,kind:String)->Vector2:
 var center:Vector2=sim.snap_position(position,kind)
 if sim.placement_error(center,kind)=="" or kind in ["wood","stone"]:return center
 for ring in range(1,11):
  for y in range(-ring,ring+1):
   for x in range(-ring,ring+1):
    if absi(x)!=ring and absi(y)!=ring:continue
    var site:Vector2=center+Vector2(x,y)*sim.GRID_SIZE
    if sim.placement_error(site,kind)=="":return site
 return center
func act()->void:
 if sim.defeated:return
 var repair_index:=-1
 var lowest:=0.65
 for i in sim.buildings.size():
  var b=sim.buildings[i]
  if b==null or b.hp<=0 or b.age<sim.build_time(b.kind) or float(b.get("repair_left",0))>0:continue
  var ratio:float=b.hp/sim.stat(b,"hp")
  if ratio<lowest and sim.can_afford(sim.repair_cost(b)):
   lowest=ratio
   repair_index=i
 if repair_index>=0 and sim.repair_at(repair_index)=="":
  paid_orders+=1
  return
 for key in sites:
  var kind:String=PLAN[int(key)][1]
  var point:Vector2=sites[key]
  var present:=false
  for b in sim.nearby_buildings(point,2):
   if sim.buildings[b]!=null and sim.buildings[b].kind==kind and sim.buildings[b].pos==point:present=true
  if not present and sim.can_afford(Sim.DEFINITIONS[kind].cost) and sim.build_at(point,kind)=="":
   paid_orders+=1
   return
 if sim.workshop_index()>=0 and sim.research_job.is_empty():
  var priorities:Array=["arrow","cannon","stone","wall","wood","hall"]
  var choices:Array=[]
  var target:=mini(8,2+int(sim.elapsed/240))
  for i in priorities.size():
   var kind:String=priorities[i]
   if int(sim.research_levels[kind])>=target:continue
   var count:=0
   for b in sim.buildings:
    if b!=null and b.kind==kind:count+=1
   if count>0:choices.append({"kind":kind,"score":int(sim.research_levels[kind])*10+i})
  choices.sort_custom(func(a,b):return a.score<b.score)
  if not choices.is_empty():
   var kind:String=choices[0].kind
   if sim.can_afford(sim.research_cost(kind)) and sim.start_research(kind)=="":
    paid_orders+=1
    return
 if next<PLAN.size() and sim.can_afford(Sim.DEFINITIONS[PLAN[next][1]].cost):
  var point:=planned_site(PLAN[next][0],PLAN[next][1])
  if sim.build_at(point,PLAN[next][1])=="":
   sites[next]=point
   next+=1
   paid_orders+=1
   return
 if next>=PLAN.size() and sim.active_building_count()<60:
  # Spend real surplus supplies on a second line and additional focused fire.
  for y in range(2600,3001,80):
   var point:=Vector2(4280,y)
   if sim.can_afford(Sim.DEFINITIONS.wall.cost) and sim.placement_error(point,"wall")=="":
    if sim.build_at(point,"wall")=="":
     paid_orders+=1
     return
  var kinds:Array=["cannon","arrow"] if paid_orders%3==0 else ["arrow","cannon"]
  for kind in kinds:
   if not sim.can_afford(Sim.DEFINITIONS[kind].cost):continue
   for x in range(4360,4841,80):
    for y in range(2440,3241,80):
     var point:=Vector2(x,y)
     if sim.placement_error(point,kind)=="" and sim.build_at(point,kind)=="":
      paid_orders+=1
      return
 if sim.resources.stone<100 and sim.resources.gold>250:
  if sim.buy("stone"):paid_orders+=1
