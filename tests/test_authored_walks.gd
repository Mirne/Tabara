extends SceneTree
## Actual movement from a stratified set of basin origins. This is a routing
## fixture, not balance: hall fire and additional wave spawns are suppressed.
const Sim=preload("res://scripts/simulation.gd")
const Map=preload("res://scripts/world_data.gd")
var failures:=0
var traces:=0
var samples:=0
var longest:=0.0
func _init()->void:call_deferred("run")
func run()->void:
 var started:=Time.get_ticks_msec()
 var results:Array=[]
 for y in range(400,5000,800):
  for x in range(400,8100,1000):
   var sim=Sim.new(80+traces)
   sim.enemies.clear()
   sim.buildings[0].cooldown=1e9
   var origin:Vector2=sim.navigation.nearest_open(Vector2(x,y))
   if not is_finite(sim.navigation.costs[sim.navigation.index(sim.navigation.cell_of(origin))]):continue
   var enemy:Dictionary=sim.spawn_enemy()
   enemy.pos=origin
   enemy.speed=160.0
   enemy.hp=1e8
   enemy.max_hp=1e8
   enemy.damage=0.001
   enemy.lane=0.0
   var stayed_open:=true
   var arrived:=false
   for tick in 4000:
    sim.spawn_remaining=0
    sim.wave=int((sim.elapsed+0.05)/sim.WAVE_SECONDS)+1
    sim.step(0.05)
    samples+=1
    if not sim.navigation.passable(enemy.pos):stayed_open=false
    if enemy.target==0:
     arrived=true
     break
    if tick%200==0:await process_frame
   traces+=1
   longest=maxf(longest,sim.elapsed)
   if not stayed_open or not arrived:
    failures+=1
    printerr("FAIL WALK: origin ",origin," position ",enemy.pos," arrived ",arrived," stayed open ",stayed_open)
   results.append({"origin":[origin.x,origin.y],"arrived":arrived,"stayed_open":stayed_open,"seconds":sim.elapsed})
 var data:={"traces":traces,"position_samples":samples,"failures":failures,"longest_game_seconds":longest,"actual_seconds":(Time.get_ticks_msec()-started)/1000.0,"fixture":"One durable raider per stratified origin, hall fire and wave spawns suppressed; actual fixed-step movement","results":results}
 var file:=FileAccess.open("res://test-results/authored-walks.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(data,"  "))
 file.close()
 print("AUTHORED WALKS RESULT: ",traces," traces, ",samples," positions, ",failures," failures")
 quit(1 if failures else 0)
