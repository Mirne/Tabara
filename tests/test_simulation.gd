extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Map=preload("res://scripts/world_data.gd")
var checks:=0
var failures:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures+=1
  printerr("FAIL: ",label)
func rich(layout:int=Map.AUTHORED_REVISION):
 var s=Sim.new(17,layout)
 s.resources={"wood":1e14,"stone":1e14,"gold":1e14}
 s.enemies.clear()
 s.spawn_remaining=0
 return s
func roundtrip(s):return Sim.restore(JSON.parse_string(JSON.stringify(s.snapshot(),"",true,true)))
func quiet_step(s,seconds:float)->void:
 s.spawn_remaining=0
 s.wave=int((s.elapsed+seconds)/s.WAVE_SECONDS)+1
 # Use short intervals when suppressing spawn fixtures across wave boundaries.
 s.step(seconds)
 s.enemies.clear()
 s.spawn_remaining=0
func run()->void:
 var s=Sim.new(7)
 check(s.terrain_revision==4 and s.resource_nodes.size()==8,"New mission uses eight deliberate resource sites")
 check(s.buildings.size()==1 and s.enemies.size()==1 and s.enemies[0].progress==0,"Only the hall is prebuilt; enemies start at the western entrance")
 var zones:Dictionary={}
 for node in s.resource_nodes:
  var key:String=node.kind+":"+node.zone
  zones[key]=zones.get(key,0)+1
 check(zones=={"wood:base":2,"wood:outpost":2,"stone:base":2,"stone:outpost":2},"Two wood and two stone sites in base; two of each outside")
 for node in s.resource_nodes:
  if node.zone=="outpost":check(node.pos.x<Map.HALL.x,"Outpost resources lie on the exposed western side")
 check(not s.collect(0),"Resource sites remain noninteractive scenery")
 var gold:float=s.resources.gold
 s.enemies[0].hp=0
 s.step(0.05)
 check(s.kills==1 and s.resources.gold>=gold+2,"Enemy kills award gold")
 s=rich()
 for node in s.resource_nodes:
  check(s.build_at(node.pos,node.kind)=="","Every resource site accepts its producer: "+str(node.pos))
  var paid:Dictionary=s.resources.duplicate()
  check(s.build_at(node.pos,node.kind)!="" and s.resources==paid,"Each resource site permits one producer without double spending")
 check(s.buildings.size()==9,"All eight sites and the hall coexist")
 check(s.build_at(Vector2(6100,2800),"stone")!="","Quarries cannot be placed on empty ground")
 check(s.build_at(s.resource_nodes[4].pos,"wood")!="","Producers require the matching resource")
 s=rich()
 check(s.build_at(Vector2(6101,2802),"arrow")=="" and s.buildings[1].pos==Vector2(6120,2800),"Foundations snap to the visible grid")
 var stock:Dictionary=s.resources.duplicate()
 check(s.build_at(Vector2(6120,2800),"wall")!="" and s.resources==stock,"Overlapping foundations spend nothing")
 for point in [Vector2(10,10),Map.LAKE_CENTER,Map.CLIFFS[0]]:
  check(s.build_at(point,"arrow")!="","Boundary, water and rock reject foundations")
 var hidden:=0
 for pocket in Map.forest_pockets:
  var point:Vector2=pocket.pos.snapped(Vector2.ONE*40)
  if Map.cell_terrain(Map.cell_of(point),4) in [6,7]:
   hidden+=1
   check(s.build_at(point,"arrow")!="" and not s.navigation.passable(point),"Former forest hole blocks both construction and enemies")
 check(hidden>=8,"Former inaccessible resource hollows are closed")
 var safe:=true
 for i in Map.terrain_field(4).size():
  if Map.terrain_field(4)[i]==0 and not is_finite(s.navigation.costs[i]):safe=false
 check(safe,"Every open cell belongs to the connected attackable landscape")
 s=rich()
 var stroke:Array=s.wall_line(Vector2(6100,2800),Vector2(6340,2960))
 check(stroke.size()>1 and s.build_wall(stroke)=="","A confirmed wall stroke builds connected sections")
 var count:int=s.active_building_count()
 check(s.build_wall(stroke)!="" and s.active_building_count()==count,"Existing wall endpoints are reused")
 var corner:int=s.wall_at(stroke[2])
 check(s.wall_neighbors(corner).size()>=1,"Wall geometry receives shared neighboring pieces")
 var broke=rich()
 broke.resources={"wood":0.0,"stone":0.0,"gold":0.0}
 var before:Dictionary=broke.snapshot()
 check(broke.build_wall(stroke)!="" and broke.snapshot()==before,"Unaffordable strokes remain atomic")
 # One global research queue, real costs and time, all current and future structures.
 s=rich()
 check(s.start_research("arrow")!="","Research requires an operational Workshop")
 check(s.build_at(Vector2(5200,2800),"workshop")=="","Workshop has its own buildable footprint")
 check(s.start_research("arrow")!="","Research waits for Workshop construction")
 quiet_step(s,7)
 check(s.build_at(Vector2(6100,2800),"arrow")=="" and s.build_at(Vector2(6300,2800),"arrow")=="","Two towers can share future research")
 var first:Dictionary=s.buildings[2]
 var second:Dictionary=s.buildings[3]
 first.hp=s.stat(first,"hp")*0.5
 var research_price:Array=s.research_cost("arrow")
 var wood:float=s.resources.wood
 check(s.start_research("arrow")=="" and s.resources.wood==wood-research_price[0],"Global research spends the quoted cost once")
 var paid:Dictionary=s.resources.duplicate()
 check(s.start_research("wall")!="" and s.resources==paid,"A busy Workshop refuses another paid order")
 check(s.upgrade_at(2)!="" and first.level==1,"Direct per-building upgrades are removed")
 quiet_step(s,1)
 check(first.level==1 and second.level==1 and s.research_job.remaining>0,"Research does not complete instantly")
 var saved=roundtrip(s)
 check(saved!=null and saved.research_job.kind==s.research_job.kind and saved.research_job.level==s.research_job.level and is_equal_approx(saved.research_job.remaining,s.research_job.remaining),"In-progress research survives a JSON round trip")
 quiet_step(s,35)
 check(first.level==2 and second.level==2 and s.research_levels.arrow==2,"Completed research upgrades every tower of that type")
 check(is_equal_approx(first.hp/s.stat(first,"hp"),0.5),"Global health upgrades preserve the damage fraction")
 check(s.build_at(Vector2(6500,2800),"arrow")=="" and s.buildings[-1].level==2,"Future structures inherit global research")
 check(s.build_at(Vector2(5400,3200),"workshop")!="","Multiple workshops cannot multiply research speed")
 check(s.start_research("stone")=="","Another subject starts when the previous research finishes")
 var pending:float=s.research_job.remaining
 var destroyer:Dictionary=s.spawn_enemy()
 destroyer.cooldown=0
 destroyer.damage=1e9
 s.attack_building(destroyer,1)
 quiet_step(s,2)
 check(s.buildings[1]==null and s.research_job.remaining==pending,"Destroying the Workshop removes it and pauses its paid research")
 check(s.build_at(Vector2(5200,2800),"workshop")=="","A destroyed Workshop can be replaced on its freed grid cells")
 quiet_step(s,7)
 check(s.research_job.remaining<pending,"A replacement Workshop resumes retained research")
 # Level 100 remains valid for every global building type.
 var progression=rich()
 progression.build_at(Vector2(5200,2800),"workshop")
 progression.buildings[1].age=10
 for kind in Sim.DEFINITIONS:
  for level in range(2,101):
   check(progression.start_research(kind)=="",kind+" global research starts at level "+str(level))
   progression.step_research(progression.research_duration(kind))
   var exemplar:Dictionary=progression.make_building(kind,Vector2(6000,2800))
   check(exemplar.level==level and is_finite(progression.stat(exemplar,"hp")) and progression.stat(exemplar,"hp")>0,kind+" global level is finite and inherited")
  check(progression.start_research(kind)!="" and progression.research_levels[kind]==100,kind+" research is capped at 100")
 # Repairs are local, take time, and cannot resurrect destroyed structures.
 s=rich()
 s.build_at(Vector2(6100,2800),"arrow")
 var tower:Dictionary=s.buildings[1]
 tower.age=10
 tower.hp=100
 var cost:Array=s.repair_cost(tower)
 wood=s.resources.wood
 check(s.repair_at(1)=="" and tower.hp==100 and s.resources.wood==wood-cost[0],"Local repair spends its quoted price without instant healing")
 check(s.repair_at(1)!="","Repeated repair taps do not duplicate jobs")
 quiet_step(s,4)
 check(tower.hp>100 and tower.hp<s.stat(tower,"hp"),"Local repair restores health progressively")
 saved=roundtrip(s)
 check(saved!=null and is_equal_approx(saved.buildings[1].repair_left,tower.repair_left),"Local repair progress survives saves")
 quiet_step(s,4.1)
 check(is_equal_approx(tower.hp,s.stat(tower,"hp")),"A full repair reaches the maximum health")
 destroyer=s.spawn_enemy()
 destroyer.damage=1e9
 destroyer.cooldown=0
 s.attack_building(destroyer,1)
 quiet_step(s,0.05)
 check(s.buildings[1]==null and s.repair_at(1)!="","Destroyed buildings disappear and cannot be repaired")
 check(s.build_at(Vector2(6100,2800),"arrow")=="","Destroyed foundations immediately become buildable again")
 # Real movement retaliates against the defense that fired, with walls respected.
 s=rich()
 s.build_at(Vector2(6520,3000),"arrow")
 s.buildings[1].age=10
 var enemy:Dictionary=s.spawn_enemy()
 enemy.pos=Vector2(6280,2800)
 enemy.hp=1e7
 enemy.max_hp=1e7
 var x_before:float=enemy.pos.x
 s.step(2)
 check(enemy.get("anger",-1)==1 and enemy.pos.x>x_before,"An attacked raider turns away from the Hall toward the firing tower")
 check(s.navigation.passable(enemy.pos),"Retaliation remains on passable terrain")
 s=rich()
 s.build_at(Vector2(6520,3000),"arrow")
 s.buildings[1].age=10
 s.build_wall(s.wall_line(Vector2(6400,2800),Vector2(6400,3040)))
 enemy=s.spawn_enemy()
 enemy.pos=Vector2(6280,2800)
 enemy.hp=1e7
 enemy.max_hp=1e7
 enemy.damage=0.01
 s.step(5)
 check(enemy.pos.x<6400 and enemy.target>=2,"Retaliating enemies attack blocking walls before reaching the tower")
 # Producers remain vulnerable beside their resource cores.
 s=rich()
 s.build_at(s.resource_nodes[2].pos,"wood")
 enemy=s.spawn_enemy()
 enemy.pos=s.buildings[1].pos+Vector2(-110,0)
 enemy.damage=100
 enemy.cooldown=0
 var hp:float=s.buildings[1].hp
 s.step(0.1)
 check(s.buildings[1].hp<hp,"Raiders attack exposed producers instead of ignoring their blocked deposit cells")
 # Elites use ordinary damage; their health and attack alone make them stronger.
 s=rich()
 s.wave=5
 s.spawn_remaining=s.wave_size(5)
 var elite:Dictionary=s.spawn_enemy()
 check(elite.kind=="elite" and elite.hp>Sim.DEFINITIONS.cannon.damage*3,"First great horde contains an elite with enough health for several cannon hits")
 var elite_damage:float=elite.damage
 var elite_hp:float=elite.hp
 s.wave=1
 var normal:Dictionary=s.spawn_enemy()
 check(elite_damage>normal.damage and elite_hp>normal.hp*5,"Elites have greater health and attack than ordinary raiders")
 s=rich()
 s.build_at(Vector2(6200,2800),"cannon")
 s.buildings[1].age=10
 s.wave=5
 s.elapsed=120
 s.spawn_remaining=s.wave_size(5)
 elite=s.spawn_enemy()
 elite.pos=Vector2(5900,2800)
 hp=elite.hp
 s.spawn_remaining=0
 s.step(0.2)
 check(elite.hp>0 and is_equal_approx(hp-elite.hp,s.stat(s.buildings[1],"damage")),"Cannon damage is unmodified and a fresh elite survives its first shell")
 # Save validation, actual legacy fixture, and exact fifteen-minute/endless rules.
 saved=roundtrip(s)
 check(saved!=null and saved.enemies[0].kind=="elite","Elite state survives a save round trip")
 var bad:Dictionary=s.snapshot()
 bad.research_levels.arrow=101
 check(Sim.restore(bad)==null,"Corrupt global research levels are rejected")
 bad=s.snapshot()
 bad.research_job={"kind":"arrow","level":2,"duration":35,"remaining":-1}
 check(Sim.restore(bad)==null,"Corrupt research timers are rejected")
 var old=Sim.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/frontier-preview.json")))
 check(old!=null and old.buildings[1].pos==Vector2(4544,3264),"Legacy free-position settlements retain their foundations")
 check(Sim.restore({"version":1})==null,"Malformed prototype saves do not corrupt the frontier")
 s=rich()
 s.elapsed=899.95
 s.wave=30
 s.step(0.05)
 check(s.victory and s.elapsed>=900,"Victory arrives after fifteen simulated minutes")
 s.victory_seen=true
 s.step(0.1)
 check(s.elapsed>900 and not s.defeated,"Play continues in endless mode after victory")
 print("RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
