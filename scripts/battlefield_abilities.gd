@static_unload
class_name BattlefieldAbilities
extends RefCounted
## Combat rules stay in simulation time; rendering never deals damage.
const SMASH_PERIOD:=3.0
const SMASH_WINDUP:=0.6
const SMASH_RADIUS:=160.0
const SMASH_DAMAGE:=2.0
const WARCRY_RADIUS:=360.0
const WARCRY_SPEED:=1.3
const RAIN_RADIUS:=220.0
const RAIN_DURATION:=3.0
const RAIN_PULSES:=6
const RAIN_PULSE_INTERVAL:=0.45
const RAIN_PULSE_DAMAGE:=50.0
# Owner-confirmed recharge, measured in game seconds.
static var rain_recharge_seconds:float=60.0

static func step_rain(sim,delta:float)->void:
 sim.rain_cooldown=maxf(0,sim.rain_cooldown-delta)
 if sim.rain_cooldown<0.00001:sim.rain_cooldown=0.0
 for i in range(sim.arrow_rains.size()-1,-1,-1):
  var rain:Dictionary=sim.arrow_rains[i]
  rain.left=maxf(0,float(rain.left)-delta)
  if rain.left<0.00001:rain.left=0.0
  var age:float=RAIN_DURATION-rain.left
  while rain.pulses<RAIN_PULSES and age+0.00001>=(rain.pulses+1)*RAIN_PULSE_INTERVAL:
   for enemy in sim.nearby_enemies(rain.pos,RAIN_RADIUS):
    if enemy.hp>0 and enemy.pos.distance_squared_to(rain.pos)<=RAIN_RADIUS*RAIN_RADIUS:
     enemy.hp-=rain.damage
   rain.pulses+=1
  if rain.left<=0:sim.arrow_rains.remove_at(i)

static func apply_warcry(sim)->void:
 for enemy in sim.enemies:enemy.rallied=false
 for boss in sim.enemies:
  if boss.kind!="boss" or boss.hp<=0:continue
  for enemy in sim.nearby_enemies(boss.pos,WARCRY_RADIUS):
   if enemy.hp>0 and enemy.kind!="boss" and enemy.pos.distance_squared_to(boss.pos)<=WARCRY_RADIUS*WARCRY_RADIUS:
    enemy.rallied=true

static func begin_smash(enemy:Dictionary,position:Vector2)->void:
 enemy.smash_center=position
 enemy.smash_left=SMASH_WINDUP
 enemy.smash_clock=SMASH_PERIOD
 enemy.attack_left=0.0

static func step_smash(sim,enemy:Dictionary,delta:float)->bool:
 enemy.smash_clock=maxf(0,float(enemy.smash_clock)-delta)
 if enemy.smash_clock<0.00001:enemy.smash_clock=0.0
 if enemy.smash_left<=0:return false
 enemy.smash_left=maxf(0,float(enemy.smash_left)-delta)
 if enemy.smash_left<0.00001:enemy.smash_left=0.0
 enemy.attacking=true
 var horizontal:float=enemy.smash_center.x-enemy.pos.x
 if absf(horizontal)>1:enemy.facing_left=horizontal<0
 if enemy.smash_left<=0:
  var center:Vector2=enemy.smash_center
  for index in sim.nearby_buildings(center,SMASH_RADIUS+160):
   var building=sim.buildings[index]
   if building==null or building.hp<=0:continue
   var rect:Rect2=sim.building_foundation(building)
   if center.distance_to(center.clamp(rect.position,rect.end))<=SMASH_RADIUS:
    sim.damage_building(index,float(enemy.damage)*SMASH_DAMAGE)
  enemy.attack_left=sim.ATTACK_ANIMATION_SECONDS
  enemy.cooldown=maxf(float(enemy.cooldown),sim.ATTACK_ANIMATION_SECONDS)
  sim.events.append({"type":"smash","pos":center,"radius":SMASH_RADIUS,"text":""})
 return true
