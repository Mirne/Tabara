@static_unload
class_name Settlement
extends RefCounted
## Deterministic, presentation-independent mission simulation. All time is seconds.

const VICTORY_TIME := 900.0
const MAX_LEVEL := 100
const WAVE_SECONDS := 30.0
const SAVE_VERSION := 6
const Navigator=preload("res://scripts/assault_navigation.gd")
static var shared_navigation:Dictionary={}
var mountains_enabled:=true
var terrain_revision:=World.AUTHORED_REVISION
var foundation_cells:Dictionary={}
var navigation
var body_cells:Dictionary={}
var wall_cells:Dictionary={}
var hit_cells:Dictionary={}
var hit_rects:Array[Rect2]=[]
var hit_seen:=PackedInt64Array()
var hit_serial:=0
const RESOURCE_NAMES := ["wood", "stone", "gold"]
const World = preload("res://scripts/world_data.gd")
const PATH = World.ROAD
const MAX_BUILDINGS := 512
const MAX_ENEMIES := 2400
const BUILD_TIME := 2.5
const GRID_SIZE := 40.0
const FOUNDATION_WIDTHS := {"hall":240.0,"wood":160.0,"stone":160.0,"arrow":80.0,"wall":80.0,"cannon":160.0,"market":160.0}
const FOOTPRINTS := {"hall":100.0,"wood":65.0,"stone":68.0,"arrow":45.0,"wall":34.0,"cannon":52.0,"market":76.0}
const BODY_GAPS := {"raider":30.0,"runner":28.0,"brute":43.0,"siege":60.0}
const DEFINITIONS := {
 "hall": {"name":"Main hall", "tag":"THE HEART OF TABARA", "desc":"Your last line of defense. Fires arrows and provides a small steady income.", "cost":[0,0,0], "upgrade":[65,45,25], "hp":4200.0, "damage":50.0, "range":560.0, "period":0.9, "art":0},
 "wood": {"name":"Woodcutter", "tag":"WOOD PRODUCTION", "desc":"Harvests timber automatically. Build in a marked timber working pocket. One woodcutter per site.", "cost":[60,20,10], "upgrade":[50,25,15], "hp":300.0, "income":4.0, "resource":"wood", "art":1},
 "stone": {"name":"Stonemason", "tag":"STONE PRODUCTION", "desc":"Quarries stone automatically. Must be built on a stone deposit. One stonemason per quarry.", "cost":[70,15,15], "upgrade":[45,40,15], "hp":380.0, "income":3.0, "resource":"stone", "art":2},
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

func _init(seed_number:int=2026,layout:int=World.AUTHORED_REVISION)->void:
 terrain_revision=layout
 mountains_enabled=layout!=0
 reset_navigation()
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
 spawn_enemy()
 spawn_remaining=maxi(0,spawn_remaining-1)
 spawn_clock=1.0

func reset_navigation()->void:
 if not shared_navigation.has(terrain_revision): shared_navigation[terrain_revision]=Navigator.new(World.HALL,terrain_revision)
 navigation=shared_navigation[terrain_revision]

func grid_blocked(cell:Vector2i)->bool:
 if World.cell_terrain(cell,terrain_revision)>0: return true
 var index:int=foundation_cells.get(cell,-1)
 return index>=0 and buildings[index]!=null and buildings[index].hp>0

func make_building(kind: String, position: Vector2 = Vector2.ZERO) -> Dictionary:
 return {"kind":kind,"pos":position,"level":1,"hp":float(DEFINITIONS[kind].hp),"cooldown":0.15,"age":0.0,"ruined_at":-1.0}

func footprint(kind: String) -> float:
 return FOOTPRINTS.get(kind,65.0)

func snap_position(position: Vector2, kind: String = "") -> Vector2:
 if kind in ["wood","stone"]:
  var node:=deposit_near(position,kind)
  if node>=0: return resource_nodes[node].pos.snapped(Vector2.ONE*GRID_SIZE)
 return position.snapped(Vector2.ONE*GRID_SIZE)

func foundation_rect(position: Vector2, kind: String) -> Rect2:
 var width:float=FOUNDATION_WIDTHS.get(kind,160.0)
 return Rect2(position-Vector2.ONE*width/2,Vector2.ONE*width)

func deposit_near(position: Vector2, kind: String, distance_limit: float = 200.0) -> int:
 var nearest:=-1
 var distance:=distance_limit
 for i in resource_nodes.size():
  if resource_nodes[i].kind!=kind: continue
  var current:float=position.distance_to(resource_nodes[i].pos)
  if current<distance:
   nearest=i
   distance=current
 return nearest

func producer_deposit(building: Dictionary) -> int:
 if building.kind not in ["wood","stone"]: return -1
 # Existing v2 settlements retain their buildings and reserve their closest site.
 return deposit_near(building.pos,building.kind,520.0)

func deposit_owner(index: int) -> int:
 for i in buildings.size():
  if buildings[i]!=null and producer_deposit(buildings[i])==index: return i
 return -1

func placement_error(position: Vector2, kind: String) -> String:
 if defeated: return "The main hall has fallen. Start a new settlement."
 if not DEFINITIONS.has(kind) or kind=="hall": return "Choose a construction tool."
 var foundation:=foundation_rect(position,kind)
 var radius:float=foundation.size.x/2
 var own_deposit:=-1
 if kind in ["wood","stone"]:
  own_deposit=deposit_near(position,kind,45.0)
  if own_deposit<0: return "Place this producer on a %s deposit."%("forest" if kind=="wood" else "stone")
  if deposit_owner(own_deposit)>=0: return "This deposit already has a producer. Repair or clear its building."
 var terrain:String=World.terrain_error(position,radius,own_deposit,terrain_revision)
 if terrain!="": return terrain
 for i in nearby_buildings(position,radius+180):
  var b=buildings[i]
  if b==null: continue
  if foundation.intersects(foundation_rect(b.pos,b.kind)):
   return "These grid cells are occupied. Clear ruins to reuse their ground."
 if active_building_count()>=MAX_BUILDINGS: return "The frontier supports up to 512 structures."
 return ""

func active_building_count() -> int:
 var count:=0
 for b in buildings:
  if b!=null: count+=1
 return count

func rebuild_building_grid() -> void:
 building_cells.clear()
 foundation_cells.clear()
 wall_cells.clear()
 hit_cells.clear()
 hit_rects.resize(buildings.size())
 hit_seen.resize(buildings.size())
 hit_seen.fill(0)
 for i in buildings.size():
  if buildings[i]==null: continue
  var rect:=foundation_rect(buildings[i].pos,buildings[i].kind)
  hit_rects[i]=rect
  for fy in range(floori(rect.position.y/GRID_SIZE),ceili(rect.end.y/GRID_SIZE)):
   for fx in range(floori(rect.position.x/GRID_SIZE),ceili(rect.end.x/GRID_SIZE)):
    foundation_cells[Vector2i(fx,fy)]=i
  for hy in range(floori(rect.position.y/80),floori(rect.end.y/80)+1):
   for hx in range(floori(rect.position.x/80),floori(rect.end.x/80)+1):
    var key:=Vector2i(hx,hy)
    if not hit_cells.has(key): hit_cells[key]=[]
    hit_cells[key].append(i)
  if buildings[i].kind=="wall": wall_cells[Vector2i((buildings[i].pos/GRID_SIZE).round())]=i
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
 position=snap_position(position,kind)
 var error:=placement_error(position,kind)
 if error!="": return error
 if not spend(DEFINITIONS[kind].cost): return "Not enough supplies. Gather resources or grow production."
 var index:=buildings.find(null)
 var b:=make_building(kind,position)
 if index<0: buildings.append(b)
 else: buildings[index]=b
 clear_vegetation(position,footprint(kind)+45)
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

func collect(_index: int) -> bool:
 # Resource sites are passive scenery; production and combat supply the economy.
 return false

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

func wave_size(number:int) -> int:
 var count:=mini(220,8+int(number*2.7))
 return mini(300,count*2) if number%5==0 else count

func begin_wave() -> void:
 spawn_remaining = wave_size(wave)
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
 enemy.pos=path_point(initial_progress)+Vector2(0,enemy.lane)
 enemy.push=Vector2.ZERO
 enemy.aim=0.0
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
 return enemy.pos

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
  spawn_clock += maxf(0.065,21.0/float(wave_size(wave)))
 var rates := income_rates()
 for key in RESOURCE_NAMES: resources[key] = minf(1.0e15,resources[key]+rates[key]*delta)
 for i in deposits.size(): deposits[i] = maxf(0,deposits[i]-delta)
 enemy_cells.clear()
 enemy_positions.clear()
 body_cells.clear()
 for e in enemies:
  if e.hp<=0: continue
  var p:Vector2=e.pos
  enemy_positions[e.id]=p
  var cell:=Vector2i(floori(p.x/256),floori(p.y/256))
  if not enemy_cells.has(cell): enemy_cells[cell]=[]
  enemy_cells[cell].append(e)
  var body_cell:=Vector2i(floori(p.x/64),floori(p.y/64))
  if not body_cells.has(body_cell): body_cells[body_cell]=[]
  body_cells[body_cell].append(e)
 for i in buildings.size():
  var b = buildings[i]
  if b == null: continue
  b.age += delta
  if b.hp <= 0 or b.age<BUILD_TIME: continue
  b.cooldown -= delta
  if b.cooldown > 0 or not DEFINITIONS[b.kind].has("damage"): continue
  var target = null
  var farthest := -INF
  var radius:=stat(b,"range")
  for e in nearby_enemies(b.pos,radius):
   if e.hp <= 0: continue
   var threat:float=-enemy_positions[e.id].distance_to(buildings[0].pos)
   if enemy_positions[e.id].distance_to(b.pos) <= radius and threat > farthest:
    target = e
    farthest = threat
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
 for e in enemies:
  if e.hp<=0: continue
  e.cooldown-=delta
  var pos:Vector2=e.pos
  if not navigation.passable(pos):
   pos=navigation.nearest_open(pos)
   e.pos=pos
  var body:float=BODY_GAPS[e.kind]*0.5
  e.aim=float(e.get("aim",0.0))-delta
  var held:int=e.target
  var reach:float=220.0 if e.kind=="siege" else e.speed*delta+10.0
  if e.aim>0 and held>=0 and held<buildings.size() and buildings[held]!=null and buildings[held].hp>0 and hit_rects[held].grow(body+reach).has_point(pos):
   attack_building(e,held)
   continue
  var heading:Vector2=navigation.direction(pos)
  e.scan-=delta
  var separation:Vector2=e.get("push",Vector2.ZERO)
  if e.scan<=0:
   e.scan=0.2
   separation=Vector2.ZERO
   var cell:=Vector2i(floori(pos.x/64),floori(pos.y/64))
   var checked:=0
   for dy in range(-1,2):
    for dx in range(-1,2):
     for other in body_cells.get(cell+Vector2i(dx,dy),[]):
      if other.id==e.id or other.hp<=0: continue
      checked+=1
      if checked>40: break
      var diff:Vector2=pos-enemy_positions[other.id]
      var distance:float=diff.length()
      var gap:float=body+BODY_GAPS[other.kind]*0.5+4
      if distance<gap:
       if distance<0.01: diff=Vector2.from_angle(float(e.id)*2.399963)
       else: diff/=distance
       separation+=diff*(1.0-distance/gap)
   e.push=separation
  var velocity:Vector2=heading+separation*1.35
  if velocity.length()>1: velocity=velocity.normalized()
  var proposed:Vector2=pos+velocity*e.speed*delta
  var walkable:bool=navigation.can_step(pos,proposed)
  if not walkable:
   proposed=pos+heading*e.speed*delta
   walkable=navigation.can_step(pos,proposed)
   if not walkable:
    # Recenter inside the current open cell before taking a tight terrain turn.
    var recovery:Vector2=pos.direction_to(navigation.center(navigation.cell_of(pos)))
    proposed=pos+recovery*minf(e.speed*delta,pos.distance_to(navigation.center(navigation.cell_of(pos))))
    walkable=navigation.can_step(pos,proposed)
  var lookahead:float=220.0 if e.kind=="siege" else e.speed*delta+10.0
  var blocker:=first_blocker(pos,pos+heading*lookahead,body)
  if blocker<0: blocker=first_blocker(pos,proposed,body)
  e.target=blocker
  e.aim=0.2
  if blocker>=0:
   attack_building(e,blocker)
  elif walkable:
   e.pos=proposed
   e.progress=minf(total_length,e.progress+pos.distance_to(proposed))
 for i in range(enemies.size()-1,-1,-1):
  var e: Dictionary = enemies[i]
  if e.hp <= 0:
   kills += 1
   var reward:float=ceilf((3.0+wave*0.45)*(2.5 if e.kind == "siege" else (1.5 if e.kind=="brute" else 1.0)))
   resources.gold = minf(1.0e15,resources.gold+reward)
   events.append({"type":"kill","gold":reward,"pos":enemy_position(e),"text":"","kind":e.kind,"phase":e.phase})
   enemies.remove_at(i)
 # Bound event memory even in non-visual simulations.
 if events.size() > 250: events = events.slice(-150)

func segment_entry(start:Vector2,end:Vector2,rect:Rect2)->float:
 var direction:=end-start
 var enter:=0.0
 var leave:=1.0
 for axis in 2:
  if absf(direction[axis])<0.00001:
   if start[axis]<rect.position[axis] or start[axis]>rect.end[axis]: return INF
  else:
   var a:float=(rect.position[axis]-start[axis])/direction[axis]
   var b:float=(rect.end[axis]-start[axis])/direction[axis]
   enter=maxf(enter,minf(a,b))
   leave=minf(leave,maxf(a,b))
   if enter>leave: return INF
 return enter

func first_blocker(start:Vector2,end:Vector2,body:float)->int:
 var result:=-1
 var nearest:=INF
 hit_serial+=1
 var minimum:Vector2=start.min(end)-Vector2.ONE*body
 var maximum:Vector2=start.max(end)+Vector2.ONE*body
 for y in range(floori(minimum.y/80),floori(maximum.y/80)+1):
  for x in range(floori(minimum.x/80),floori(maximum.x/80)+1):
   for i in hit_cells.get(Vector2i(x,y),[]):
    if hit_seen[i]==hit_serial: continue
    hit_seen[i]=hit_serial
    var b=buildings[i]
    if b==null or b.hp<=0: continue
    var contact:=segment_entry(start,end,hit_rects[i].grow(body))
    if contact<nearest:
     nearest=contact
     result=i
 return result

func attack_building(enemy:Dictionary,index:int)->void:
 if enemy.cooldown>0: return
 var b:Dictionary=buildings[index]
 b.hp=maxf(0,b.hp-enemy.damage)
 enemy.cooldown=1.15
 events.append({"type":"hit","pos":b.pos,"text":""})
 if b.hp<=0:
  b.ruined_at=elapsed
  events.append({"type":"ruin","pos":b.pos,"text":"Building ruined","kind":b.kind})
  if index==0: defeated=true

func wall_neighbors(index:int)->Dictionary:
 var result:Dictionary={}
 var b=buildings[index]
 if b==null or b.kind!="wall" or b.hp<=0: return result
 for offset in [Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2)]:
  var i:int=wall_cells.get(Vector2i((b.pos/GRID_SIZE).round())+offset,-1)
  if i>=0 and buildings[i]!=null and buildings[i].hp>0: result[offset]=i
 return result

func wall_line(start:Vector2,end:Vector2)->Array:
 var anchor:=snap_position(start)
 # A stroke beginning on a wall uses that wall's lattice, including legacy saves.
 for i in nearby_buildings(anchor,80):
  if buildings[i]!=null and buildings[i].kind=="wall" and buildings[i].pos.distance_to(start)<45:
   anchor=buildings[i].pos
   break
 var destination:=anchor+(end-anchor).snapped(Vector2(80,80))
 var cursor:=anchor
 var result:Array=[cursor]
 while cursor!=destination and result.size()<65:
  var diff:Vector2=destination-cursor
  if absf(diff.x)>=absf(diff.y): cursor.x+=signf(diff.x)*80
  else: cursor.y+=signf(diff.y)*80
  result.append(cursor)
 return result

func wall_at(position:Vector2)->int:
 for i in nearby_buildings(position,80):
  if buildings[i]!=null and buildings[i].kind=="wall" and buildings[i].pos.distance_to(position)<1: return i
 return -1

func wall_preview(points:Array)->Dictionary:
 var count:=0
 var error:=""
 if points.is_empty(): error="Drag on the map to preview a wall."
 elif points.size()>64: error="Build a shorter wall (maximum 64 pieces per stroke)."
 for point in points:
  var existing:=wall_at(point)
  if existing>=0:
   if buildings[existing].hp<=0 and error=="": error="Repair or clear the ruined wall before extending this line."
   continue
  count+=1
  if error=="": error=placement_error(point,"wall")
 if error=="" and count==0: error="These wall pieces already exist."
 if error=="" and active_building_count()+count>MAX_BUILDINGS: error="The frontier supports up to 512 structures."
 var cost:Array=[]
 for value in DEFINITIONS.wall.cost: cost.append(value*count)
 if error=="" and not can_afford(cost): error="Not enough supplies for the entire wall."
 return {"count":count,"cost":cost,"error":error}

func build_wall(points:Array)->String:
 var preview:=wall_preview(points)
 if preview.error!="": return preview.error
 var event_start:=events.size()
 # Full validation precedes spending; no partial walls when a stroke is invalid.
 for point in points:
  if wall_at(point)>=0: continue
  var error:=build_at(point,"wall")
  if error!="": return error
 events.resize(event_start)
 events.append({"type":"build","pos":points[points.size()/2],"text":"Wall · %d new pieces"%preview.count})
 return ""

func snapshot() -> Dictionary:
 var saved_buildings:Array=[]
 for b in buildings:
  if b==null: saved_buildings.append(null)
  else:
   var copy:Dictionary=b.duplicate(true)
   copy.pos=[b.pos.x,b.pos.y]
   saved_buildings.append(copy)
 var saved_enemies:Array=[]
 for e in enemies:
  var copy:Dictionary=e.duplicate(true)
  copy.pos=[e.pos.x,e.pos.y]
  var push:Vector2=e.get("push",Vector2.ZERO)
  copy.push=[push.x,push.y]
  saved_enemies.append(copy)
 return {"version":SAVE_VERSION,"mountains_enabled":mountains_enabled,"terrain_revision":terrain_revision,"resources":resources.duplicate(true),"buildings":saved_buildings,"enemies":saved_enemies,"deposits":deposits.duplicate(),"elapsed":elapsed,"wave":wave,"kills":kills,"victory_seen":victory_seen,"spawn_remaining":spawn_remaining,"spawn_clock":spawn_clock,"next_id":next_id,"seed":seed_value,"rng_state":str(rng.state),"cleared_ground":cleared_ground.keys()}

static func restore(data: Dictionary):
 if not _number(data.get("version"),2,SAVE_VERSION) or float(data.version)!=floorf(data.version): return null
 if int(data.version) not in [2,3,4,5,SAVE_VERSION]: return null
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
 var layout:=1
 if data.version>=5:
  if not _number(data.get("terrain_revision"),0,World.AUTHORED_REVISION) or float(data.terrain_revision)!=floorf(data.terrain_revision): return null
  layout=int(data.terrain_revision)
 elif data.version>=4:
  if not data.get("mountains_enabled") is bool: return null
  layout=1 if data.mountains_enabled else 0
 var sim=load("res://scripts/simulation.gd").new(int(data.seed),layout)
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
  if data.version>=3:
   if not e.get("pos") is Array or e.pos.size()!=2: return null
   if not _number(e.pos[0],0,World.SIZE.x) or not _number(e.pos[1],0,World.SIZE.y): return null
 sim.resources=data.resources.duplicate(true)
 sim.cleared_ground.clear()
 for cell in data.cleared_ground: sim.cleared_ground[int(cell)]=true
 sim.buildings=restored
 if data.version<4:
  # Older settlements keep the terrain on which their foundations were built.
  for b in sim.buildings:
   if b!=null and World.mountain_conflict(sim.foundation_rect(b.pos,b.kind),1): sim.terrain_revision=0
 sim.mountains_enabled=sim.terrain_revision!=0
 sim.reset_navigation()
 if sim.buildings[0].pos!=World.HALL: sim.navigation=Navigator.new(sim.buildings[0].pos,sim.terrain_revision)
 sim.enemies=data.enemies.duplicate(true)
 for e in sim.enemies:
  e.pos=Vector2(e.pos[0],e.pos[1]) if data.version>=3 else sim.path_point(e.progress)+Vector2(0,e.lane)
  var push=e.get("push",[0,0])
  if not push is Array or push.size()!=2 or not _number(push[0],-80,80) or not _number(push[1],-80,80): return null
  e.push=Vector2(push[0],push[1])
  if not _number(e.get("aim",0.0),-1,1): return null
  e.aim=float(e.get("aim",0.0))
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
