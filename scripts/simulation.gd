@static_unload
class_name Settlement
extends RefCounted
## Deterministic, presentation-independent mission simulation. All time is seconds.

const FINAL_BOSS_TIME := 900.0
const MAX_LEVEL := 100
const WAVE_SECONDS := 30.0
const SAVE_VERSION := 12
const LOCAL_UPGRADES := ["hall","wood","stone","market","workshop"]
const GLOBAL_UPGRADES := ["arrow","wall","cannon"]
const BOSS_INTERVAL := 300.0
const ATTACK_ANIMATION_SECONDS := 0.66
const Abilities=preload("res://scripts/battlefield_abilities.gd")
const PRODUCER_AGGRO_RANGE := 1600.0
const Navigator=preload("res://scripts/assault_navigation.gd")
static var shared_navigation:Dictionary={}
static var shared_retaliation:Dictionary={}
var retaliation_grid:AStarGrid2D
var research_levels:Dictionary={}
var settlement_age := 1
var tower_tracks: Dictionary = {}
var tracks_by_stat: Dictionary = {"arrow":{}, "cannon":{}}
var regeneration_level:=0
var boss_intervals:=0
var final_boss_id:=0
var final_boss_defeated:=false
var legacy_completion:=false
var rain_cooldown:=0.0
var arrow_rains:Array=[]
var foundations_dirty:=false
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
var producer_indices:Array[int]=[]
var producer_approaches:Dictionary={}
const RESOURCE_NAMES := ["wood", "stone", "gold"]
const World = preload("res://scripts/world_data.gd")
const PATH = World.ROAD
const MAX_BUILDINGS := 512
const MAX_ENEMIES := 2400
const BUILD_TIME := 2.5
const GRID_SIZE := 40.0
const FOUNDATION_WIDTHS := {"hall":240.0,"wood":160.0,"stone":160.0,"arrow":80.0,"wall":40.0,"cannon":160.0,"market":160.0,"workshop":200.0}
const FOOTPRINTS := {"hall":100.0,"wood":65.0,"stone":68.0,"arrow":45.0,"wall":16.0,"cannon":52.0,"market":76.0,"workshop":84.0}
const WALL_DIRECTIONS := [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
const BODY_GAPS := {"raider":30.0,"runner":28.0,"brute":43.0,"siege":60.0,"elite":43.0,"boss":62.0}
const AGE_NAMES := ["Wood", "Stone", "Iron", "Steel", "Keep", "Castle", "Citadel", "Crown"]
const AGE_TRACK_LIMITS := [3, 5, 8, 9, 10, 11, 12, MAX_LEVEL]
const AGE_PRICE_GROWTH := 1.5
const ARROW_RANGE_PER_RANK := 20.0
const CANNON_SPLASH_PER_RANK := 12.0
const RADIUS_DIMINISHING_RETURN := 0.035
const FIRING_RATE_PER_RANK := 0.05
const TRACKS := {
 "arrow_damage": {"kind":"arrow", "stat":"damage", "name":"Arrowheads", "unlock_age":1},
 "arrow_range": {"kind":"arrow", "stat":"range", "name":"Bow limbs", "unlock_age":2},
 "arrow_cadence": {"kind":"arrow", "stat":"period", "name":"Quick nocking", "unlock_age":3},
 "cannon_damage": {"kind":"cannon", "stat":"damage", "name":"Round shot", "unlock_age":1},
 "cannon_splash": {"kind":"cannon", "stat":"splash", "name":"Burst shells", "unlock_age":2},
 "cannon_cadence": {"kind":"cannon", "stat":"period", "name":"Loading crew", "unlock_age":3},
}
const DEFINITIONS := {
 "hall": {"name":"Main hall", "tag":"THE HEART OF TABARA", "desc":"Your last line of defense. Fires arrows and provides a small steady income.", "cost":[0,0,0], "upgrade":[65,45,25], "hp":4200.0, "damage":42.0, "range":500.0, "period":1.1, "art":0},
 "wood": {"name":"Woodcutter", "tag":"WOOD PRODUCTION", "desc":"Harvests timber automatically. Build in a marked timber working pocket. One woodcutter per settlement.", "cost":[60,20,10], "upgrade":[50,25,15], "hp":300.0, "income":4.0, "resource":"wood", "art":1},
 "stone": {"name":"Stonemason", "tag":"STONE PRODUCTION", "desc":"Quarries stone automatically. Must be built on a stone deposit. One stonemason per settlement.", "cost":[70,15,15], "upgrade":[45,40,15], "hp":380.0, "income":5.0, "resource":"stone", "art":2},
 "arrow": {"name":"Arrow tower", "tag":"FAST SINGLE TARGET", "desc":"Accurate, rapid arrows. Best against scouts and lone raiders.", "cost":[140,100,60], "upgrade":[55,35,20], "hp":650.0, "damage":30.0, "range":460.0, "period":1.0, "art":3},
 "wall": {"name":"Wall", "tag":"HOLD THE LINE", "desc":"Build freely to form a defensive line. Enemies attack walls in their way.", "cost":[25,55,10], "upgrade":[20,55,10], "hp":2000.0, "art":4},
 "cannon": {"name":"Cannon tower", "tag":"AREA DAMAGE", "desc":"Explosive shells damage every enemy in a wide blast. Strong against groups.", "cost":[220,200,120], "upgrade":[65,75,35], "hp":650.0, "damage":110.0, "range":560.0, "period":3.0, "splash":140.0, "art":5},
 "market": {"name":"Marketplace", "tag":"GOLD PRODUCTION", "desc":"Produces gold automatically.", "cost":[120,80,60], "upgrade":[55,40,25], "hp":450.0, "income":2.0, "resource":"gold", "art":6},
 "workshop": {"name":"Workshop", "tag":"GLOBAL RESEARCH", "desc":"Wall, tower and Regeneration upgrades.", "cost":[140,100,70], "upgrade":[70,60,40], "hp":750.0, "build_time":6.0, "art":7}
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
 resource_nodes=World.resource_nodes(layout)
 for kind in DEFINITIONS: research_levels[kind]=1
 for id in TRACKS:
  tower_tracks[id] = 1
  var track: Dictionary = TRACKS[id]
  tracks_by_stat[track.kind][track.stat] = id
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
 if not shared_retaliation.has(terrain_revision):
  var grid:=AStarGrid2D.new()
  grid.region=Rect2i(0,0,World.GRID_WIDTH,World.GRID_HEIGHT)
  grid.cell_size=Vector2.ONE*GRID_SIZE
  grid.offset=Vector2.ONE*GRID_SIZE*0.5
  grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
  grid.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE
  grid.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE
  grid.update()
  for y in World.GRID_HEIGHT:
   for x in World.GRID_WIDTH:
    if navigation.solid(Vector2i(x,y)): grid.set_point_solid(Vector2i(x,y))
  shared_retaliation[terrain_revision]=grid
 retaliation_grid=shared_retaliation[terrain_revision]

func grid_blocked(cell:Vector2i)->bool:
 if World.cell_terrain(cell,terrain_revision)>0: return true
 var index:int=foundation_cells.get(cell,-1)
 return index>=0 and buildings[index]!=null and buildings[index].hp>0

func make_building(kind: String, position: Vector2 = Vector2.ZERO) -> Dictionary:
 var b:Dictionary={"kind":kind,"pos":position,"level":1 if kind in LOCAL_UPGRADES else int(research_levels.get(kind,1)),"hp":0.0,"cooldown":0.15,"age":0.0,"ruined_at":-1.0}
 if kind=="wall": b.wall_size=GRID_SIZE
 b.hp=stat(b,"hp")
 return b

func footprint(kind: String) -> float:
 return FOOTPRINTS.get(kind,65.0)

func snap_position(position: Vector2, kind: String = "") -> Vector2:
 if kind=="wall": return (position/GRID_SIZE).floor()*GRID_SIZE+Vector2.ONE*GRID_SIZE*0.5
 if kind in ["wood","stone"]:
  var node:=deposit_near(position,kind)
  if node>=0: return resource_nodes[node].pos.snapped(Vector2.ONE*GRID_SIZE)
 return position.snapped(Vector2.ONE*GRID_SIZE)

func foundation_rect(position: Vector2, kind: String, width_override:float=0.0) -> Rect2:
 var width:float=width_override if width_override>0 else FOUNDATION_WIDTHS.get(kind,160.0)
 return Rect2(position-Vector2.ONE*width/2,Vector2.ONE*width)

func building_foundation(building:Dictionary)->Rect2:
 return foundation_rect(building.pos,building.kind,float(building.get("wall_size",GRID_SIZE)) if building.kind=="wall" else 0.0)

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

func singleton_index(kind: String) -> int:
 for i in buildings.size():
  var building = buildings[i]
  if building != null and building.kind == kind and building.hp > 0: return i
 return -1

func placement_error(position: Vector2, kind: String) -> String:
 if defeated: return "The main hall has fallen. Start a new settlement."
 if not DEFINITIONS.has(kind) or kind=="hall": return "Choose a construction tool."
 if kind in ["wood","stone","market","workshop"] and singleton_index(kind) >= 0:
  return "Only one %s may stand at a time." % DEFINITIONS[kind].name
 var foundation:=foundation_rect(position,kind)
 var radius:float=foundation.size.x/2
 var own_deposit:=-1
 if kind in ["wood","stone"]:
  own_deposit=deposit_near(position,kind,45.0)
  if own_deposit<0: return "Place this producer on a %s deposit."%("forest" if kind=="wood" else "stone")
  if deposit_owner(own_deposit)>=0: return "This deposit already has a producer."
 var terrain:String=World.terrain_error(position,radius,own_deposit,terrain_revision)
 if terrain!="": return terrain
 for i in nearby_buildings(position,radius+180):
  var b=buildings[i]
  if b==null: continue
  if foundation.intersects(building_foundation(b)):
   return "These grid cells are occupied."
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
 producer_indices.clear()
 producer_approaches.clear()
 hit_rects.resize(buildings.size())
 hit_seen.resize(buildings.size())
 hit_seen.fill(0)
 for i in buildings.size():
  if buildings[i]==null: continue
  var rect:=building_foundation(buildings[i])
  if DEFINITIONS[buildings[i].kind].has("income"):
   producer_indices.append(i)
   var approaches:Array[Vector2]=[]
   var perimeter:=rect.grow(35)
   for gy in range(floori(perimeter.position.y/GRID_SIZE),ceili(perimeter.end.y/GRID_SIZE)):
    for gx in range(floori(perimeter.position.x/GRID_SIZE),ceili(perimeter.end.x/GRID_SIZE)):
     var point:Vector2=navigation.center(Vector2i(gx,gy))
     if not rect.has_point(point) and navigation.passable(point) and point.distance_to(point.clamp(rect.position,rect.end))<=45:
      approaches.append(point)
   producer_approaches[i]=approaches
  hit_rects[i]=rect
  for fy in range(floori(rect.position.y/GRID_SIZE),ceili(rect.end.y/GRID_SIZE)):
   for fx in range(floori(rect.position.x/GRID_SIZE),ceili(rect.end.x/GRID_SIZE)):
    foundation_cells[Vector2i(fx,fy)]=i
    if buildings[i].kind=="wall":wall_cells[Vector2i(fx,fy)]=i
  for hy in range(floori(rect.position.y/80),floori(rect.end.y/80)+1):
   for hx in range(floori(rect.position.x/80),floori(rect.end.x/80)+1):
    var key:=Vector2i(hx,hy)
    if not hit_cells.has(key): hit_cells[key]=[]
    hit_cells[key].append(i)
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
 if b.kind not in ["wood","stone"]: return 1.0
 for node in resource_nodes:
  if node.kind==b.kind and node.pos.distance_to(b.pos)<520: return 1.25
 return 1.0

func stat(building: Dictionary, key: String) -> float:
 var rank := 1
 if tracks_by_stat.has(building.kind) and tracks_by_stat[building.kind].has(key):
  rank = track_level(tracks_by_stat[building.kind][key])
 return _scaled_stat(building.kind, key, building.level, rank)

func track_value(id: String, next: bool = false) -> float:
 if not TRACKS.has(id): return 0.0
 var track: Dictionary = TRACKS[id]
 var rank := mini(track_level(id) + int(next), MAX_LEVEL)
 return _scaled_stat(track.kind, track.stat, int(research_levels[track.kind]), rank)

func _scaled_stat(kind: String, key: String, building_level: int, track_rank: int) -> float:
 var base: float = DEFINITIONS[kind].get(key, 0.0)
 var grades := building_level - 1
 var ranks := track_rank - 1
 match key:
  "hp": return base * pow(1.085, grades)
  "income": return base * pow(1.08, grades)
  "range": return base + minf(55.0, grades * 0.8) + ARROW_RANGE_PER_RANK * ranks / (1.0 + RADIUS_DIMINISHING_RETURN * ranks)
  "period": return base / ((1.0 + minf(0.5, grades * 0.007)) * (1.0 + ranks * FIRING_RATE_PER_RANK))
  "splash": return base + CANNON_SPLASH_PER_RANK * ranks / (1.0 + RADIUS_DIMINISHING_RETURN * ranks)
  "damage": return base * pow(1.1, maxi(grades, ranks))
  _: return base

func build_time(kind:String)->float:
 return float(DEFINITIONS[kind].get("build_time",BUILD_TIME))

func workshop_index()->int:
 for i in buildings.size():
  var b=buildings[i]
  if b!=null and b.kind=="workshop" and b.hp>0 and b.age>=build_time("workshop"): return i
 return -1

func track_limit(age: int = -1) -> int:
 var selected_age := settlement_age if age < 0 else age
 return AGE_TRACK_LIMITS[clampi(selected_age, 1, AGE_NAMES.size()) - 1]

func track_level(id: String) -> int:
 return int(tower_tracks.get(id, 0))

func age_cost() -> Array:
 if settlement_age >= AGE_NAMES.size(): return []
 var price := []
 for amount in DEFINITIONS.hall.upgrade:
  price.append(ceili(amount * 2.0 * pow(AGE_PRICE_GROWTH, settlement_age - 1)))
 return price

func track_cost(id: String) -> Array:
 if not TRACKS.has(id) or track_level(id) >= MAX_LEVEL: return []
 var price := []
 for amount in DEFINITIONS[TRACKS[id].kind].upgrade:
  price.append(ceili(amount * pow(1.15, track_level(id) - 1)))
 return price

func age_error() -> String:
 if defeated: return "The main hall has fallen."
 if settlement_age >= AGE_NAMES.size(): return "Final age reached."
 if not can_afford(age_cost()): return "Not enough supplies to advance."
 return ""

func advance_age() -> String:
 var error := age_error()
 if error != "": return error
 spend(age_cost())
 settlement_age += 1
 events.append({"type":"age", "age":settlement_age})
 return ""

func required_track_age(id: String) -> int:
 var unlock_age: int = TRACKS[id].unlock_age
 if settlement_age < unlock_age: return unlock_age
 var rank := track_level(id)
 if rank < MAX_LEVEL and rank >= track_limit():
  for age in range(settlement_age + 1, AGE_NAMES.size() + 1):
   if track_limit(age) > rank: return age
 return 0

func track_error(id: String) -> String:
 if defeated: return "The main hall has fallen."
 if not TRACKS.has(id): return "Select a tower upgrade."
 if workshop_index() < 0: return "Complete a Workshop."
 var required_age := required_track_age(id)
 if required_age > 0: return "Requires %s age." % AGE_NAMES[required_age - 1]
 if track_level(id) >= MAX_LEVEL: return "Maximum rank reached."
 if not can_afford(track_cost(id)): return "Not enough supplies."
 return ""

func research_track(id: String) -> String:
 var error := track_error(id)
 if error != "": return error
 spend(track_cost(id))
 tower_tracks[id] = track_level(id) + 1
 events.append({"type":"build", "pos":buildings[workshop_index()].pos, "text":TRACKS[id].name})
 return ""

func research_cost(kind:String)->Array:
 if kind != "wall": return []
 var result:Array=[]
 for value in DEFINITIONS[kind].upgrade: result.append(ceilf(value*2.0*pow(1.15,int(research_levels[kind])-1)))
 return result

func upgrade_cost(building:Dictionary)->Array:
 if building.kind not in LOCAL_UPGRADES: return research_cost(building.kind)
 var result:Array=[]
 for value in DEFINITIONS[building.kind].upgrade: result.append(ceilf(value*pow(1.15,int(building.level)-1)))
 return result

func apply_global_level(kind:String,level:int)->void:
 for b in buildings:
  if b==null or b.kind!=kind: continue
  var fraction:float=b.hp/stat(b,"hp")
  b.level=level
  b.hp=stat(b,"hp")*fraction
 research_levels[kind]=level
 if kind in ["arrow", "cannon"]:
  var damage_track := kind + "_damage"
  tower_tracks[damage_track] = maxi(track_level(damage_track), level)

func start_research(kind:String)->String:
 if defeated: return "The main hall has fallen."
 if kind in ["arrow", "cannon"]: return "Select a tower upgrade."
 if kind not in GLOBAL_UPGRADES: return "Select this building to upgrade it."
 var index:=workshop_index()
 if index<0: return "Build a Workshop and wait for construction to finish."
 if int(research_levels[kind])>=MAX_LEVEL: return "Maximum upgrade level reached."
 if not spend(research_cost(kind)): return "Not enough supplies for this global upgrade."
 apply_global_level(kind,int(research_levels[kind])+1)
 events.append({"type":"build","pos":buildings[index].pos,"text":"All %s · level %d"%[DEFINITIONS[kind].name,research_levels[kind]]})
 return ""

func regeneration_cost()->Array:
 var result:Array=[]
 for value in [120,90,60]: result.append(ceilf(value*pow(1.15,regeneration_level)))
 return result

func regeneration_rate(level:int=-1)->float:
 var value:int=regeneration_level if level<0 else level
 return 0.0 if value<=0 else minf(0.2,0.003+(mini(value,MAX_LEVEL)-1)*(0.2-0.003)/99.0)

func upgrade_regeneration()->String:
 if defeated: return "The main hall has fallen."
 var index:=workshop_index()
 if index<0: return "Build a Workshop and wait for construction to finish."
 if regeneration_level>=MAX_LEVEL: return "Maximum regeneration level reached."
 if not spend(regeneration_cost()): return "Not enough supplies for regeneration."
 regeneration_level+=1
 events.append({"type":"build","pos":buildings[index].pos,"text":"Regeneration · level %d"%regeneration_level})
 return ""

func can_afford(cost: Array) -> bool:
 if cost.size() != RESOURCE_NAMES.size(): return false
 for i in 3:
  if resources[RESOURCE_NAMES[i]]+0.001 < cost[i]: return false
 return true

func rain_damage(next_rank:bool=false)->float:
 var multiplier := track_value("arrow_damage",next_rank) / float(DEFINITIONS.arrow.damage)
 return Abilities.RAIN_PULSE_DAMAGE * Abilities.RAIN_PULSES * multiplier

func rain_ready()->bool:
 return not defeated and Abilities.rain_recharge_seconds>=0 and rain_cooldown<=0 and arrow_rains.is_empty()

func rain_target_error(position:Vector2)->String:
 if defeated:return "The main hall has fallen."
 if not is_finite(position.x) or not is_finite(position.y) or not Rect2(Vector2.ZERO,World.SIZE).has_point(position):return "Choose a target inside the battlefield."
 if not rain_ready():return "Rain of Arrows is recharging."
 return ""

func cast_rain(position:Vector2)->String:
 var error:=rain_target_error(position)
 if error!="":return error
 rain_cooldown=Abilities.rain_recharge_seconds
 arrow_rains.append({"pos":position,"left":Abilities.RAIN_DURATION,"pulses":0,"damage":rain_damage()/Abilities.RAIN_PULSES})
 return ""

func spend(cost: Array) -> bool:
 if not can_afford(cost): return false
 for i in 3: resources[RESOURCE_NAMES[i]] = maxf(0.0,resources[RESOURCE_NAMES[i]]-cost[i])
 return true

func upgrade_at(index:int)->String:
 if defeated: return "The main hall has fallen."
 if index<0 or index>=buildings.size() or buildings[index]==null: return "Select a building."
 var b:Dictionary=buildings[index]
 if b.kind not in LOCAL_UPGRADES: return "Select this upgrade in the Workshop."
 if b.age<build_time(b.kind): return "Building under construction."
 if b.level>=MAX_LEVEL: return "Maximum upgrade level reached."
 if not spend(upgrade_cost(b)): return "Not enough supplies."
 var fraction:float=b.hp/stat(b,"hp")
 b.level+=1
 b.hp=stat(b,"hp")*fraction
 events.append({"type":"build","pos":b.pos,"text":"Level %d"%b.level})
 return ""

func collect(_index: int) -> bool:
 # Resource sites are passive scenery; production and combat supply the economy.
 return false

func income_rates() -> Dictionary:
 var rates := {"wood":0.8,"stone":0.45,"gold":0.1}
 for i in buildings.size():
  var b = buildings[i]
  if b == null or b.hp <= 0 or b.age<build_time(b.kind): continue
  var d: Dictionary = DEFINITIONS[b.kind]
  if not d.has("income"): continue
  var bonus := production_bonus(b)
  rates[d.resource] += stat(b,"income")*bonus
 return rates

func wave_size(number:int) -> int:
 var count:=mini(220,10+int(number*3.1))
 return mini(300,count*2) if number%5==0 else count

func begin_wave() -> void:
 spawn_remaining = wave_size(wave)
 spawn_clock = 0.0
 events.append({"type":"wave","text":"Wave %d" % wave})

func boss_profile(interval:int,mission_boss:bool=false)->Dictionary:
 var rank:=maxi(1,interval)
 return {"hp":4.0 if mission_boss else 1.0+0.5*(rank-1),"damage":2.0 if mission_boss else 1.0+0.15*(rank-1)}

func spawn_enemy(initial_progress: float = 0.0, forced_kind:String="",boss_stage:int=1,mission_boss:bool=false) -> Dictionary:
 if enemies.size()>=MAX_ENEMIES: return {}
 var kind := "raider"
 var roll := rng.randf()
 if wave >= 4 and roll < 0.22: kind = "runner"
 if wave >= 7 and roll > 0.78: kind = "brute"
 if wave>=5 and (roll<minf(0.20,0.035+(wave-5)*0.006) or (wave%5==0 and spawn_remaining==wave_size(wave))): kind="elite"
 if wave >= 14 and wave % 5 == 0 and spawn_remaining == 1: kind = "siege"
 if forced_kind!="": kind=forced_kind
 var spawn_wave:int=maxi(wave,boss_stage*10+1) if kind=="boss" else wave
 var growth := pow(1.06,minf(spawn_wave-1,600))
 var health := 50.0*growth
 var speed := 86.0+minf(34.0,spawn_wave*0.7)
 var damage := 12.0*growth
 if kind == "runner":
  health *= 0.65
  speed *= 1.55
 if kind == "brute":
  health *= 2.8
  speed *= 0.75
  damage *= 1.9
 if kind=="elite":
  health *= 5.5
  speed *= 0.85
  damage *= 2.0
 if kind == "siege":
  health *= 7.0
  speed *= 0.55
  damage *= 3.5
 if kind=="boss":
  var profile:=boss_profile(boss_stage,mission_boss)
  health *= 26.0*float(profile.hp)
  speed *= 0.62
  damage *= 4.5*float(profile.damage)
 var enemy:={"id":next_id,"kind":kind,"hp":health,"max_hp":health,"damage":damage,"speed":speed,"progress":initial_progress,"cooldown":0.5,"lane":float(rng.randi_range(0,8)*26-104)+rng.randf_range(-3,3),"phase":rng.randf()*TAU,"target":-1,"scan":0.0,"facing_left":false,"attacking":false,"attack_left":0.0,"boss_rank":maxi(1,boss_stage) if kind=="boss" else 0,"mission_boss":mission_boss and kind=="boss"}
 enemy.pos=path_point(initial_progress)+Vector2(0,enemy.lane)
 enemy.push=Vector2.ZERO
 enemy.aim=0.0
 enemy.smash_clock=0.0
 enemy.smash_left=0.0
 enemy.smash_center=Vector2.ZERO
 enemy.rallied=false
 var index:=enemies.size()
 if initial_progress>0:
  for i in enemies.size():
   if enemies[i].progress<initial_progress:
    index=i
    break
 enemies.insert(index,enemy)
 next_id += 1
 return enemy

func spawn_due_boss()->void:
 if enemies.size()>=MAX_ENEMIES: return
 # The final encounter is independent of old interval counters on migrated saves.
 if elapsed+0.00001>=FINAL_BOSS_TIME and final_boss_id==0 and not legacy_completion:
  var boss:=spawn_enemy(0.0,"boss",3,true)
  if not boss.is_empty():
   final_boss_id=int(boss.id)
   if boss_intervals==2: boss_intervals=3
   events.append({"type":"boss","pos":boss.pos,"text":"Final Warlord"})
  return
 var due:=int(floor((elapsed+0.00001)/BOSS_INTERVAL))
 if due<=boss_intervals: return
 var rank:=boss_intervals+1
 if rank==3:
  boss_intervals=3
  return
 var boss:=spawn_enemy(0.0,"boss",rank)
 if not boss.is_empty():
  boss_intervals=rank
  events.append({"type":"boss","pos":boss.pos,"text":"Warlord %d"%rank})

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
 var next_wave := int(elapsed/WAVE_SECONDS)+1
 if next_wave > wave:
  wave = next_wave
  begin_wave()
 spawn_due_boss()
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
  if b.hp <= 0 or b.age<build_time(b.kind): continue
  if regeneration_level>0: b.hp=minf(stat(b,"hp"),b.hp+stat(b,"hp")*regeneration_rate()*delta)
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
   var blast_radius := stat(b, "splash")
   for e in nearby_enemies(impact, blast_radius):
    if enemy_positions[e.id].distance_to(impact) <= blast_radius:
     e.hp -= damage
     provoke(e,i)
  else:
   target.hp -= damage
   provoke(target,i)
   for witness in nearby_enemies(impact,90):
    if witness.hp>0 and witness.pos.distance_to(impact)<90: provoke(witness,i)
  b.cooldown = stat(b,"period")
  events.append({"type":"shot","from":b.pos-Vector2(0,100),"pos":impact,"cannon":b.kind=="cannon"})
 Abilities.step_rain(self,delta)
 Abilities.apply_warcry(self)
 for e in enemies:
  if e.hp<=0: continue
  e.cooldown-=delta
  e.attack_left=maxf(0,float(e.get("attack_left",0.0))-delta)
  e.attacking=false
  if e.kind=="boss" and Abilities.step_smash(self,e,delta):continue
  var pos:Vector2=e.pos
  if not navigation.passable(pos):
   pos=navigation.nearest_open(pos)
   e.pos=pos
  var body:float=BODY_GAPS[e.kind]*0.5
  var walk_speed:float=e.speed*(Abilities.WARCRY_SPEED if e.rallied else 1.0)
  e.aim=float(e.get("aim",0.0))-delta
  var held:int=e.target
  var reach:float=220.0 if e.kind=="siege" else walk_speed*delta+10.0
  if e.aim>0 and held>=0 and held<buildings.size() and buildings[held]!=null and buildings[held].hp>0 and hit_rects[held].grow(body+reach).has_point(pos):
   attack_building(e,held)
   continue
  acquire_producer(e,pos,delta)
  var heading:Vector2=retaliation_direction(e,pos,delta)
  var adjacent:=adjacent_target(pos,body+18.0)
  if adjacent>=0 and (int(e.get("anger",-1))<0 or adjacent==int(e.anger)):
   e.target=adjacent
   e.aim=0.2
   attack_building(e,adjacent)
   continue
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
  var proposed:Vector2=pos+velocity*walk_speed*delta
  var walkable:bool=navigation.can_step(pos,proposed)
  if not walkable:
   proposed=pos+heading*walk_speed*delta
   walkable=navigation.can_step(pos,proposed)
   if not walkable:
    # Recenter inside the current open cell before taking a tight terrain turn.
    var recovery:Vector2=pos.direction_to(navigation.center(navigation.cell_of(pos)))
    proposed=pos+recovery*minf(walk_speed*delta,pos.distance_to(navigation.center(navigation.cell_of(pos))))
    walkable=navigation.can_step(pos,proposed)
  var lookahead:float=220.0 if e.kind=="siege" else walk_speed*delta+10.0
  var blocker:=first_blocker(pos,pos+heading*lookahead,body)
  if blocker<0: blocker=first_blocker(pos,proposed,body)
  e.target=blocker
  e.aim=0.2
  if blocker>=0:
   attack_building(e,blocker)
  elif walkable:
   var horizontal:float=proposed.x-pos.x
   if absf(horizontal)>0.1: e.facing_left=horizontal<0
   e.pos=proposed
   e.progress=minf(total_length,e.progress+pos.distance_to(proposed))
 for i in range(enemies.size()-1,-1,-1):
  var e: Dictionary = enemies[i]
  if e.hp <= 0:
   if bool(e.get("mission_boss",false)) and int(e.id)==final_boss_id: final_boss_defeated=true
   kills += 1
   var reward:float=60.0 if e.kind=="boss" else (14.0 if e.kind=="siege" else (8.0 if e.kind=="elite" else (5.0 if e.kind=="brute" else 3.0)))
   resources.gold = minf(1.0e15,resources.gold+reward)
   events.append({"type":"kill","gold":reward,"pos":enemy_position(e),"text":"","kind":e.kind,"phase":e.phase,"facing_left":bool(e.get("facing_left",false))})
   enemies.remove_at(i)
 if final_boss_defeated and not defeated and not victory:
  victory=true
  events.append({"type":"victory","text":"Final Warlord defeated"})
 if foundations_dirty:
  rebuild_building_grid()
  foundations_dirty=false
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
 var b:Dictionary=buildings[index]
 enemy.attacking=true
 var horizontal:float=b.pos.x-enemy.pos.x
 if absf(horizontal)>1.0: enemy.facing_left=horizontal<0
 if enemy.kind=="boss" and float(enemy.smash_left)>0:return
 if enemy.kind=="boss" and float(enemy.smash_clock)<=0:
  Abilities.begin_smash(enemy,b.pos)
  return
 if enemy.cooldown>0: return
 enemy.cooldown=1.15
 enemy.attack_left=ATTACK_ANIMATION_SECONDS
 damage_building(index,float(enemy.damage))

func damage_building(index:int,amount:float)->void:
 if index<0 or index>=buildings.size() or buildings[index]==null:return
 var b:Dictionary=buildings[index]
 b.hp=maxf(0,b.hp-amount)
 events.append({"type":"hit","pos":b.pos,"text":""})
 if b.hp<=0:
  b.ruined_at=elapsed
  events.append({"type":"ruin","pos":b.pos,"text":"Building destroyed","kind":b.kind})
  if index==0: defeated=true
  else:
   buildings[index]=null
   foundations_dirty=true

func wall_neighbors(index:int)->Dictionary:
 if index<0 or index>=buildings.size() or buildings[index]==null:return {}
 return wall_tile_neighbors(wall_tiles(buildings[index])[0]) if buildings[index].kind=="wall" else {}

func wall_tiles(building:Dictionary)->Array[Vector2]:
 var result:Array[Vector2]=[]
 var rect:=building_foundation(building)
 for y in int(rect.size.y/GRID_SIZE):
  for x in int(rect.size.x/GRID_SIZE):
   result.append(rect.position+(Vector2(x,y)+Vector2.ONE*0.5)*GRID_SIZE)
 return result

func wall_tile_neighbors(position:Vector2)->Dictionary:
 var result:Dictionary={}
 for offset in WALL_DIRECTIONS:
  var i:int=wall_at(position+Vector2(offset)*GRID_SIZE)
  if i>=0 and buildings[i]!=null and buildings[i].hp>0: result[offset]=i
 return result

func wall_line(start:Vector2,end:Vector2)->Array:
 var cursor:=snap_position(start,"wall")
 var destination:=snap_position(end,"wall")
 var result:Array=[cursor]
 # A whole-map stroke is still previewed so red cells can be skipped. The
 # transaction separately limits the number of new, green cells to 64.
 while cursor!=destination and result.size()<512:
  var diff:Vector2=destination-cursor
  if absf(diff.x)>=absf(diff.y): cursor.x+=signf(diff.x)*GRID_SIZE
  else: cursor.y+=signf(diff.y)*GRID_SIZE
  result.append(cursor)
 return result

func wall_at(position:Vector2)->int:
 var index:int=wall_cells.get(Vector2i((position/GRID_SIZE).floor()),-1)
 if index<0:return -1
 if buildings[index]!=null and buildings[index].hp>0 and building_foundation(buildings[index]).has_point(position):return index
 for other in nearby_buildings(position,80):
  var building=buildings[other]
  if building!=null and building.kind=="wall" and building.hp>0 and building_foundation(building).has_point(position):return other
 return -1

func wall_preview(points:Array)->Dictionary:
 var valid:Array=[]
 var skipped:Array=[]
 var seen:Dictionary={}
 var occupied:Dictionary={}
 for raw_point in points:
  var point:Vector2=snap_position(raw_point,"wall")
  if seen.has(point): continue
  seen[point]=true
  if wall_at(point)>=0: continue
  var allowed:bool=placement_error(point,"wall")==""
  var rect:=foundation_rect(point,"wall")
  var cells:Array[Vector2i]=[]
  for y in range(floori(rect.position.y/GRID_SIZE),ceili(rect.end.y/GRID_SIZE)):
   for x in range(floori(rect.position.x/GRID_SIZE),ceili(rect.end.x/GRID_SIZE)):
    var cell:=Vector2i(x,y)
    cells.append(cell)
    if occupied.has(cell): allowed=false
  if allowed:
   valid.append(point)
   for cell in cells: occupied[cell]=true
  else: skipped.append(point)
 var count:=valid.size()
 var error:=""
 if count==0: error="Drag over available ground to add wall sections."
 elif count>64: error="Build a shorter wall (maximum 64 new sections)."
 elif active_building_count()+count>MAX_BUILDINGS: error="The frontier supports up to 512 structures."
 var cost:Array=[]
 for value in DEFINITIONS.wall.cost: cost.append(value*count)
 if error=="" and not can_afford(cost): error="Not enough supplies for these wall sections."
 return {"count":count,"cost":cost,"error":error,"points":valid,"skipped":skipped}

func build_wall(points:Array)->String:
 var preview:=wall_preview(points)
 if preview.error!="": return preview.error
 var event_start:=events.size()
 for point in preview.points:
  var error:=build_at(point,"wall")
  if error!="": return error
 events.resize(event_start)
 events.append({"type":"build","pos":preview.points[preview.count/2],"text":"Wall · %d new sections"%preview.count})
 return ""

func snapshot() -> Dictionary:
 var saved_rains:Array=[]
 for rain in arrow_rains:
  var copy:Dictionary=rain.duplicate(true)
  copy.pos=[rain.pos.x,rain.pos.y]
  saved_rains.append(copy)
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
  copy.smash_center=[e.smash_center.x,e.smash_center.y]
  copy.erase("rallied")
  copy.erase("anger_path")
  copy.erase("anger_step")
  var push:Vector2=e.get("push",Vector2.ZERO)
  copy.push=[push.x,push.y]
  saved_enemies.append(copy)
 return {"settlement_age":settlement_age,"tower_tracks":tower_tracks.duplicate(),
 "rain_cooldown":rain_cooldown,"arrow_rains":saved_rains,"research_levels":research_levels.duplicate(),"regeneration_level":regeneration_level,"boss_intervals":boss_intervals,"final_boss_id":final_boss_id,"final_boss_defeated":final_boss_defeated,"legacy_completion":legacy_completion,"victory":victory,"version":SAVE_VERSION,"mountains_enabled":mountains_enabled,"terrain_revision":terrain_revision,"resources":resources.duplicate(true),"buildings":saved_buildings,"enemies":saved_enemies,"deposits":deposits.duplicate(),"elapsed":elapsed,"wave":wave,"kills":kills,"victory_seen":victory_seen,"spawn_remaining":spawn_remaining,"spawn_clock":spawn_clock,"next_id":next_id,"seed":seed_value,"rng_state":str(rng.state),"cleared_ground":cleared_ground.keys()}

static func restore(data: Dictionary):
 if not _number(data.get("version"),2,SAVE_VERSION) or float(data.version)!=floorf(data.version): return null
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
 if data.version>=11:
  if not _number(data.get("rain_cooldown"),0,maxf(0,Abilities.rain_recharge_seconds)+0.00001):return null
  if not data.get("arrow_rains") is Array or data.arrow_rains.size()>1:return null
  sim.rain_cooldown=float(data.rain_cooldown)
  for rain in data.arrow_rains:
   if not rain is Dictionary or not _number(rain.get("left"),0.000001,Abilities.RAIN_DURATION):return null
   if not _number(rain.get("pulses"),0,Abilities.RAIN_PULSES) or float(rain.pulses)!=floorf(rain.pulses):return null
   var expected:=mini(Abilities.RAIN_PULSES,int(floor((Abilities.RAIN_DURATION-float(rain.left)+0.00001)/Abilities.RAIN_PULSE_INTERVAL)))
   if int(rain.pulses)!=expected:return null
   if not _number(rain.get("damage"),0.001,Abilities.RAIN_PULSE_DAMAGE*pow(1.1,MAX_LEVEL-1)+0.01):return null
   var point=rain.get("pos")
   if not point is Array or point.size()!=2 or not _number(point[0],0,World.SIZE.x-0.00001) or not _number(point[1],0,World.SIZE.y-0.00001):return null
   var copy:Dictionary=rain.duplicate(true)
   copy.pos=Vector2(point[0],point[1])
   copy.pulses=int(rain.pulses)
   sim.arrow_rains.append(copy)
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
  var max_health:float=sim.stat(b,"hp") if data.version>=7 else float(DEFINITIONS[b.kind].hp)*pow(1.11,int(b.level)-1)
  # The hall and defense base health in previous versions used the old definitions.
  if data.version<7:
   var old_base:float={"hall":4200.0,"market":350.0,"wall":1250.0,"arrow":500.0}.get(b.kind,float(DEFINITIONS[b.kind].hp))
   max_health=old_base*pow(1.11,int(b.level)-1)
  if not _number(b.get("hp"),0,max_health+0.01): return null
  if not _number(b.get("cooldown"),-1e9,20) or not _number(b.get("age"),0,1e9): return null
  if not _number(b.get("ruined_at"),-1,1e9): return null
  var copy:Dictionary=b.duplicate(true)
  copy.pos=Vector2(b.pos[0],b.pos[1])
  copy.level=int(copy.level)
  if b.kind=="wall":
   var width=b.get("wall_size",80.0 if data.version<11 else null)
   if not _number(width,GRID_SIZE,80) or float(width) not in [GRID_SIZE,80.0]:return null
   copy.wall_size=float(width)
  if data.version<7:
   copy.hp=float(b.hp)/max_health
  if not _number(copy.get("repair_left",0.0),0,8.01) or not _number(copy.get("repair_rate",0.0),0,1e30): return null
  copy.repair_left=float(copy.get("repair_left",0.0))
  copy.repair_rate=float(copy.get("repair_rate",0.0))
  if data.version<8 and b.hp>0 and copy.repair_left>0:
   copy.hp=minf(1.0,copy.hp+copy.repair_rate*copy.repair_left/max_health) if data.version<7 else minf(max_health,copy.hp+copy.repair_rate*copy.repair_left)
  copy.erase("repair_left")
  copy.erase("repair_rate")
  restored.append(copy if i==0 or b.hp>0 else null)
 for e in data.enemies:
  if not e is Dictionary or e.get("kind","") not in ["raider","runner","brute","siege","elite","boss"]: return null
  for key in ["hp","max_hp","speed","damage","progress","id","cooldown","lane","phase"]:
   if not _number(e.get(key),-1e9,1e30): return null
  if e.hp<=0 or e.max_hp<=0 or e.hp>e.max_hp or e.speed<=0 or e.damage<=0: return null
  if e.progress<0 or e.progress>sim.total_length or absf(e.lane)>120: return null
  if not _number(e.get("target",-1),-1,511) or float(e.get("target",-1))!=floorf(e.get("target",-1)): return null
  if not _number(e.get("scan",0.0),-1,1): return null
  if data.version>=3:
   if not e.get("pos") is Array or e.pos.size()!=2: return null
   if not _number(e.pos[0],0,World.SIZE.x) or not _number(e.pos[1],0,World.SIZE.y): return null
 if data.version>=7:
  if not data.get("research_levels") is Dictionary or data.research_levels.size()!=DEFINITIONS.size(): return null
  for kind in DEFINITIONS:
   if not _number(data.research_levels.get(kind),1,MAX_LEVEL) or float(data.research_levels[kind])!=floorf(data.research_levels[kind]): return null
   sim.research_levels[kind]=int(data.research_levels[kind])
  if data.version==7 and not data.get("research_job") is Dictionary: return null
  if data.version==7 and not data.research_job.is_empty():
   var job:Dictionary=data.research_job
   if job.get("kind","") not in DEFINITIONS or not _number(job.get("level"),2,MAX_LEVEL): return null
   if float(job.level)!=floorf(job.level) or int(job.level)!=int(sim.research_levels[job.kind])+1: return null
   if not _number(job.get("duration"),1,10000) or not _number(job.get("remaining"),0,float(job.duration)): return null
   if not is_equal_approx(float(job.duration),35.0+(int(sim.research_levels[job.kind])-1)*8.0): return null
   sim.set_meta("legacy_paid_upgrade",job.duplicate())
  if data.version<9 and not _number(data.get("trade_clock"),0,8.01): return null
 else:
  for b in restored:
   if b!=null: sim.research_levels[b.kind]=maxi(int(sim.research_levels[b.kind]),int(b.level))
 for b in restored:
  if b==null: continue
  if data.version>=7 and (data.version<9 or b.kind not in LOCAL_UPGRADES) and int(b.level)!=int(sim.research_levels[b.kind]): return null
  if b.kind not in LOCAL_UPGRADES: b.level=int(sim.research_levels[b.kind])
  if data.version<7: b.hp=float(b.hp)*sim.stat(b,"hp")
 if data.version>=8:
  if not _number(data.get("regeneration_level"),0,MAX_LEVEL) or float(data.regeneration_level)!=floorf(data.regeneration_level): return null
  if not _number(data.get("boss_intervals"),0,int(floor((float(data.elapsed)+0.00001)/BOSS_INTERVAL))) or float(data.boss_intervals)!=floorf(data.boss_intervals): return null
  sim.regeneration_level=int(data.regeneration_level)
  sim.boss_intervals=int(data.boss_intervals)
 else: sim.boss_intervals=int(floor((float(data.elapsed)+0.00001)/BOSS_INTERVAL))
 sim.resources=data.resources.duplicate(true)
 sim.cleared_ground.clear()
 for cell in data.cleared_ground: sim.cleared_ground[int(cell)]=true
 sim.buildings=restored
 if data.version<4:
  # Older settlements keep the terrain on which their foundations were built.
  for b in sim.buildings:
   if b!=null and World.mountain_conflict(sim.building_foundation(b),1): sim.terrain_revision=0
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
  if not _number(e.get("anger",-1),-1,MAX_BUILDINGS-1) or float(e.get("anger",-1))!=floorf(e.get("anger",-1)): return null
  if not _number(e.get("anger_left",0.0),0,8): return null
  e.anger=int(e.get("anger",-1))
  e.anger_left=float(e.get("anger_left",0.0))
  e.anger_path=PackedVector2Array()
  e.anger_step=1
  e.producer_scan=0.0
  e.anger_source="producer" if e.anger>=0 and e.anger<restored.size() and restored[e.anger]!=null and DEFINITIONS[restored[e.anger].kind].has("income") else "defense"
  if data.version>=10:
   if not e.get("facing_left") is bool or not e.get("attacking") is bool or not e.get("mission_boss") is bool:return null
   if not _number(e.get("attack_left"),0,ATTACK_ANIMATION_SECONDS+0.00001):return null
   if not _number(e.get("boss_rank"),0,maxi(1,int(floor((float(data.elapsed)+0.00001)/BOSS_INTERVAL)))) or float(e.boss_rank)!=floorf(e.boss_rank):return null
   if e.kind!="boss" and (e.boss_rank!=0 or e.mission_boss):return null
   if e.kind=="boss" and e.boss_rank<1:return null
   e.boss_rank=int(e.boss_rank)
  else:
   e.facing_left=sim.navigation.direction(e.pos).x<0
   if e.target>=0 and e.target<restored.size() and restored[e.target]!=null:e.facing_left=restored[e.target].pos.x<e.pos.x
   e.attacking=false
   e.attack_left=0.0
   e.boss_rank=1 if e.kind=="boss" else 0
   e.mission_boss=false
  if data.version>=11:
   if not _number(e.get("smash_clock"),0,Abilities.SMASH_PERIOD+0.00001) or not _number(e.get("smash_left"),0,Abilities.SMASH_WINDUP+0.00001):return null
   var center=e.get("smash_center")
   if not center is Array or center.size()!=2 or not _number(center[0],0,World.SIZE.x) or not _number(center[1],0,World.SIZE.y):return null
   if e.kind!="boss" and (e.smash_clock>0 or e.smash_left>0):return null
   if e.smash_left>0 and (e.smash_clock<e.smash_left or not e.attacking):return null
   e.smash_center=Vector2(center[0],center[1])
  else:
   e.smash_clock=0.0
   e.smash_left=0.0
   e.smash_center=Vector2.ZERO
  e.rallied=false
 sim.deposits=data.deposits.duplicate()
 sim.elapsed=float(data.elapsed)
 sim.wave=int(data.wave)
 sim.kills=int(data.kills)
 sim.defeated=sim.buildings[0].hp<=0
 sim.victory_seen=data.victory_seen
 if data.version>=10:
  for key in ["victory","final_boss_defeated","legacy_completion"]:
   if not data.get(key) is bool:return null
  if not _number(data.get("final_boss_id"),0,int(data.next_id)-1) or float(data.final_boss_id)!=floorf(data.final_boss_id):return null
  sim.final_boss_id=int(data.final_boss_id)
  sim.final_boss_defeated=data.final_boss_defeated
  sim.legacy_completion=data.legacy_completion
  sim.victory=data.victory
  var alive_final:=0
  for enemy in sim.enemies:
   if enemy.mission_boss:
    if enemy.id!=sim.final_boss_id or enemy.boss_rank!=3:return null
    alive_final+=1
  if sim.final_boss_id==0 and (alive_final>0 or sim.final_boss_defeated):return null
  if sim.final_boss_id>0 and (alive_final!=(0 if sim.final_boss_defeated else 1)):return null
  if sim.elapsed+0.00001<FINAL_BOSS_TIME and (sim.final_boss_id>0 or sim.victory or sim.legacy_completion):return null
  if sim.victory and not (sim.final_boss_defeated or sim.legacy_completion):return null
  if sim.victory_seen and not sim.victory:return null
  if sim.legacy_completion and not sim.victory:return null
 else:
  sim.legacy_completion=sim.elapsed>=FINAL_BOSS_TIME and sim.victory_seen
  sim.victory=sim.legacy_completion
  sim.victory_seen=sim.legacy_completion
 sim.spawn_remaining=int(data.spawn_remaining)
 sim.spawn_clock=float(data.spawn_clock)
 sim.next_id=int(data.next_id)
 sim.rng.state=int(data.rng_state)
 if sim.has_meta("legacy_paid_upgrade"):
  var job:Dictionary=sim.get_meta("legacy_paid_upgrade")
  sim.apply_global_level(job.kind,int(job.level))
  sim.remove_meta("legacy_paid_upgrade")
 if data.version < 12:
  for kind in ["arrow", "cannon"]:
   sim.tower_tracks[kind + "_damage"] = int(sim.research_levels[kind])
 elif not sim.restore_age_research(data):
  return null
 sim.events.clear()
 sim.rebuild_building_grid()
 return sim

func restore_age_research(data: Dictionary) -> bool:
 var age_value = data.get("settlement_age")
 if not _number(age_value, 1, AGE_NAMES.size()) or float(age_value) != floorf(age_value):
  return false
 var ranks = data.get("tower_tracks")
 if not ranks is Dictionary or ranks.size() != TRACKS.size():
  return false
 for id in TRACKS:
  var track: Dictionary = TRACKS[id]
  var inherited := int(research_levels[track.kind]) if track.stat == "damage" else 1
  var limit := track_limit(int(age_value)) if int(age_value) >= track.unlock_age else 1
  var value = ranks.get(id)
  if not _number(value, inherited, maxi(inherited, limit)) or float(value) != floorf(value):
   return false
 settlement_age = int(age_value)
 for id in TRACKS:
  tower_tracks[id] = int(ranks[id])
 return true

static func _number(value, minimum: float, maximum: float) -> bool:
 return (value is float or value is int) and is_finite(float(value)) and value>=minimum and value<=maximum

func provoke(enemy:Dictionary,index:int)->void:
 if enemy.hp<=0 or index<0 or index>=buildings.size() or buildings[index]==null: return
 var held:int=enemy.get("anger",-1)
 if held>=0 and held<buildings.size() and buildings[held]!=null and buildings[held].hp>0 and float(enemy.get("anger_left",0.0))>0 and enemy.get("anger_source","")!="producer":
  enemy.anger_left=7.0
  return
 enemy.anger=index
 enemy.anger_source="defense"
 enemy.anger_left=7.0
 enemy.anger_path=PackedVector2Array()
 enemy.anger_step=1

func acquire_producer(enemy:Dictionary,pos:Vector2,delta:float)->void:
 enemy.producer_scan=maxf(0,float(enemy.get("producer_scan",0))-delta)
 var held:int=enemy.get("anger",-1)
 if held>=0 and held<buildings.size() and buildings[held]!=null and buildings[held].hp>0 and float(enemy.get("anger_left",0))>0: return
 if enemy.producer_scan>0: return
 enemy.producer_scan=1.0+fmod(float(enemy.id)*0.173,1.0)
 var candidates:Array=[]
 for index in producer_indices:
  var b=buildings[index]
  if b==null or b.hp<=0 or b.pos.distance_to(pos)>PRODUCER_AGGRO_RANGE: continue
  candidates.append({"index":index,"distance":pos.distance_squared_to(b.pos)})
 candidates.sort_custom(func(a,b):return a.distance<b.distance)
 for candidate in candidates:
  var index:int=candidate.index
  var choices:Array=producer_approaches.get(index,[]).duplicate()
  choices.sort_custom(func(a,b):return pos.distance_squared_to(a)<pos.distance_squared_to(b))
  for point in choices:
   var path:=retaliation_grid.get_point_path(navigation.cell_of(pos),navigation.cell_of(point))
   if path.is_empty(): continue
   var length:=0.0
   for i in range(1,path.size()):length+=path[i-1].distance_to(path[i])
   if length>maxf(1800,pos.distance_to(point)*2.5):continue
   enemy.anger=index
   enemy.anger_source="producer"
   enemy.anger_left=7.0
   enemy.anger_path=path
   enemy.anger_step=1
   return

func retaliation_direction(enemy:Dictionary,pos:Vector2,delta:float)->Vector2:
 var target:int=enemy.get("anger",-1)
 enemy.anger_left=maxf(0.0,float(enemy.get("anger_left",0.0))-delta)
 if target>=0 and target<buildings.size() and buildings[target]!=null and buildings[target].hp>0 and enemy.anger_left>0:
  var destination:Vector2=buildings[target].pos
  var producer:bool=DEFINITIONS[buildings[target].kind].has("income")
  if pos.distance_to(destination)<(PRODUCER_AGGRO_RANGE if producer else 850.0):
   var path:PackedVector2Array=enemy.get("anger_path",PackedVector2Array())
   if path.is_empty():
    if producer:
     var choices:Array=producer_approaches.get(target,[]).duplicate()
     choices.sort_custom(func(a,b):return pos.distance_squared_to(a)<pos.distance_squared_to(b))
     if not choices.is_empty(): destination=choices[0]
    var goal_cell:Vector2i=navigation.cell_of(destination)
    if retaliation_grid.is_point_solid(goal_cell): goal_cell=navigation.cell_of(navigation.nearest_open(destination))
    if retaliation_grid.is_point_solid(goal_cell):
     enemy.anger=-1
     return navigation.direction(pos)
    path=retaliation_grid.get_point_path(navigation.cell_of(pos),goal_cell)
    var length:=0.0
    for i in range(1,path.size()): length+=path[i-1].distance_to(path[i])
    if path.is_empty() or length>maxf(900,pos.distance_to(destination)*1.85):
     enemy.anger=-1
     return navigation.direction(pos)
    enemy.anger_path=path
    enemy.anger_step=1
   var cursor:int=int(enemy.get("anger_step",1))
   while cursor<path.size()-1 and pos.distance_to(path[cursor])<18: cursor+=1
   enemy.anger_step=cursor
   if cursor<path.size(): return pos.direction_to(path[cursor])
   return pos.direction_to(destination)
 enemy.anger=-1
 enemy.anger_path=PackedVector2Array()
 return navigation.direction(pos)

func adjacent_target(pos:Vector2,reach:float)->int:
 var best:=-1
 var nearest:=reach
 for index in nearby_buildings(pos,200):
  var b=buildings[index]
  if b==null or b.hp<=0: continue
  var rect:=building_foundation(b)
  var point:=pos.clamp(rect.position,rect.end)
  var distance:=pos.distance_to(point)
  if distance>=nearest: continue
  var own:=producer_deposit(b)
  var clear:=true
  var samples:=maxi(1,ceili(distance/10.0))
  for sample in range(1,samples+1):
   var q:=pos.lerp(point,float(sample)/samples)
   var value:=World.cell_terrain(World.cell_of(q),terrain_revision)
   if value>0 and value!=10+own:
    clear=false
    break
  if clear:
   nearest=distance
   best=index
 return best
