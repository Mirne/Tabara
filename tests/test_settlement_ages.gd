extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const LEGACY_FIXTURE = "res://tests/fixtures/v012-paid-settlement.json"
var failures := 0
var checks := 0

func _init() -> void:
 call_deferred("run")

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  printerr("FAIL AGE: ", label)
  failures += 1

func funded():
 var sim = Sim.new(931)
 sim.resources = {"wood": 1e12, "stone": 1e12, "gold": 1e12}
 sim.enemies.clear()
 sim.spawn_remaining = 0
 sim.build_at(Vector2(5200,2800),"workshop")
 sim.step(7)
 return sim

func paid(before: Dictionary, after: Dictionary, cost: Array) -> bool:
 for i in Sim.RESOURCE_NAMES.size():
  var key: String = Sim.RESOURCE_NAMES[i]
  if not is_equal_approx(before[key] - after[key], cost[i]):
   return false
 return true

func upgrade_and_check(sim, id: String) -> void:
 var previous: Dictionary = sim.tower_tracks.duplicate()
 var before: Dictionary = sim.resources.duplicate()
 var cost: Array = sim.track_cost(id)
 var now: float = sim.track_value(id)
 var quoted: float = sim.track_value(id,true)
 check(sim.research_track(id).is_empty(), "Research purchased: "+id)
 check(paid(before,sim.resources,cost), "Only quoted resources spent: "+id)
 check(sim.track_level(id) == previous[id]+1 and sim.track_value(id) == quoted and quoted != now,
   "The purchased rank changes its promised value: "+id)
 previous[id] += 1
 check(sim.tower_tracks == previous, "Only the chosen specialization changes: "+id)

func check_progression() -> void:
 var sim = funded()
 check(sim.settlement_age == 1 and Sim.AGE_NAMES.size() == 8, "Wood is the first of eight ages")
 check(not sim.start_research("arrow").is_empty() and not sim.start_research("cannon").is_empty(),
   "A generic tower level cannot be bought alongside the new traits")
 for age in range(1, Sim.AGE_NAMES.size()+1):
  for id in Sim.TRACKS:
   if Sim.TRACKS[id].unlock_age > age:
    var before: Dictionary = sim.snapshot()
    check(not sim.research_track(id).is_empty() and sim.snapshot() == before, "Locked research is atomic: "+id)
    continue
   for rank in range(sim.track_level(id), sim.track_limit()):
    upgrade_and_check(sim,id)
   var cap_snapshot: Dictionary = sim.snapshot()
   check(not sim.research_track(id).is_empty() and cap_snapshot == sim.snapshot(), "The Hall gates ranks: "+id)
  var restored = Sim.restore(JSON.parse_string(JSON.stringify(sim.snapshot(),"",true,true)))
  check(restored != null and restored.settlement_age == age and restored.tower_tracks == sim.tower_tracks,
    "Age and every independently purchased specialization survive JSON at age "+str(age))
  if age < Sim.AGE_NAMES.size():
   var hall: Dictionary = sim.buildings[0].duplicate()
   var price: Array = sim.age_cost()
   var before: Dictionary = sim.resources.duplicate()
   check(sim.advance_age().is_empty() and sim.settlement_age == age+1, "Advance exactly one age")
   check(sim.buildings[0] == hall and paid(before,sim.resources,price), "Age costs the displayed resources and preserves the Hall")
 var completed: Dictionary = sim.snapshot()
 check(not sim.advance_age().is_empty() and completed == sim.snapshot(), "No age past Crown or further age charge")
 var broke = funded()
 broke.resources = {"wood":12.0,"stone":0.0,"gold":1000.0}
 var original: Dictionary = broke.snapshot()
 check(not broke.advance_age().is_empty() and not broke.research_track("arrow_damage").is_empty() and broke.snapshot() == original,
   "A failed multi-resource purchase never partially spends")
 for bad_age in [0,9,1.5,"Wood",null]:
  var corrupt: Dictionary = original.duplicate(true)
  corrupt.settlement_age = bad_age
  check(Sim.restore(corrupt) == null, "Invalid saved age rejected")
 for bad_track in [100,-1,0,2.5,"2",null]:
  var corrupt: Dictionary = original.duplicate(true)
  corrupt.tower_tracks.arrow_cadence = bad_track
  check(Sim.restore(corrupt) == null, "Invalid or age-locked saved rank rejected")

func check_migration() -> void:
 var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_FIXTURE))
 var migrated = Sim.restore(old)
 check(migrated != null, "Actual v0.12 snapshot loads")
 if migrated == null: return
 check(migrated.terrain_revision == 5 and migrated.resource_nodes.size() == 8 and migrated.settlement_age == 1,
   "Legacy settlement retains its eight resource sites and enters Wood")
 check(migrated.resources == old.resources and migrated.regeneration_level == old.regeneration_level,
   "Legacy economy and Regeneration survive migration")
 for i in old.buildings.size():
  var b: Dictionary = migrated.buildings[i]
  var previous: Dictionary = old.buildings[i]
  check(b.kind == previous.kind and b.pos == Vector2(previous.pos[0],previous.pos[1]) and b.level == previous.level and b.hp == previous.hp,
    "Paid building and exact foundation preserved: "+str(i))
  if b.kind in ["arrow","cannon"]:
   var def: Dictionary = Sim.DEFINITIONS[b.kind]
   check(migrated.track_level(b.kind+"_damage") == 2 and is_equal_approx(migrated.stat(b,"damage"),def.damage*1.1) and
    is_equal_approx(migrated.stat(b,"range"),def.range+0.8) and is_equal_approx(migrated.stat(b,"period"),def.period/1.007) and
    is_equal_approx(migrated.stat(b,"hp"),def.hp*1.085), "Old paid "+b.kind+" combat values are exactly preserved")
 # Previously purchased ranks above the introductory Wood limit remain owned.
 var veteran_save: Dictionary = old.duplicate(true)
 veteran_save.research_levels.arrow = 78
 for b in veteran_save.buildings:
  if b.kind == "arrow": b.level = 78
 var veteran = Sim.restore(veteran_save)
 check(veteran != null and veteran.track_level("arrow_damage") == 78 and veteran.track_limit() < 78,
   "Veteran Wood settlement retains purchased research above its current age limit")
 if veteran != null:
  var funds: Dictionary = veteran.resources.duplicate()
  check(veteran.required_track_age("arrow_damage") == Sim.AGE_NAMES.size(),
    "The Workshop quotes Crown as the first age that can advance a migrated rank 78")
  check(not veteran.research_track("arrow_damage").is_empty() and veteran.resources == funds and
    is_equal_approx(veteran.track_value("arrow_damage"),30.0*pow(1.1,77)), "Legacy grade preserves effective damage while an age lock costs nothing")
  var persisted = Sim.restore(veteran.snapshot())
  check(persisted != null and persisted.track_level("arrow_damage") == 78,"Migrated high grades round-trip at Wood")
 var old_income: Dictionary = migrated.income_rates()
 check(is_equal_approx(old_income.wood,0.8+5.0*(3+1.08)) and is_equal_approx(old_income.stone,0.45+6.25*(3+1.08)),
   "All eight existing producers keep their purchased income on load")
 var first_node: Dictionary = migrated.resource_nodes[0]
 migrated.clear_at(1)
 var before: Dictionary = migrated.snapshot()
 check(not migrated.build_at(first_node.pos,"wood").is_empty() and before == migrated.snapshot(),
   "A released legacy site cannot add a duplicate while another woodcutter survives")
 for index in [2,3,4]:
  migrated.clear_at(index)
 check(migrated.build_at(first_node.pos,"wood").is_empty(), "After its last legacy woodcutter falls the settlement can replace one")
 var modern = Sim.restore(migrated.snapshot())
 check(modern != null and modern.tower_tracks == migrated.tower_tracks and modern.resources == migrated.resources,
   "Migrated settlement can save and reload again without reapplied costs or upgrades")

func check_workyard_income(layout:int) -> void:
 var sim = Sim.new(14,layout)
 var wood_rates := [5.0,7.0,8.5,10.0,10.8]
 var stone_rates := [6.25,8.75,10.625,12.5,13.5]
 for node in sim.resource_nodes:
  check(sim.build_at(node.pos,node.kind).is_empty(), "Purchase the designated "+node.kind+" site from starting funds")
 for tick in 60: sim.step(0.05)
 for grade in wood_rates.size():
  var rates:Dictionary=sim.income_rates()
  check(is_equal_approx(rates.wood,0.8+wood_rates[grade]) and is_equal_approx(rates.stone,0.45+stone_rates[grade]),
    "Operating yards deliver the quoted wood and stone at level %d on layout %d"%[grade+1,layout])
  var before:Dictionary=sim.resources.duplicate()
  for tick in 200: sim.step(0.05)
  check(is_equal_approx(sim.resources.wood-before.wood,10.0*rates.wood) and is_equal_approx(sim.resources.stone-before.stone,10.0*rates.stone),
    "Ten game seconds credit the displayed income at level %d"%[grade+1])
  if grade+1==wood_rates.size(): break
  for kind in ["wood","stone"]:
   var index:int=sim.singleton_index(kind)
   var building:Dictionary=sim.buildings[index]
   var preview:Dictionary=building.duplicate()
   preview.level+=1
   var quote:float=sim.stat(preview,"income")*sim.production_bonus(preview)
   var expected:float=wood_rates[grade+1] if kind=="wood" else stone_rates[grade+1]
   check(is_equal_approx(quote,expected),"Local "+kind+" quote uses next level's actual site rate")
   var stock:Dictionary=sim.resources.duplicate()
   var price:Array=sim.upgrade_cost(building)
   check(sim.upgrade_at(index).is_empty() and paid(stock,sim.resources,price),"Purchase "+kind+" upgrade for its quoted price")
 var restored=Sim.restore(sim.snapshot())
 check(restored!=null and restored.income_rates()==sim.income_rates() and restored.resources==sim.resources,
   "Resuming a paid single-yard save keeps production and stored resources")
 for kind in ["wood","stone"]:
  var maxed:Dictionary=sim.buildings[sim.singleton_index(kind)].duplicate()
  maxed.level=Sim.MAX_LEVEL
  check(is_equal_approx(sim.stat(maxed,"income"),Sim.DEFINITIONS[kind].income*2*pow(1.08,96)),
    "Late "+kind+" levels compound from their fully developed working site")

func durable_enemy(sim, position: Vector2):
 var enemy: Dictionary = sim.spawn_enemy(0,"elite")
 enemy.pos = position
 enemy.hp = 10000.0
 enemy.max_hp = enemy.hp
 return enemy

func check_weapons() -> void:
 var sim = funded()
 sim.advance_age()
 sim.advance_age()
 var quoted_barrage:float = sim.rain_damage(true)
 for id in Sim.TRACKS:
  upgrade_and_check(sim,id)
 check(is_equal_approx(quoted_barrage,sim.rain_damage()), "The Arrowheads quote matches the damage dealt by the next barrage")
 check(sim.build_at(Vector2(6200,2800),"arrow").is_empty(), "Construct replacement arrow tower with purchased traits")
 var tower: Dictionary = sim.buildings[-1]
 tower.age = 10
 tower.cooldown = 0
 # Choose a distance that only the new bow limbs can reach. No Hall shot can reach either actor.
 var enemy: Dictionary = durable_enemy(sim,tower.pos+Vector2.RIGHT*(460+sim.stat(tower,"range"))/2)
 sim.step(0.05)
 check(is_equal_approx(10000.0-enemy.hp,sim.track_value("arrow_damage")) and is_equal_approx(tower.cooldown,sim.track_value("arrow_cadence")),
   "Actual arrow reaches the extended range, applies purchased damage, and resets the purchased cadence")
 check(is_equal_approx(sim.rain_damage(),330.0), "Buying bow reach or reload does not add extra Rain damage")
 sim.clear_at(sim.buildings.size()-1)
 sim.enemies.clear()
 check(sim.build_at(Vector2(6200,2800),"cannon").is_empty(), "Replacement cannon receives purchased traits")
 var cannon: Dictionary
 for b in sim.buildings:
  if b != null and b.kind == "cannon": cannon = b
 cannon.age = 10
 cannon.cooldown = 0
 var target := cannon.pos as Vector2 - Vector2(250,0)
 var primary: Dictionary = durable_enemy(sim,target)
 var secondary: Dictionary = durable_enemy(sim,target+Vector2.RIGHT*(140.0+sim.stat(cannon,"splash"))/2)
 var outside: Dictionary = durable_enemy(sim,target+Vector2.RIGHT*(sim.stat(cannon,"splash")+6))
 sim.step(0.05)
 check(is_equal_approx(10000.0-primary.hp,sim.track_value("cannon_damage")) and secondary.hp == primary.hp and outside.hp == 10000.0,
   "The new blast reaches a second enemy just beyond the old radius and spares one outside the new radius")
 check(is_equal_approx(cannon.cooldown,sim.track_value("cannon_cadence")), "Actual cannon reload reflects Workshop research")

func run() -> void:
 check_progression()
 check_migration()
 for layout in range(Sim.World.WORKYARD_REVISION,Sim.World.AUTHORED_REVISION+1):
  check_workyard_income(layout)
 check_weapons()
 print("AGE RESULT: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
