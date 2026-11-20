extends RefCounted
## Defender used by paid campaigns and the real-time rendered soak. One order per second.
const Sim = preload("res://scripts/simulation.gd")
const PLAN = [
 [Vector2.ZERO,"wood"], [Vector2.ZERO,"stone"], [Vector2(4480,2760),"arrow"],
 [Vector2(4800,3280),"market"], [Vector2(4480,2880),"cannon"], [Vector2(5200,2800),"workshop"],
 [Vector2(4520,2720),"arrow"], [Vector2(4520,3040),"cannon"],
 [Vector2(4560,2600),"cannon"], [Vector2(4500,3120),"arrow"],
 [Vector2(4180,2580),"wall"], [Vector2(4180,2620),"wall"], [Vector2(4180,2660),"wall"],
 [Vector2(4180,2700),"wall"], [Vector2(4180,2740),"wall"], [Vector2(4180,2780),"wall"],
 [Vector2(4180,2820),"wall"], [Vector2(4180,2860),"wall"], [Vector2(4180,2900),"wall"],
 [Vector2(4180,2940),"wall"], [Vector2(4180,2980),"wall"], [Vector2(4180,3020),"wall"],
 [Vector2(4720,3056),"cannon"], [Vector2(4700,2520),"arrow"],
 [Vector2(4920,2520),"arrow"], [Vector2(4800,2560),"cannon"],
 [Vector2(4680,3240),"arrow"], [Vector2(4460,3280),"arrow"],
 [Vector2(5000,3120),"arrow"], [Vector2(5000,3280),"arrow"]
]
var sim
var next := 0
var sites: Dictionary = {}
var paid_orders := 0
var approach := "balanced"
var investment_slot := false
var project_cursor := 0
var rain_casts := 0
var age_seconds: Array = [0.0]

func _init(settlement, opening: String = "balanced") -> void:
 sim = settlement
 approach = opening
 var present := {}
 for b in sim.buildings:
  if b != null:
   present[b.kind] = present.get(b.kind,0)+1
 var needed := {}
 while next < PLAN.size():
  var kind: String = PLAN[next][1]
  needed[kind] = needed.get(kind,0)+1
  if present.get(kind,0) < needed[kind]:
   break
  next += 1

func planned_site(position: Vector2, kind: String) -> Vector2:
 if kind in ["wood","stone"]:
  for node in sim.resource_nodes:
   if node.kind == kind and sim.placement_error(node.pos,kind).is_empty():
    return node.pos
 var center: Vector2 = sim.snap_position(position,kind)
 if sim.placement_error(center,kind).is_empty():
  return center
 for ring in range(1,11):
  for y in range(-ring,ring+1):
   for x in range(-ring,ring+1):
    if absi(x) != ring and absi(y) != ring:
     continue
    var site: Vector2 = center+Vector2(x,y)*sim.GRID_SIZE
    if sim.placement_error(site,kind).is_empty():
     return site
 return center

func restore_destroyed() -> bool:
 for key in sites:
  var kind: String = PLAN[int(key)][1]
  var point: Vector2 = sites[key]
  var present := false
  for index in sim.nearby_buildings(point,2):
   var building = sim.buildings[index]
   if building != null and building.kind == kind and building.pos == point:
    present = true
    break
  if not present and sim.build_at(point,kind).is_empty():
   return true
 return false

func upgrade_local_kind(kind: String, goal: int) -> bool:
 for i in sim.buildings.size():
  var building = sim.buildings[i]
  if building != null and building.kind == kind and building.level < goal:
   return sim.upgrade_at(i).is_empty()
 return false

# A purchase waits for its actual quote. Giving every spare coin to the cheapest
# available action starves the higher-priced cannon projects indefinitely.
func investment_order() -> Array:
 if approach == "age_rush":
  return ["arrow_damage","wood","arrow_range","stone","arrow_cadence","regen"]
 if approach == "fortify":
  return ["cannon_damage","wood","cannon_splash","regen","stone","cannon_cadence","wall"]
 return ["wood","arrow_damage","stone","cannon_damage","regen","cannon_splash","arrow_cadence","wall"]

func invest() -> bool:
 if sim.workshop_index() < 0: return false
 var projects := investment_order()
 var limit := mini(sim.track_limit(),2+int(sim.elapsed/90))
 var economy := mini(8,2+int(sim.elapsed/100))
 for unused in projects.size():
  var project: String = projects[project_cursor % projects.size()]
  var bought := false
  var wanted := true
  if Sim.TRACKS.has(project):
   wanted = sim.track_level(project) < limit and sim.settlement_age >= Sim.TRACKS[project].unlock_age
   if wanted: bought = sim.research_track(project).is_empty()
  elif project == "regen":
   wanted = sim.regeneration_level < mini(5,1+int(sim.elapsed/220))
   if wanted: bought = sim.upgrade_regeneration().is_empty()
  elif project == "wall":
   wanted = sim.research_levels.wall < economy and sim.singleton_index("wall") >= 0
   if wanted: bought = sim.start_research("wall").is_empty()
  else:
   var index: int = sim.singleton_index(project)
   wanted = index >= 0 and sim.buildings[index].level < economy
   if wanted: bought = upgrade_local_kind(project,economy)
  if wanted and not bought: return false
  project_cursor += 1
  if bought: return true
 investment_slot = false
 return false

func build_next() -> bool:
 if next >= PLAN.size():
  return false
 var kind: String = PLAN[next][1]
 if not sim.can_afford(Sim.DEFINITIONS[kind].cost):
  return false
 var point := planned_site(PLAN[next][0], kind)
 if not sim.build_at(point,kind).is_empty():
  return false
 sites[next] = point
 next += 1
 return true

func extend_defenses() -> bool:
 if sim.active_building_count() >= 60:
  return false
 var kind := "cannon" if paid_orders % 3 == 0 else "arrow"
 if not sim.can_afford(Sim.DEFINITIONS[kind].cost):
  return false
 for x in range(4360,4841,80):
  for y in range(2440,3241,80):
   if sim.build_at(Vector2(x,y),kind).is_empty():
    return true
 return false

func aim_rain() -> bool:
 if not sim.rain_ready():
  return false
 var target
 var nearest := INF
 for enemy in sim.enemies:
  var distance: float = enemy.pos.distance_to(Sim.World.HALL)
  if distance < 1400 and enemy.kind == "boss":
   target = enemy
   break
  if distance < 900 and distance < nearest:
   target = enemy
   nearest = distance
 if target == null or (target.kind != "boss" and sim.nearby_enemies(target.pos,220).size() < 6):
  return false
 if not sim.cast_rain(target.pos).is_empty():
  return false
 rain_casts += 1
 return true

func act() -> void:
 if sim.defeated or aim_rain():
  return
 if restore_destroyed():
  paid_orders += 1
  return
 # Finish the opening economy, two tower types, and Workshop before competing
 # for their resources. Between new foundations, allow one investment.
 if next >= 6 and investment_slot:
  var interval: int = {"balanced":150,"fortify":235,"age_rush":75}[approach]
  var age_goal := mini(Sim.AGE_NAMES.size(),2+int(sim.elapsed/interval))
  if sim.settlement_age < age_goal:
   if sim.advance_age().is_empty():
    age_seconds.append(snappedf(sim.elapsed,0.05))
    paid_orders += 1
    investment_slot = false
   return
  if invest():
   paid_orders += 1
   investment_slot = false
   return
  if investment_slot: return
 if next < PLAN.size():
  if build_next():
   paid_orders += 1
   investment_slot = next >= 6
  return
 if invest() or extend_defenses():
  investment_slot = true
  paid_orders += 1
