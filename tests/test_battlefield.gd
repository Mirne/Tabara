extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Art=preload("res://scripts/frontier_art.gd")
var checks:=0
var failures:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures+=1
  printerr("FAIL BATTLEFIELD: ",label)
func quiet():
 var sim=Sim.new(124)
 sim.resources={"wood":100000.0,"stone":100000.0,"gold":100000.0}
 sim.enemies.clear()
 sim.spawn_remaining=0
 sim.spawn_clock=30
 return sim
func restored(sim):return Sim.restore(JSON.parse_string(JSON.stringify(sim.snapshot())))
func run()->void:
 # One physical terrain cell, not a smaller graphic over the old 2x2 collision.
 var sim=quiet()
 check(sim.build_at(Vector2(6201,2801),"wall")=="","Single-cell wall constructs on open terrain")
 var wall:Dictionary=sim.buildings[1]
 check(wall.pos==Vector2(6220,2820) and sim.building_foundation(wall).size==Vector2(40,40),"Wall is centered in one visible grid cell")
 var occupied:=0
 for index in sim.foundation_cells.values():
  if index==1:occupied+=1
 check(occupied==1,"Wall collision occupies exactly one terrain cell")
 check(sim.build_at(Vector2(6260,2820),"wall")=="" and sim.wall_neighbors(1).has(Vector2i(1,0)),"Adjacent 1x1 walls share an exterior boundary")
 check(sim.build_at(Vector2(6220,2860),"wall")=="" and sim.wall_neighbors(1).has(Vector2i(0,1)),"Corner joins use cardinal single-cell neighbors")
 var copy=restored(sim)
 check(copy!=null and copy.building_foundation(copy.buildings[1])==sim.building_foundation(wall),"New wall footprint survives disk serialization")
 # Genuine older schema lacks footprint metadata; preserve the old foundation.
 var old:Dictionary=sim.snapshot()
 old.version=10
 old.buildings.resize(2)
 old.buildings[1].erase("wall_size")
 old.buildings[1].pos=[6200.0,2800.0]
 var migrated=Sim.restore(old)
 check(migrated!=null and migrated.building_foundation(migrated.buildings[1]).size==Vector2(80,80),"Version-ten walls keep their old physical footprint")
 check(migrated.resources==old.resources and migrated.buildings[1].hp==old.buildings[1].hp,"Wall migration neither spends supplies nor changes health")
 check(migrated.wall_tiles(migrated.buildings[1]).size()==4,"An old foundation renders as four merged tiles")
 check(migrated.build_at(Vector2(6260,2780),"wall")=="","New single cell meets an existing legacy wall")
 check(migrated.wall_tile_neighbors(Vector2(6220,2780)).has(Vector2i(1,0)),"Mixed-size walls merge at their shared edge")
 migrated.damage_building(1,1e9)
 migrated.step(0.05)
 check(not migrated.grid_blocked(Vector2i(155,69)) and migrated.wall_at(Vector2(6260,2780))==2,"Destroying an old wall opens its cells without removing its new neighbor")
 old=sim.snapshot()
 old.buildings[1].wall_size=60
 check(Sim.restore(old)==null,"Invalid intermediate wall footprints are rejected")
 # Smash winds up, damages a real area once, and retains the 3-second cycle.
 sim=quiet()
 for point in [Vector2(6220,2820),Vector2(6260,2820),Vector2(6500,2820)]:
  check(sim.build_at(point,"wall")=="","Smash fixture has a legal foundation")
 var boss:Dictionary=sim.spawn_enemy(0,"boss")
 boss.pos=Vector2(6160,2820)
 boss.damage=100.0
 boss.cooldown=0.0
 sim.attack_building(boss,1)
 check(boss.smash_left==0.6 and boss.smash_clock==3 and boss.attacking,"Contact starts the requested 3-second smash cycle")
 check(Art.attack_frame(boss)==0,"Pending smash displays the hammer wind-up")
 sim.attack_building(boss,1)
 check(sim.buildings[1].hp==2000,"Repeated contact during wind-up cannot deal an extra melee hit")
 sim.step(0.25)
 check(sim.buildings[2].hp==2000 and boss.smash_left>0,"Warning circle precedes area damage")
 copy=restored(sim)
 check(copy!=null and is_equal_approx(copy.enemies[0].smash_left,boss.smash_left),"Reload retains a partly completed warning")
 sim.step(0.4)
 copy.step(0.4)
 check(sim.buildings[1].hp==1800 and sim.buildings[2].hp==1800,"Smash damages the target and its neighboring wall")
 check(sim.buildings[3].hp==2000,"Smash respects the actual circle radius")
 check(copy.buildings[2].hp==sim.buildings[2].hp,"Restored smash resolves exactly once")
 var impacts:=0
 for event in sim.events:
  if event.type=="smash":impacts+=1
 check(impacts==1,"One warning produces one impact event")
 sim.step(3.0)
 impacts=0
 for event in sim.events:
  if event.type=="smash":impacts+=1
 check(impacts==2 and sim.buildings[2].hp==1600,"A surviving boss smashes again after three seconds")
 sim=quiet()
 sim.build_at(Vector2(6220,2820),"wall")
 boss=sim.spawn_enemy(0,"boss")
 boss.pos=Vector2(6160,2820)
 sim.attack_building(boss,1)
 boss.hp=0
 sim.step(0.8)
 check(sim.buildings[1].hp==2000,"Killing a winding-up boss cancels its smash")
 # The aura modifies movement only, never stored base stats or attack cadence.
 sim=quiet()
 boss=sim.spawn_enemy(0,"boss")
 boss.pos=Vector2(6400,2800)
 var ally:Dictionary=sim.spawn_enemy(0,"raider")
 ally.pos=Vector2(6200,2800)
 var base_speed:float=ally.speed
 var base_damage:float=ally.damage
 var start:Vector2=ally.pos
 sim.step(0.05)
 check(ally.rallied and absf(ally.pos.distance_to(start)-base_speed*1.3*0.05)<0.002,"Passive war cry continuously adds thirty percent movement speed")
 check(ally.speed==base_speed and ally.damage==base_damage,"War cry preserves ordinary base stats")
 var second:Dictionary=sim.spawn_enemy(0,"boss")
 second.pos=Vector2(6400,3000)
 start=ally.pos
 sim.step(0.05)
 check(absf(ally.pos.distance_to(start)-base_speed*1.3*0.05)<0.002,"Overlapping war cries do not stack")
 boss.hp=0
 second.hp=0
 start=ally.pos
 sim.step(0.05)
 check(not ally.rallied and is_equal_approx(ally.pos.distance_to(start),base_speed*0.05),"War cry ends immediately when its bosses die")
 sim=quiet()
 boss=sim.spawn_enemy(0,"boss")
 boss.pos=Vector2(6400,2800)
 ally=sim.spawn_enemy(0,"runner")
 ally.pos=Vector2(6800,2800)
 sim.step(0.05)
 check(not ally.rallied,"Enemies outside the aura keep normal movement")
 var bad:Dictionary=sim.snapshot()
 bad.enemies[0].smash_clock=3.1
 check(Sim.restore(bad)==null,"Corrupt smash cooldowns are rejected")
 bad=sim.snapshot()
 bad.enemies[0].smash_center=[-1,0]
 check(Sim.restore(bad)==null,"Out-of-map smash warnings are rejected")
 # Exercise the starting recharge and the alternative proposed tuning.
 var release_period:float=Sim.Abilities.rain_recharge_seconds
 for period in [60.0,90.0]:
  Sim.Abilities.rain_recharge_seconds=period
  sim=quiet()
  sim.build_at(Vector2(6220,2820),"wall")
  var inside:Dictionary=sim.spawn_enemy(0,"raider")
  inside.pos=Vector2(6180,2820)
  inside.hp=1000
  inside.max_hp=1000
  var outside:Dictionary=sim.spawn_enemy(0,"raider")
  outside.pos=Vector2(7000,2820)
  outside.hp=1000
  outside.max_hp=1000
  var stock:Dictionary=sim.resources.duplicate()
  check(sim.cast_rain(Vector2(-1,2820))!="" and sim.rain_ready(),"Invalid rain target does not consume its recharge")
  check(sim.cast_rain(Vector2(6200,2820))=="" and sim.rain_cooldown==period,"Confirmed rain starts the configured recharge")
  check(sim.resources==stock and sim.arrow_rains.size()==1,"Rain creates one barrage without charging resources")
  check(sim.cast_rain(Vector2(6300,2820))!="" and sim.arrow_rains.size()==1,"A second cast cannot bypass recharge")
  sim.step(0.4)
  check(inside.hp==1000,"Arrows fall before their first damage pulse")
  sim.step(0.15)
  check(inside.hp==950 and outside.hp==1000,"Only targets inside the circle take the first pulse")
  copy=restored(sim)
  check(copy!=null and copy.arrow_rains[0].pulses==1 and is_equal_approx(copy.rain_cooldown,sim.rain_cooldown),"Active barrage and recharge survive serialization")
  sim.apply_global_level("arrow",3)
  sim.step(2.5)
  copy.step(2.5)
  check(sim.enemies[0].hp==700 and sim.enemies[1].hp==1000,"Six pulses deal the captured cast damage and respect the circle")
  check(copy.enemies[0].hp==700 and copy.arrow_rains.is_empty(),"Reload neither repeats damage nor drops remaining pulses")
  check(is_equal_approx(sim.rain_damage(),363.0),"Future cast damage scales with existing Arrow tower research")
  sim.enemies.clear()
  sim.step(period)
  check(sim.rain_ready(),"Rain becomes available again after its game-time recharge")
 Sim.Abilities.rain_recharge_seconds=60
 sim=quiet()
 sim.cast_rain(Vector2(6200,2820))
 for i in 60:sim.step(0.05)
 check(sim.arrow_rains.is_empty() and restored(sim)!=null,"Saving on the exact barrage-end frame keeps a valid settlement")
 sim=quiet()
 var victim:Dictionary=sim.spawn_enemy(0,"raider")
 victim.pos=Vector2(6200,2820)
 victim.hp=1
 var gold:float=sim.resources.gold
 sim.cast_rain(victim.pos)
 sim.step(3.1)
 check(sim.kills==1 and absf(sim.resources.gold-gold-3.0-0.1*sim.elapsed)<0.01,"Rain kills pay ordinary gold exactly once")
 sim=quiet()
 sim.elapsed=900
 sim.wave=31
 sim.boss_intervals=3
 boss=sim.spawn_enemy(0,"boss",3,true)
 sim.final_boss_id=boss.id
 boss.pos=Vector2(6200,2820)
 boss.hp=1
 sim.cast_rain(boss.pos)
 sim.step(0.5)
 check(sim.victory and sim.final_boss_defeated and sim.buildings[0].hp>0,"Rain can kill the final Warlord and satisfy the same victory rule")
 bad=sim.snapshot()
 bad.rain_cooldown=61
 check(Sim.restore(bad)==null,"Invalid rain recharge is rejected")
 bad=sim.snapshot()
 bad.arrow_rains[0].pulses=6
 check(Sim.restore(bad)==null,"A tampered pulse count cannot skip or duplicate barrage damage")
 Sim.Abilities.rain_recharge_seconds=release_period
 print("BATTLEFIELD RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
