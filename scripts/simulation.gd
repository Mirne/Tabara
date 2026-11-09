class_name Settlement
extends RefCounted
## Deterministic, presentation-independent mission simulation. All time is seconds.

const VICTORY_TIME := 900.0
const MAX_LEVEL := 100
const WAVE_SECONDS := 30.0
const SAVE_VERSION := 1
const RESOURCE_NAMES := ["wood", "stone", "gold"]
const PATH := [Vector2(55, 276), Vector2(222, 298), Vector2(369, 440), Vector2(647, 440), Vector2(807, 324), Vector2(1005, 302)]
const DEFINITIONS := {
 "hall": {"name":"Main hall", "tag":"THE HEART OF TABARA", "desc":"Your last line of defense. Fires arrows and provides a small steady income.", "cost":[0,0,0], "upgrade":[65,45,25], "hp":1600.0, "damage":24.0, "range":290.0, "period":1.1, "art":0},
 "wood": {"name":"Woodcutter", "tag":"WOOD PRODUCTION", "desc":"Harvests timber automatically. Build beside the pine grove for a 25% bonus.", "cost":[60,20,10], "upgrade":[50,25,15], "hp":300.0, "income":4.0, "resource":"wood", "art":1},
 "stone": {"name":"Stonemason", "tag":"STONE PRODUCTION", "desc":"Quarries stone automatically. Build beside the quarry for a 25% bonus.", "cost":[70,15,15], "upgrade":[45,40,15], "hp":380.0, "income":3.0, "resource":"stone", "art":2},
 "arrow": {"name":"Arrow tower", "tag":"FAST SINGLE TARGET", "desc":"Accurate, rapid arrows. Best against scouts and lone raiders.", "cost":[75,40,20], "upgrade":[55,35,20], "hp":500.0, "damage":16.0, "range":220.0, "period":0.85, "art":3},
 "wall": {"name":"Wall", "tag":"HOLD THE LINE", "desc":"Blocks enemies at a road checkpoint. Ruined walls stay in place for repair.", "cost":[25,65,10], "upgrade":[20,55,10], "hp":1250.0, "art":4},
 "cannon": {"name":"Cannon tower", "tag":"AREA DAMAGE", "desc":"Explosive shells damage every enemy in a 65m blast. Strong against groups.", "cost":[100,100,55], "upgrade":[65,75,35], "hp":650.0, "damage":52.0, "range":255.0, "period":2.7, "splash":65.0, "art":5},
 "market": {"name":"Marketplace", "tag":"GOLD & RESOURCE TRADE", "desc":"Generates gold automatically. Unlocks trading surplus timber or stone for gold.", "cost":[85,50,25], "upgrade":[55,40,25], "hp":350.0, "income":2.0, "resource":"gold", "art":6}
}
const PADS := [
 {"pos":Vector2(1005,302),"role":"hall"},
 {"pos":Vector2(335,242),"role":"forest"},
 {"pos":Vector2(817,217),"role":"quarry"},
 {"pos":Vector2(951,517),"role":"village"},
 {"pos":Vector2(425,342),"role":"defense"},
 {"pos":Vector2(664,342),"role":"defense"},
 {"pos":Vector2(808,450),"role":"defense"},
 {"pos":Vector2(532,539),"role":"village"},
 {"pos":Vector2(262,467),"role":"village"},
 {"pos":Vector2(470,440),"role":"gate"},
 {"pos":Vector2(892,314),"role":"gate"},
 {"pos":Vector2(1052,433),"role":"defense"},
 {"pos":Vector2(680,550),"role":"village"}
]
const DEPOSITS := [
 {"pos":Vector2(192,198),"kind":"wood","amount":20.0},
 {"pos":Vector2(721,180),"kind":"stone","amount":16.0},
 {"pos":Vector2(383,565),"kind":"gold","amount":12.0}
]
var resources := {"wood":240.0,"stone":180.0,"gold":110.0}
var buildings: Array = []
var enemies: Array = []
var events: Array = []
var deposits: Array = [0.0,0.0,0.0]
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
 buildings.resize(PADS.size())
 buildings.fill(null)
 buildings[0] = make_building("hall")
 begin_wave()
 spawn_enemy() # The road is hostile from the very first frame.
 spawn_remaining -= 1

func make_building(kind: String) -> Dictionary:
 return {"kind":kind,"level":1,"hp":float(DEFINITIONS[kind].hp),"cooldown":0.15,"age":0.0}

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

func build_at(index: int, kind: String) -> String:
 if defeated: return "The settlement has fallen. Start a new mission."
 if index <= 0 or index >= buildings.size() or buildings[index] != null: return "Choose an empty building plot."
 if not DEFINITIONS.has(kind) or kind == "hall": return "Choose a building from the build bar."
 if (PADS[index].role == "gate") != (kind == "wall"): return "Walls belong on road checkpoints." if kind == "wall" else "This checkpoint is reserved for a wall."
 if not spend(DEFINITIONS[kind].cost): return "Not enough resources. Gather supplies or grow your economy."
 buildings[index] = make_building(kind)
 events.append({"type":"build","pos":PADS[index].pos,"text":"Built!"})
 return ""

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
 events.append({"type":"build","pos":PADS[index].pos,"text":"Level %d" % b.level})
 return ""

func repair_at(index: int) -> String:
 if defeated: return "The hall has fallen. Start a new mission."
 if index < 0 or index >= buildings.size() or buildings[index] == null: return "Select a building."
 var b: Dictionary = buildings[index]
 if b.hp >= stat(b,"hp")-0.01: return "This building is already at full health."
 if not spend(repair_cost(b)): return "Not enough wood and stone to repair."
 b.hp = stat(b,"hp")
 b.cooldown = maxf(b.cooldown,0.5)
 events.append({"type":"build","pos":PADS[index].pos,"text":"Repaired"})
 return ""

func collect(index: int) -> bool:
 if defeated or index < 0 or index >= deposits.size() or deposits[index] > 0: return false
 var d: Dictionary = DEPOSITS[index]
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

func income_rates() -> Dictionary:
 var rates := {"wood":1.5,"stone":0.9,"gold":0.45}
 for i in buildings.size():
  var b = buildings[i]
  if b == null or b.hp <= 0: continue
  var d: Dictionary = DEFINITIONS[b.kind]
  if not d.has("income"): continue
  var bonus := 1.25 if (b.kind == "wood" and PADS[i].role == "forest") or (b.kind == "stone" and PADS[i].role == "quarry") else 1.0
  rates[d.resource] += stat(b,"income")*bonus
 return rates

func begin_wave() -> void:
 spawn_remaining = mini(36,3+int(wave/2.0))
 spawn_clock = 0.0
 events.append({"type":"wave","text":"Wave %d" % wave})

func spawn_enemy() -> void:
 var kind := "raider"
 var roll := rng.randf()
 if wave >= 4 and roll < 0.22: kind = "runner"
 if wave >= 7 and roll > 0.78: kind = "brute"
 if wave >= 14 and wave % 5 == 0 and spawn_remaining == 1: kind = "siege"
 var growth := pow(1.085,wave-1)
 var health := 38.0*growth
 var speed := 32.0+minf(14.0,wave*0.35)
 var damage := 10.0*pow(1.065,wave-1)
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
 enemies.append({"id":next_id,"kind":kind,"hp":health,"max_hp":health,"damage":damage,"speed":speed,"progress":0.0,"cooldown":0.5,"lane":rng.randf_range(-9,9),"phase":rng.randf()*TAU})
 next_id += 1

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
  spawn_clock += maxf(0.35,18.0/(3.0+wave/2.0))
 var rates := income_rates()
 for key in RESOURCE_NAMES: resources[key] = minf(1.0e15,resources[key]+rates[key]*delta)
 for i in deposits.size(): deposits[i] = maxf(0,deposits[i]-delta)
 for i in buildings.size():
  var b = buildings[i]
  if b == null: continue
  b.age += delta
  if b.hp <= 0: continue
  b.cooldown -= delta
  if b.cooldown > 0 or not DEFINITIONS[b.kind].has("damage"): continue
  var target = null
  var farthest := -1.0
  for e in enemies:
   if e.hp <= 0: continue
   if enemy_position(e).distance_to(PADS[i].pos) <= stat(b,"range") and e.progress > farthest:
    target = e
    farthest = e.progress
  if target == null: continue
  var impact := enemy_position(target)
  var damage := stat(b,"damage")
  if b.kind == "cannon":
   for e in enemies:
    if enemy_position(e).distance_to(impact) <= DEFINITIONS.cannon.splash: e.hp -= damage
  else: target.hp -= damage
  b.cooldown = stat(b,"period")
  events.append({"type":"shot","from":PADS[i].pos-Vector2(0,50),"pos":impact,"cannon":b.kind=="cannon"})
 for e in enemies:
  if e.hp <= 0: continue
  e.cooldown -= delta
  var pos := enemy_position(e)
  var target_index := -1
  # Siege engines can bombard the economy from the same road.
  var nearest := 215.0 if e.kind == "siege" else (95.0 if e.kind == "brute" else 72.0)
  for i in buildings.size():
   var b = buildings[i]
   if b == null or b.hp <= 0: continue
   var dist := pos.distance_to(PADS[i].pos)
   # Walls claim enemies first and cannot be bypassed while standing.
   if b.kind == "wall" and dist < 43.0:
    target_index = i
    break
   if b.kind != "wall" and dist < nearest:
    nearest = dist
    target_index = i
  if target_index >= 0:
   if e.cooldown <= 0:
    var b: Dictionary = buildings[target_index]
    b.hp = maxf(0,b.hp-e.damage)
    e.cooldown = 1.15
    events.append({"type":"hit","pos":PADS[target_index].pos,"text":""})
    if b.hp <= 0:
     events.append({"type":"ruin","pos":PADS[target_index].pos,"text":"Building ruined"})
     if target_index == 0: defeated = true
  else: e.progress = minf(total_length,e.progress+e.speed*delta)
 for i in range(enemies.size()-1,-1,-1):
  var e: Dictionary = enemies[i]
  if e.hp <= 0:
   kills += 1
   resources.gold += (3.0+wave*0.45)*(2.5 if e.kind == "siege" else 1.0)
   events.append({"type":"kill","pos":enemy_position(e),"text":""})
   enemies.remove_at(i)
 # Bound event memory even in non-visual simulations.
 if events.size() > 250: events = events.slice(-150)

func snapshot() -> Dictionary:
 return {"version":SAVE_VERSION,"resources":resources.duplicate(true),"buildings":buildings.duplicate(true),"enemies":enemies.duplicate(true),"deposits":deposits.duplicate(),"elapsed":elapsed,"wave":wave,"kills":kills,"defeated":defeated,"victory":victory,"victory_seen":victory_seen,"spawn_remaining":spawn_remaining,"spawn_clock":spawn_clock,"next_id":next_id,"seed":seed_value,"rng_state":str(rng.state)}

static func restore(data: Dictionary):
 # Validate the whole save before using any of it. Corrupt files never break the menu.
 if data.get("version",0) != SAVE_VERSION: return null
 if not data.get("buildings") is Array or data.buildings.size() != PADS.size(): return null
 if not data.get("enemies") is Array or data.enemies.size() > 5000: return null
 if not data.get("resources") is Dictionary: return null
 for key in RESOURCE_NAMES:
  if not _number(data.resources.get(key),0,1e15): return null
 if not _number(data.get("elapsed"),0,1e9): return null
 if not _number(data.get("wave"),1,40000000): return null
 for entry in [["seed",-2147483648,2147483647],["kills",0,1e12],["spawn_remaining",0,36],["spawn_clock",-1e9,10],["next_id",1,1e12]]:
  if not _number(data.get(entry[0]),entry[1],entry[2]): return null
 if not data.get("victory_seen") is bool: return null
 if not data.get("rng_state") is String or not data.rng_state.is_valid_int(): return null
 if int(data.wave) != int(float(data.elapsed)/WAVE_SECONDS)+1: return null
 if not data.get("deposits") is Array or data.deposits.size() != DEPOSITS.size(): return null
 for timer in data.deposits:
  if not _number(timer,0,12.01): return null
 var sim = load("res://scripts/simulation.gd").new(int(data.get("seed",2026)))
 for i in data.buildings.size():
  var b = data.buildings[i]
  if b == null:
   if i == 0: return null
   continue
  if not b is Dictionary or not DEFINITIONS.has(b.get("kind","")): return null
  if (i == 0) != (b.kind == "hall"): return null
  if i > 0 and ((PADS[i].role == "gate") != (b.kind == "wall")): return null
  if not _number(b.get("level"),1,100) or float(b.level) != floorf(b.level): return null
  if not _number(b.get("hp"),0,sim.stat(b,"hp")+0.01): return null
  if not _number(b.get("cooldown"),-1e9,20) or not _number(b.get("age"),0,1e9): return null
 for e in data.enemies:
  if not e is Dictionary or e.get("kind","") not in ["raider","runner","brute","siege"]: return null
  for key in ["hp","max_hp","speed","damage","progress","id","cooldown","lane","phase"]:
   if not _number(e.get(key),-1e9,1e30): return null
  if e.hp <= 0 or e.max_hp <= 0 or e.progress < 0 or e.progress > sim.total_length: return null
  if e.hp > e.max_hp or e.speed <= 0 or e.damage <= 0: return null
 sim.resources = data.resources.duplicate(true)
 sim.buildings = data.buildings.duplicate(true)
 for b in sim.buildings:
  if b != null: b.level = int(b.level)
 sim.enemies = data.enemies.duplicate(true)
 sim.deposits = data.deposits.duplicate()
 sim.elapsed = float(data.elapsed)
 sim.wave = int(data.wave)
 sim.kills = int(data.get("kills",0))
 sim.defeated = sim.buildings[0].hp <= 0
 sim.victory = sim.elapsed >= VICTORY_TIME
 sim.victory_seen = bool(data.get("victory_seen",false))
 sim.spawn_remaining = clampi(int(data.get("spawn_remaining",0)),0,36)
 sim.spawn_clock = float(data.spawn_clock)
 sim.next_id = maxi(1,int(data.get("next_id",1)))
 sim.rng.state = int(data.get("rng_state",str(sim.rng.state)))
 sim.events.clear()
 return sim

static func _number(value, minimum: float, maximum: float) -> bool:
 return (value is float or value is int) and is_finite(float(value)) and value >= minimum and value <= maximum
