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
 check(s.terrain_revision==5 and s.resource_nodes.size()==8,"New mission uses eight deliberate resource sites")
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
 for i in Map.terrain_field(5).size():
  if Map.terrain_field(5)[i]==0 and not is_finite(s.navigation.costs[i]):safe=false
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
 # A stroke through mountains uses just the available opening, filling its width.
 s=rich()
 var crossing:Array=s.wall_line(Vector2(4160,2400),Vector2(4160,3200))
 var preview:Dictionary=s.wall_preview(crossing)
 check(preview.error=="" and preview.count==6 and preview.skipped.size()>0,"Wall drag ignores red mountain cells and fits six sections across the pass")
 var charged:Dictionary=s.resources.duplicate()
 check(s.build_wall(crossing)=="" and s.active_building_count()==7,"Valid wall sections build despite skipped red endpoints")
 for i in 3:check(s.resources[Sim.RESOURCE_NAMES[i]]==charged[Sim.RESOURCE_NAMES[i]]-preview.cost[i],"Only eligible wall sections are charged")
 var edges:=0
 var Wall=load("res://scripts/wall_art.gd")
 s=rich()
 for y in range(2800,2961,80):
  for x in range(6000,6161,80):s.build_at(Vector2(x,y),"wall")
 for i in range(1,10):edges+=Wall.exposed_sides(s.wall_neighbors(i)).size()
 check(edges==12 and Wall.exposed_sides(s.wall_neighbors(5)).is_empty(),"A 3x3 wall mass has only twelve perimeter rails and no internal parapets")
 # Instant global upgrades spend once, preserve damage and affect future builds.
 s=rich()
 check(s.start_research("arrow")!="","Upgrades require an operational Workshop")
 check(s.build_at(Vector2(5200,2800),"workshop")=="","Workshop footprint is buildable")
 check(s.start_research("arrow")!="","Workshop construction must finish before upgrading")
 quiet_step(s,7)
 check(s.build_at(Vector2(6100,2800),"arrow")=="" and s.build_at(Vector2(6300,2800),"arrow")=="","Two standing towers share upgrades")
 var first:Dictionary=s.buildings[2]
 var second:Dictionary=s.buildings[3]
 first.hp=s.stat(first,"hp")*0.5
 var cost:Array=s.research_cost("arrow")
 var wood:float=s.resources.wood
 check(s.start_research("arrow")=="" and s.resources.wood==wood-cost[0],"A global upgrade spends its displayed price once")
 check(first.level==2 and second.level==2 and s.research_levels.arrow==2,"All existing towers upgrade immediately without a timer")
 check(is_equal_approx(first.hp/s.stat(first,"hp"),0.5),"Instant upgrades preserve damage instead of granting free healing")
 check(s.start_research("wall")=="" and s.research_levels.wall==2,"Another type can upgrade immediately without a queue")
 check(s.build_at(Vector2(6500,2800),"arrow")=="" and s.buildings[-1].level==2,"Future towers inherit completed global upgrades")
 check(s.upgrade_at(2)!="","Defense upgrades stay in the Workshop")
 var saved=roundtrip(s)
 check(saved!=null and saved.research_levels==s.research_levels,"Instant global levels survive JSON saves")
 var destroyer:Dictionary=s.spawn_enemy()
 destroyer.damage=1e9
 destroyer.cooldown=0
 s.attack_building(destroyer,1)
 check(s.start_research("arrow")!="" and s.research_levels.arrow==2,"Destroyed Workshop stops new purchases without losing completed upgrades")
 # Global defenses and independently upgraded buildings both retain the level cap.
 var progression=rich()
 progression.build_at(Vector2(5200,2800),"workshop")
 progression.buildings[1].age=10
 for kind in Sim.DEFINITIONS:
  var local:bool=kind in Sim.LOCAL_UPGRADES
  var index:int=progression.buildings.size()
  if local:
   var building:Dictionary=progression.make_building(kind,Vector2(6200,2800))
   building.age=10
   progression.buildings.append(building)
  for level in range(2,101):
   var error:String=progression.upgrade_at(index) if local else progression.start_research(kind)
   check(error=="",kind+" purchases level "+str(level))
   var exemplar:Dictionary=progression.buildings[index] if local else progression.make_building(kind,Vector2(6000,2800))
   check(exemplar.level==level and is_finite(progression.stat(exemplar,"hp")) and progression.stat(exemplar,"hp")>0,kind+" level is finite")
  var error:String=progression.upgrade_at(index) if local else progression.start_research(kind)
  check(error!="",kind+" remains capped at 100")
  if local:check(progression.make_building(kind).level==1,kind+" replacement starts at level one")
 # Producer purchases affect one building, preserve damage, and survive mixed-level saves.
 s=rich()
 s.build_at(s.resource_nodes[4].pos,"stone")
 s.build_at(s.resource_nodes[5].pos,"stone")
 quiet_step(s,3)
 first=s.buildings[1]
 second=s.buildings[2]
 first.hp=s.stat(first,"hp")*0.5
 var local_cost:Array=s.upgrade_cost(first)
 wood=s.resources.wood
 check(s.upgrade_at(1)=="" and first.level==2 and second.level==1,"Quarry upgrades are local and require no Workshop")
 check(is_equal_approx(first.hp/s.stat(first,"hp"),0.5) and s.resources.wood==wood-local_cost[0],"Local upgrade pays its quote once and preserves damage")
 check(s.start_research("stone")!="","Workshop cannot buy producer levels")
 saved=roundtrip(s)
 check(saved!=null and saved.buildings[1].level==2 and saved.buildings[2].level==1,"Different local levels survive save/load")
 var hammer:Dictionary=s.spawn_enemy()
 hammer.damage=1e9
 hammer.cooldown=0
 s.attack_building(hammer,1)
 s.rebuild_building_grid()
 check(s.build_at(s.resource_nodes[4].pos,"stone")=="" and s.buildings[1].level==1,"A destroyed quarry is rebuilt on its site at level one")
 s=rich()
 s.build_at(s.resource_nodes[0].pos,"wood")
 s.apply_global_level("wood",4)
 var v09:Dictionary=s.snapshot()
 v09.version=8
 v09.trade_clock=7.0
 saved=Sim.restore(v09)
 check(saved!=null and saved.buildings[1].level==4 and saved.make_building("wood").level==1,"v0.9 producer levels are retained, with local replacement levels")
 check(saved!=null and not saved.snapshot().has("trade_clock"),"Removed Marketplace cooldown is cleared on old saves")
 # Marketplace restores the old passive output and exposes income upgrades.
 s=rich()
 s.build_at(Vector2(5200,2800),"market")
 check(is_equal_approx(s.income_rates().gold,0.1),"Marketplace construction does not produce gold")
 s.buildings[1].age=10
 check(is_equal_approx(s.income_rates().gold,2.1),"Completed Marketplace restores 2 gold per second plus the Hall income")
 check(s.upgrade_at(1)=="" and is_equal_approx(s.income_rates().gold,2.0*1.08+0.1),"Marketplace local upgrade increases passive gold income")
 s.resources.gold=1000.0
 gold=s.resources.gold
 quiet_step(s,10)
 check(is_equal_approx(s.resources.gold-gold,(2.0*1.08+0.1)*10),"Passive upgraded gold is actually credited over time")
 check(not s.has_method("buy") and not s.has_method("trade"),"Marketplace buying and selling are completely removed")
 # Regeneration is a permanent global upgrade; no manual repair or resurrection.
 s=rich()
 check(s.upgrade_regeneration()!="","Regeneration is unlocked at an operational Workshop")
 s.build_at(Vector2(5200,2800),"workshop")
 s.buildings[1].age=10
 s.build_at(Vector2(6100,2800),"arrow")
 var tower:Dictionary=s.buildings[2]
 tower.age=10
 tower.hp=100
 cost=s.regeneration_cost()
 wood=s.resources.wood
 check(s.upgrade_regeneration()=="" and s.resources.wood==wood-cost[0] and tower.hp==100,"Unlocking regeneration spends once and does not heal instantly")
 var hp:float=tower.hp
 quiet_step(s,10)
 check(is_equal_approx(tower.hp,hp+s.stat(tower,"hp")*s.regeneration_rate()*10),"Standing buildings heal automatically at the global rate")
 saved=roundtrip(s)
 check(saved!=null and saved.regeneration_level==1,"Regeneration survives save/reload")
 destroyer=s.spawn_enemy()
 destroyer.damage=1e9
 destroyer.cooldown=0
 s.attack_building(destroyer,1)
 hp=tower.hp
 quiet_step(s,1)
 check(tower.hp>hp,"Completed regeneration persists after Workshop destruction")
 check(s.upgrade_regeneration()!="","Further regeneration upgrades need a replacement Workshop")
 destroyer.cooldown=0
 s.attack_building(destroyer,2)
 quiet_step(s,1)
 check(s.buildings[2]==null,"Regeneration cannot revive destroyed structures")
 check(s.build_at(Vector2(6100,2800),"arrow")=="" and not s.buildings[1].has("repair_left"),"Destroyed foundations are reusable without manual repair state")
 progression=rich()
 progression.build_at(Vector2(5200,2800),"workshop")
 progression.buildings[1].age=10
 for level in range(1,101):
  check(progression.upgrade_regeneration()=="" and progression.regeneration_level==level,"Regeneration purchases global level "+str(level))
 check(progression.upgrade_regeneration()!="" and is_equal_approx(progression.regeneration_rate(),0.2),"Regeneration is capped at 100 and reaches 20 percent HP per second")
 check(is_equal_approx(progression.regeneration_rate(1),0.003) and progression.regeneration_rate(5)>0.01 and progression.regeneration_rate(50)>0.1,"Regeneration preserves its starting rate and grows materially faster")
 # Existing v0.8 paid work completes exactly once, preserving positions and HP.
 var legacy:Dictionary=saved.snapshot()
 legacy.version=7
 legacy.trade_clock=0.0
 legacy.erase("regeneration_level")
 legacy.erase("boss_intervals")
 legacy.research_job={"kind":"arrow","level":2,"duration":35.0,"remaining":20.0}
 legacy.buildings[2].hp=100
 legacy.buildings[2].repair_left=4.0
 legacy.buildings[2].repair_rate=10.0
 var migrated=Sim.restore(legacy)
 check(migrated!=null and migrated.research_levels.arrow==2,"An already-paid old research order finishes on migration without another charge")
 check(migrated!=null and is_equal_approx(migrated.buildings[2].hp,140*1.085),"Paid local repair remainder finishes once before upgrades preserve its damage fraction")
 check(migrated!=null and not migrated.snapshot().has("research_job") and not migrated.buildings[2].has("repair_left"),"New saves contain no research queue or manual repair jobs")
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
 hp=s.buildings[1].hp
 s.step(0.1)
 check(s.buildings[1].hp<hp,"Raiders attack exposed producers instead of ignoring their blocked deposit cells")
 # All four exposed sites attract enemies from a distance and remain reachable.
 for node in Map.resource_nodes(5):
  if node.zone!="outpost": continue
  s=rich()
  s.build_at(node.pos,node.kind)
  var producer:Dictionary=s.buildings[1]
  enemy=s.spawn_enemy()
  enemy.pos=s.navigation.nearest_open(node.pos+Vector2(-720,0))
  enemy.hp=1e8
  enemy.max_hp=1e8
  var initial_hp:float=producer.hp
  var passable:=true
  for tick in 1200:
   s.step(0.05)
   passable=passable and s.navigation.passable(enemy.pos)
   s.enemies=[enemy]
   s.spawn_remaining=0
   if producer.hp<initial_hp:break
  check(producer.hp<initial_hp,"Long-range aggro reaches exposed "+node.kind+" at "+str(node.pos))
  check(passable,"Producer approach never crosses blocked terrain")
 s=rich()
 s.build_at(s.resource_nodes[2].pos,"wood")
 s.build_at(s.resource_nodes[6].pos,"stone")
 enemy=s.spawn_enemy()
 enemy.pos=s.navigation.nearest_open(Vector2(3200,2920))
 s.step(0.05)
 var victim:int=enemy.get("anger",-1)
 check(victim in [1,2],"Nearby exposed producers are acquired proactively")
 enemy.damage=1e9
 enemy.cooldown=0
 s.attack_building(enemy,victim)
 enemy.producer_scan=0
 s.step(0.05)
 check(enemy.get("anger",-1)==(2 if victim==1 else 1),"After one outpost falls, enemies acquire the other producer")
 s.build_at(Vector2(4000,2800),"arrow")
 var defense:int=s.buildings.size()-1
 s.provoke(enemy,defense)
 check(enemy.anger==defense and enemy.anger_source=="defense","A firing defense can interrupt producer aggro")
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
 # Minibosses enter at exactly 5-minute boundaries, including endless mode.
 var schedule=rich()
 schedule.elapsed=299.95
 schedule.wave=10
 schedule.step(0.05)
 var bosses:=0
 for e in schedule.enemies:
  if e.kind=="boss":bosses+=1
 check(bosses==1 and schedule.boss_intervals==1,"First miniboss enters at five game minutes")
 var resumed=roundtrip(schedule)
 resumed.step(0.05)
 bosses=0
 for e in resumed.enemies:
  if e.kind=="boss":bosses+=1
 check(bosses==1 and resumed.boss_intervals==1,"Reloading at a boundary never duplicates a miniboss")
 for interval in [2,3,4]:
  schedule=rich()
  schedule.elapsed=interval*300-0.05
  schedule.wave=int(schedule.elapsed/30)+1
  schedule.boss_intervals=interval-1
  schedule.step(0.05)
  bosses=0
  for e in schedule.enemies:
   if e.kind=="boss":bosses+=1
  check(bosses==1 and schedule.boss_intervals==interval,"Miniboss enters at minute "+str(interval*5))
 check(schedule.enemies[-1].hp>Sim.DEFINITIONS.cannon.damage*10,"Miniboss has enough ordinary health for many base cannon hits")
 # Save validation, actual legacy fixture, and exact fifteen-minute/endless rules.
 saved=roundtrip(s)
 check(saved!=null and saved.enemies[0].kind=="elite","Elite state survives a save round trip")
 var bad:Dictionary=s.snapshot()
 bad.research_levels.arrow=101
 check(Sim.restore(bad)==null,"Corrupt global research levels are rejected")
 bad=s.snapshot()
 bad.regeneration_level=101
 check(Sim.restore(bad)==null,"Corrupt regeneration levels are rejected")
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
