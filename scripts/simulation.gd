class_name Settlement
extends RefCounted
## Deterministic, presentation-independent mission simulation. All time is seconds.

const VICTORY_TIME := 900.0
const MAX_LEVEL := 100
const WAVE_SECONDS := 30.0
const SAVE_VERSION := 2
const RESOURCE_NAMES := ["wood", "stone", "gold"]
const World = preload("res://scripts/world_data.gd")
const PATH = World.ROAD
const MAX_BUILDINGS := 512
const MAX_ENEMIES := 2400
const BUILD_TIME := 2.5
const FOOTPRINTS := {"hall":100.0,"wood":65.0,"stone":68.0,"arrow":45.0,"wall":34.0,"cannon":52.0,"market":76.0}
const BODY_GAPS := {"raider":30.0,"runner":28.0,"brute":43.0,"siege":60.0}
const DEFINITIONS := {
 "hall": {"name":"Main hall", "tag":"THE HEART OF TABARA", "desc":"Your last line of defense. Fires arrows and provides a small steady income.", "cost":[0,0,0], "upgrade":[65,45,25], "hp":4200.0, "damage":50.0, "range":560.0, "period":0.9, "art":0},
 "wood": {"name":"Woodcutter", "tag":"WOOD PRODUCTION", "desc":"Harvests timber automatically. Build beside a pine grove for a 25% bonus.", "cost":[60,20,10], "upgrade":[50,25,15], "hp":300.0, "income":4.0, "resource":"wood", "art":1},
 "stone": {"name":"Stonemason", "tag":"STONE PRODUCTION", "desc":"Quarries stone automatically. Build beside a quarry for a 25% bonus.", "cost":[70,15,15], "upgrade":[45,40,15], "hp":380.0, "income":3.0, "resource":"stone", "art":2},
 "arrow": {"name":"Arrow tower", "tag":"FAST SINGLE TARGET", "desc":"Accurate, rapid arrows. Best against scouts and lone raiders.", "cost":[75,40,20], "upgrade":[55,35,20], "hp":500.0, "damage":24.0, "range":460.0, "period":0.85, "art":3},
 "wall": {"name":"Wall", "tag":"HOLD THE LINE", "desc":"Build freely to form a defensive line. Enemies attack walls in their way.", "cost":[25,65,10], "upgrade":[20,55,10], "hp":1250.0, "art":4},
 "cannon": {"name":"Cannon tower", "tag":"AREA DAMAGE", "desc":"Explosive shells damage every enemy in a wide blast. Strong against groups.", "cost":[100,100,55], "upgrade":[65,75,35], "hp":650.0, "damage":88.0, "range":590.0, "period":2.7, "splash":140.0, "art":5},
 "market": {"name":"Marketplace", "tag":"GOLD & RESOURCE TRADE", "desc":"Generates gold automatically. Unlocks trading surplus timber or stone for gold.", "cost":[85,50,25], "upgrade":[55,40,25], "hp":350.0, "income":2.0, "resource":"gold", "art":6}
}
var resources := {"wood":450.0,"stone":320.0,"gold":180.0}
var buildings: Array = []
var enemies: Array = []
var events: Array = []
var resource_nodes: Array = World.resource_nodes()
var deposits: Array = []
var building_cells: Dictionary = {}
var enemy_cells: Dictionary = {}
var enemy_positions: Dictionary = {}
var cleared_ground: Dictionary = {}
var elapsed := 0.0
var wave := 1
var kills := 0
var defeated := false
var victory := false
var victory_seen := false
var spawn_remaining := 0
var spawn_clock := 0.0
var next_id := 1
var seed_value := 2026
var rng := RandomNumberGenerator.new()
var path_lengths: Array[float] = []
var total_length := 0.0

func _init(seed_number: int = 2026) -> void:
 seed_value = seed_number
 rng.seed = seed_number
 for i in range(PATH.size()-1):
  total_length += PATH[i].distance_to(PATH[i+1])
  path_lengths.append(total_length)
 buildings.append(make_building("hall",World.HALL))
 buildings[0].age=BUILD_TIME
 clear_vegetation(World.HALL,260)
 deposits.resize(resource_nodes.size())
 deposits.fill(0.0)
 rebuild_building_grid()
 begin_wave()
 for j in 4:
  spawn_enemy(maxf(0,total_length-400-j*85))
  spawn_remaining=maxi(0,spawn_remaining-1)

func make_building(kind: String, position: Vector2 = Vector2.ZERO) -> Dictionary:
 return {"kind":kind,"pos":position,"level":1,"hp":float(DEFINITIONS[kind].hp),"cooldown":0.15,"age":0.0,"ruined_at":-1.0}

func footprint(kind: String) -> float:
 return FOOTPRINTS.get(kind,65.0)

func snap_position(position: Vector2) -> Vector2:
 return position.snapped(Vector2(16,16))

func placement_error(position: Vector2, kind: String) -> String:
 if defeated: return "The main hall has fallen. Start a new settlement."
 if not DEFINITIONS.has(kind) or kind=="hall": return "Choose a construction tool."
 var radius:=footprint(kind)
 var terrain:String=World.terrain_error(position,radius)
 if terrain!="": return terrain
 for i in nearby_buildings(position,radius+130):
  var b=buildings[i]
  if b==null: continue
  if position.distance_to(b.pos)<radius+footprint(b.kind)+8: return "Leave space between foundations. Clear ruins to reuse their ground."
 if active_building_count()>=MAX_BUILDINGS: return "The frontier supports up to 512 structures."
 return ""

func active_building_count() -> int:
 var count:=0
 for b in buildings:
  if b!=null: count+=1
 return count

func rebuild_building_grid() -> void:
 building_cells.clear()
 for i in buildings.size():
  if buildings[i]==null: continue
  var cell:=Vector2i(floori(buildings[i].pos.x/256),floori(buildings[i].pos.y/256))
  if not building_cells.has(cell): building_cells[cell]=[]
  building_cells[cell].append(i)

func nearby_buildings(position: Vector2, radius: float) -> Array:
 var out:Array=[]
 for y in range(floori((position.y-radius)/256),floori((position.y+radius)/256)+1):
  for x in range(floori((position.x-radius)/256),floori((position.x+radius)/256)+1):
   out.append_array(building_cells.get(Vector2i(x,y),[]))
 return out

func nearby_enemies(position: Vector2, radius: float) -> Array:
 var out:Array=[]
 for y in range(floori((position.y-radius)/256),floori((position.y+radius)/256)+1):
  for x in range(floori((position.x-radius)/256),floori((position.x+radius)/256)+1):
   out.append_array(enemy_cells.get(Vector2i(x,y),[]))
 return out

func build_at(position: Vector2, kind: String) -> String:
 position=snap_position(position)
 var error:=placement_error(position,kind)
 if error!="": return error
 if not spend(DEFINITIONS[kind].cost): return "Not enough supplies. Gather resources or grow production."
 var index:=buildings.find(null)
 var b:=make_building(kind,position)
 if index<0: buildings.append(b)
 else: buildings[index]=b
 clear_vegetation(position,footprint(kind)+150)
 rebuild_building_grid()
 events.append({"type":"build","pos":position,"text":"Construction started"})
 return ""

func clear_vegetation(position: Vector2, radius: float) -> void:
 for y in range(maxi(0,floori((position.y-radius)/64)),mini(79,floori((position.y+radius)/64))+1):
  for x in range(maxi(0,floori((position.x-radius)/64)),mini(127,floori((position.x+radius)/64))+1):
   if (Vector2(x,y)*64+Vector2(32,32)).distance_to(position)<=radius:
    cleared_ground[y*128+x]=true

func vegetation_cleared(position: Vector2) -> bool:
 return cleared_ground.has(floori(position.y/64)*128+floori(position.x/64))

func clear_at(index: int) -> String:
 if defeated: return "The main hall has fallen."
 if index<=0 or index>=buildings.size() or buildings[index]==null: return "Select a structure to remove."
 var b:Dictionary=buildings[index]
 if b.hp>0:
  var cost:Array=DEFINITIONS[b.kind].cost
  for i in 3: resources[RESOURCE_NAMES[i]]+=floorf(cost[i]*0.25)
 events.append({"type":"ruin","pos":b.pos,"text":"Ground cleared","kind":b.kind})
 buildings[index]=null
 rebuild_building_grid()
 return ""

func production_bonus(b: Dictionary) -> float:
 var centers:Array=World.GROVES if b.kind=="wood" else World.QUARRIES
 if b.kind not in ["wood","stone"]: return 1.0
 for p in centers:
  if p.distance_to(b.pos)<520: return 1.25
 return 1.0

func stat(building: Dictionary, key: String) -> float:
 var base: float = DEFINITIONS[building.kind].get(key,0.0)
 var growth := 1.14
 if key == "hp": growth = 1.11
 if key == "range": return base + minf(55.0, (building.level-1)*0.8)
 if key == "period": return base / (1.0+minf(0.5,(building.level-1)*0.007))
 return base * pow(growth,building.level-1)

func upgrade_cost(building: Dictionary) -> Array:
 var out: Array = []
 for cost in DEFINITIONS[building.kind].upgrade:
  out.append(ceilf(cost*pow(1.13,building.level-1)))
 return out

func repair_cost(building: Dictionary) -> Array:
 var ratio: float = 1.0-building.hp/stat(building,"hp")
 var base: Array = DEFINITIONS[building.kind].upgrade
 return [ceilf(base[0]*0.4*ratio*pow(1.08,building.level-1)),ceilf(base[1]*0.4*ratio*pow(1.08,building.level-1)),0.0]

func can_afford(cost: Array) -> bool:
 for i in 3:
  if resources[RESOURCE_NAMES[i]]+0.001 < cost[i]: return false
 return true

func spend(cost: Array) -> bool:
 if not can_afford(cost): return false
 for i in 3: resources[RESOURCE_NAMES[i]] = maxf(0.0,resources[RESOURCE_NAMES[i]]-cost[i])
 return true

func upgrade_at(index: int) -> String:
 if defeated: return "Start a new mission to build again."
 if index < 0 or index >= buildings.size() or buildings[index] == null: return "Select a building."
 var b: Dictionary = buildings[index]
 if b.hp <= 0: return "Repair these ruins before upgrading."
 if b.level >= MAX_LEVEL: return "Maximum level reached."
 if not spend(upgrade_cost(b)): return "Not enough resources for this upgrade."
 var fraction: float = b.hp/stat(b,"hp")
 b.level += 1
 b.hp = stat(b,"hp")*fraction
 events.append({"type":"build","pos":b.pos,"text":"Level %d" % b.level})
 return ""

func repair_at(index: int) -> String:
 if defeated: return "The hall has fallen. Start a new mission."
 if index < 0 or index >= buildings.size() or buildings[index] == null: return "Select a building."
 var b: Dictionary = buildings[index]
 if b.hp >= stat(b,"hp")-0.01: return "This building is already at full health."
 if not spend(repair_cost(b)): return "Not enough wood and stone to repair."
 b.hp = stat(b,"hp")
 b.cooldown = maxf(b.cooldown,0.5)
 events.append({"type":"build","pos":b.pos,"text":"Repaired"})
 return ""

func collect(index: int) -> bool:
 if defeated or index < 0 or index >= deposits.size() or deposits[index] > 0: return false
 var d: Dictionary = resource_nodes[index]
 # Modest scaling keeps hand-gathering useful alongside the economy.
 var amount: float = d.amount*(1.0+elapsed/600.0)
 resources[d.kind] += amount
 deposits[index] = 12.0
 events.append({"type":"gather","pos":d.pos,"text":"+%d %s" % [amount,d.kind]})
 return true

func trade(from: String) -> bool:
 if defeated or from not in ["wood","stone"]: return false
 var market_level := 0
 for b in buildings:
  if b != null and b.kind == "market" and b.hp > 0: market_level = maxi(market_level,b.level)
 if market_level == 0 or resources[from] < 60: return false
 resources[from] -= 60.0
 resources.gold += 30.0+minf(25.0,market_level-1)
 return true

func buy(resource: String) -> bool:
 if defeated or resource not in ["wood","stone"] or resources.gold < 60: return false
 var active_market := false
 for b in buildings:
  if b != null and b.kind == "market" and b.hp > 0: active_market = true
 if not active_market: return false
 resources.gold -= 60.0
 resources[resource] += 60.0
 return true

func income_rates() -> Dictionary:
 var rates := {"wood":1.5,"stone":0.9,"gold":0.45}
 for i in buildings.size():
  var b = buildings[i]
  if b == null or b.hp <= 0 or b.age<BUILD_TIME: continue
  var d: Dictionary = DEFINITIONS[b.kind]
  if not d.has("income"): continue
  var bonus := production_bonus(b)
  rates[d.resource] += stat(b,"income")*bonus
 return rates

func begin_wave() -> void:
 spawn_remaining = mini(220,8+int(wave*2.7))
 if wave%5==0: spawn_remaining=mini(300,spawn_remaining*2)
 spawn_clock = 0.0
 events.append({"type":"wave","text":"Wave %d" % wave})

func spawn_enemy(initial_progress: float = 0.0) -> Dictionary:
 if enemies.size()>=MAX_ENEMIES: return {}
 var kind := "raider"
 var roll := rng.randf()
 if wave >= 4 and roll < 0.22: kind = "runner"
 if wave >= 7 and roll > 0.78: kind = "brute"
 if wave >= 14 and wave % 5 == 0 and spawn_remaining == 1: kind = "siege"
 var growth := pow(1.065,minf(wave-1,600))
 var health := 42.0*growth
 var speed := 86.0+minf(34.0,wave*0.7)
 var damage := 10.0*pow(1.055,minf(wave-1,600))
 if kind == "runner":
  health *= 0.65
  speed *= 1.55
 if kind == "brute":
  health *= 2.8
  speed *= 0.75
  damage *= 1.9
 if kind == "siege":
  health *= 7.0
  speed *= 0.55
  damage *= 3.5
 var enemy:={"id":next_id,"kind":kind,"hp":health,"max_hp":health,"damage":damage,"speed":speed,"progress":initial_progress,"cooldown":0.5,"lane":float(rng.randi_range(0,8)*26-104)+rng.randf_range(-3,3),"phase":rng.randf()*TAU,"target":-1,"scan":0.0}
 var index:=enemies.size()
 if initial_progress>0:
  for i in enemies.size():
   if enemies[i].progress<initial_progress:
    index=i
    break
 enemies.insert(index,enemy)
 next_id += 1
 return enemy

func lane_index(enemy:Dictionary)->int:
 return clampi(roundi((enemy.lane+104)/26),0,8)

func path_point(progress: float) -> Vector2:
 var previous := 0.0
 for i in path_lengths.size():
  if progress <= path_lengths[i]: return PATH[i].lerp(PATH[i+1],clampf((progress-previous)/(path_lengths[i]-previous),0.0,1.0))
  previous = path_lengths[i]
 return PATH[-1]

func enemy_position(enemy: Dictionary) -> Vector2:
 return path_point(enemy.progress)+Vector2(0,enemy.lane)

func step(delta: float) -> void:
 if defeated or delta <= 0: return
 # Clients use a fixed step. Subdivision also makes external large steps safe.
 if delta > 0.101:
  var remaining := delta
  while remaining > 0 and not defeated:
   var dt := minf(0.05,remaining)
   step(dt)
   remaining -= dt
  return
 elapsed += delta
 if elapsed >= VICTORY_TIME and not victory:
  victory = true
  events.append({"type":"victory","text":"The hearth endures"})
 var next_wave := int(elapsed/WAVE_SECONDS)+1
 if next_wave > wave:
  wave = next_wave
  begin_wave()
 spawn_clock -= delta
 if spawn_remaining > 0 and spawn_clock <= 0:
  spawn_enemy()
  spawn_remaining -= 1
  spawn_clock += maxf(0.065,21.0/maxf(1,8+wave*2.7))
 var rates := income_rates()
 for key in RESOURCE_NAMES: resources[key] = minf(1.0e15,resources[key]+rates[key]*delta)
 for i in deposits.size(): deposits[i] = maxf(0,deposits[i]-delta)
 enemy_cells.clear()
 enemy_positions.clear()
 var initial_fronts:Array=[INF,INF,INF,INF,INF,INF,INF,INF,INF]
 var initial_bodies:Array=[30.0,30.0,30.0,30.0,30.0,30.0,30.0,30.0,30.0]
 for e in enemies:
  if e.hp<=0: continue
  var lane:=lane_index(e)
  var body:float=BODY_GAPS[e.kind]
  e.progress=minf(e.progress,maxf(0,initial_fronts[lane]-maxf(body,initial_bodies[lane])))
  initial_fronts[lane]=e.progress
  initial_bodies[lane]=body
  var p:=enemy_position(e)
  enemy_positions[e.id]=p
  var cell:=Vector2i(floori(p.x/256),floori(p.y/256))
  if not enemy_cells.has(cell): enemy_cells[cell]=[]
  enemy_cells[cell].append(e)
 for i in buildings.size():
  var b = buildings[i]
  if b == null: continue
  b.age += delta
  if b.hp <= 0 or b.age<BUILD_TIME: continue
  b.cooldown -= delta
  if b.cooldown > 0 or not DEFINITIONS[b.kind].has("damage"): continue
  var target = null
  var farthest := -1.0
  var radius:=stat(b,"range")
  for e in nearby_enemies(b.pos,radius):
   if e.hp <= 0: continue
   if enemy_positions[e.id].distance_to(b.pos) <= radius and e.progress > farthest:
    target = e
    farthest = e.progress
  if target == null:
   b.cooldown=0.15
   continue
  var impact:Vector2=enemy_positions[target.id]
  var damage := stat(b,"damage")
  if b.kind == "cannon":
   for e in nearby_enemies(impact,DEFINITIONS.cannon.splash):
    if enemy_positions[e.id].distance_to(impact) <= DEFINITIONS.cannon.splash: e.hp -= damage
  else: target.hp -= damage
  b.cooldown = stat(b,"period")
  events.append({"type":"shot","from":b.pos-Vector2(0,100),"pos":impact,"cannon":b.kind=="cannon"})
 var movement_fronts:Array=[INF,INF,INF,INF,INF,INF,INF,INF,INF]
 var movement_bodies:Array=[30.0,30.0,30.0,30.0,30.0,30.0,30.0,30.0,30.0]
 for e in enemies:
  if e.hp <= 0: continue
  e.cooldown -= delta
  var pos:Vector2=enemy_positions[e.id]
  var target_index:int=e.target
  var target_valid:bool=target_index>=0 and target_index<buildings.size() and buildings[target_index]!=null and buildings[target_index].hp>0
  if target_valid:
   var held:Dictionary=buildings[target_index]
   var reach:float=300.0 if e.kind=="siege" and held.kind!="wall" else footprint(held.kind)+(42 if held.kind=="wall" else 40)
   target_valid=pos.distance_squared_to(held.pos)<=reach*reach
  if not target_valid and target_index>=0: e.scan=0.0
  if not target_valid: target_index=-1
  e.scan-=delta
  if e.scan<=0:
   e.scan=0.2
   target_index=-1
   # Search at 5 Hz; targets remain stationary while attackers strike them.
   var nearest := 300.0 if e.kind == "siege" else 180.0
   for i in nearby_buildings(pos,nearest):
    var b = buildings[i]
    if b == null or b.hp <= 0: continue
    var dist := pos.distance_to(b.pos)
    if b.kind == "wall" and dist < footprint("wall")+42:
     target_index = i
     break
    if b.kind != "wall" and dist < minf(nearest,300 if e.kind=="siege" else footprint(b.kind)+40):
     nearest = dist
     target_index = i
  e.target=target_index
  if target_index >= 0:
   if e.cooldown <= 0:
    var b: Dictionary = buildings[target_index]
    b.hp = maxf(0,b.hp-e.damage)
    e.cooldown = 1.15
    events.append({"type":"hit","pos":b.pos,"text":""})
    if b.hp <= 0:
     b.ruined_at=elapsed
     events.append({"type":"ruin","pos":b.pos,"text":"Building ruined","kind":b.kind})
     if target_index == 0: defeated = true
  var lane:=lane_index(e)
  var body:float=BODY_GAPS[e.kind]
  if target_index<0:
   var limit:=maxf(0,movement_fronts[lane]-maxf(body,movement_bodies[lane]))
   e.progress=minf(minf(total_length,e.progress+e.speed*delta),limit)
  movement_fronts[lane]=e.progress
  movement_bodies[lane]=body
 for i in range(enemies.size()-1,-1,-1):
  var e: Dictionary = enemies[i]
  if e.hp <= 0:
   kills += 1
   resources.gold += (3.0+wave*0.45)*(2.5 if e.kind == "siege" else 1.0)
   events.append({"type":"kill","pos":enemy_position(e),"text":"","kind":e.kind,"phase":e.phase})
   enemies.remove_at(i)
 # Bound event memory even in non-visual simulations.
 if events.size() > 250: events = events.slice(-150)

func snapshot() -> Dictionary:
 var saved_buildings:Array=[]
 for b in buildings:
  if b==null: saved_buildings.append(null)
  else:
   var copy:Dictionary=b.duplicate(true)
   copy.pos=[b.pos.x,b.pos.y]
   saved_buildings.append(copy)
 return {"version":SAVE_VERSION,"resources":resources.duplicate(true),"buildings":saved_buildings,"enemies":enemies.duplicate(true),"deposits":deposits.duplicate(),"elapsed":elapsed,"wave":wave,"kills":kills,"victory_seen":victory_seen,"spawn_remaining":spawn_remaining,"spawn_clock":spawn_clock,"next_id":next_id,"seed":seed_value,"rng_state":str(rng.state),"cleared_ground":cleared_ground.keys()}

static func restore(data: Dictionary):
 if data.get("version",0)!=SAVE_VERSION: return null
 if not data.get("buildings") is Array or data.buildings.is_empty() or data.buildings.size()>MAX_BUILDINGS: return null
 if not data.get("enemies") is Array or data.enemies.size()>MAX_ENEMIES: return null
 if not data.get("resources") is Dictionary: return null
 if not data.get("cleared_ground") is Array or data.cleared_ground.size()>10240: return null
 for cell in data.cleared_ground:
  if not _number(cell,0,10239) or float(cell)!=floorf(cell): return null
 for key in RESOURCE_NAMES:
  if not _number(data.resources.get(key),0,1e15): return null
 for entry in [["elapsed",0,1e9],["wave",1,40000000],["seed",-2147483648,2147483647],["kills",0,1e12],["spawn_remaining",0,300],["spawn_clock",-1e9,30],["next_id",1,1e12]]:
  if not _number(data.get(entry[0]),entry[1],entry[2]): return null
 if not data.get("victory_seen") is bool: return null
 if not data.get("rng_state") is String or not data.rng_state.is_valid_int(): return null
 if int(data.wave)!=int(float(data.elapsed)/WAVE_SECONDS)+1: return null
 var sim=load("res://scripts/simulation.gd").new(int(data.seed))
 if not data.get("deposits") is Array or data.deposits.size()!=sim.resource_nodes.size(): return null
 for timer in data.deposits:
  if not _number(timer,0,12.01): return null
 var restored:Array=[]
 for i in data.buildings.size():
  var b=data.buildings[i]
  if b==null:
   if i==0: return null
   restored.append(null)
   continue
  if not b is Dictionary or not DEFINITIONS.has(b.get("kind","")): return null
  if (i==0)!=(b.kind=="hall"): return null
  if not b.get("pos") is Array or b.pos.size()!=2: return null
  if not _number(b.pos[0],0,World.SIZE.x) or not _number(b.pos[1],0,World.SIZE.y): return null
  if not _number(b.get("level"),1,100) or float(b.level)!=floorf(b.level): return null
  if not _number(b.get("hp"),0,sim.stat(b,"hp")+0.01): return null
  if not _number(b.get("cooldown"),-1e9,20) or not _number(b.get("age"),0,1e9): return null
  if not _number(b.get("ruined_at"),-1,1e9): return null
  var copy:Dictionary=b.duplicate(true)
  copy.pos=Vector2(b.pos[0],b.pos[1])
  copy.level=int(copy.level)
  restored.append(copy)
 for e in data.enemies:
  if not e is Dictionary or e.get("kind","") not in ["raider","runner","brute","siege"]: return null
  for key in ["hp","max_hp","speed","damage","progress","id","cooldown","lane","phase"]:
   if not _number(e.get(key),-1e9,1e30): return null
  if e.hp<=0 or e.max_hp<=0 or e.hp>e.max_hp or e.speed<=0 or e.damage<=0: return null
  if e.progress<0 or e.progress>sim.total_length or absf(e.lane)>120: return null
  if not _number(e.get("target",-1),-1,511) or float(e.get("target",-1))!=floorf(e.get("target",-1)): return null
  if not _number(e.get("scan",0.0),-1,1): return null
 sim.resources=data.resources.duplicate(true)
 sim.cleared_ground.clear()
 for cell in data.cleared_ground: sim.cleared_ground[int(cell)]=true
 sim.buildings=restored
 sim.enemies=data.enemies.duplicate(true)
 for e in sim.enemies:
  e.target=int(e.get("target",-1))
  e.scan=float(e.get("scan",0.0))
 sim.deposits=data.deposits.duplicate()
 sim.elapsed=float(data.elapsed)
 sim.wave=int(data.wave)
 sim.kills=int(data.kills)
 sim.defeated=sim.buildings[0].hp<=0
 sim.victory=sim.elapsed>=VICTORY_TIME
 sim.victory_seen=data.victory_seen
 sim.spawn_remaining=int(data.spawn_remaining)
 sim.spawn_clock=float(data.spawn_clock)
 sim.next_id=int(data.next_id)
 sim.rng.state=int(data.rng_state)
 sim.events.clear()
 sim.rebuild_building_grid()
 return sim

static func _number(value, minimum: float, maximum: float) -> bool:
 return (value is float or value is int) and is_finite(float(value)) and value>=minimum and value<=maximum
