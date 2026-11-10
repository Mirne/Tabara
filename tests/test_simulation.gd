extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Map=preload("res://scripts/world_data.gd")
const Bot=preload("res://tests/player_bot.gd")
var checks:=0
var failures:=0
func _init()->void:
 call_deferred("run")
func check(condition:bool,label:String)->void:
 checks+=1
 if not condition:
  failures+=1
  printerr("FAIL: ",label)
func rich():
 var s=Sim.new(5)
 s.resources={"wood":1e14,"stone":1e14,"gold":1e14}
 return s
func roundtrip(s):
 return Sim.restore(JSON.parse_string(JSON.stringify(s.snapshot(),"",true,true)))
func equivalent(a,b)->bool:
 if (a is float or a is int) and (b is float or b is int):
  return absf(float(a)-float(b))<=maxf(1e-8,maxf(absf(float(a)),absf(float(b)))*2e-15)
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size(): return false
  for key in a:
   if not b.has(key) or not equivalent(a[key],b[key]): return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size(): return false
  for i in a.size():
   if not equivalent(a[i],b[i]): return false
  return true
 return a==b
func run()->void:
 var s=Sim.new(17)
 check(Map.SIZE.x*Map.SIZE.y>50*1120*690,"Frontier is over fifty times the original area")
 check(s.buildings.size()==1 and s.buildings[0].kind=="hall","Only the main hall is prebuilt")
 check(s.enemies.size()==1 and s.enemies[0].progress==0,"Initial enemy starts at the path entrance")
 s.spawn_enemy(s.total_length-200)
 var first_hp:float=s.enemies[-1].hp
 s.step(0.2)
 check(s.kills>0 or s.enemies[-1].hp<first_hp,"Main hall fires immediately")
 check(s.build_at(Vector2(6101,3702),"arrow")=="","Free placement works far beyond the old plots")
 check(s.buildings[1].pos==Vector2(6120,3720),"Placement snaps to the visible forty-unit grid")
 var before:Dictionary=s.resources.duplicate()
 check(s.build_at(Vector2(6101,3702),"wall")!="" and s.resources==before,"Overlapping foundations are rejected without spending")
 check(s.build_at(Map.LAKE_CENTER,"wood")!="","Water placement is rejected")
 check(s.build_at(Map.CLIFFS[0],"wood")!="","Ridge placement is rejected")
 check(s.build_at(Vector2(10,10),"wall")!="","Map boundary is enforced")
 check(s.build_at(Map.GROVES[0],"arrow")!="","Resource groves retain access space")
 check(s.build_at(Vector2(6400,4000),"wall")=="","Walls can be built away from the road")
 check(s.buildings.size()==3,"Buildings are dynamic rather than fixed slots")
 check(s.vegetation_cleared(Vector2(6400,4000)),"Foundations create a persistent clearing")
 var rates:Dictionary=s.income_rates()
 var node:=0
 var timber:float=s.resources.wood
 check(s.collect(node) and s.resources.wood>timber,"Deposits yield real supplies")
 check(not s.collect(node),"Gather cooldown prevents repeated harvesting")
 s.step(12)
 check(s.collect(node),"Deposits replenish after twelve seconds")
 check(s.build_at(Vector2(7000,4000),"hall")!="","Only one main hall is allowed")
 check(not s.buy("stone") and not s.trade("wood"),"Trading requires a marketplace")
 var tiles=rich()
 check(tiles.build_at(Vector2(6400,4000),"wall")=="" and tiles.build_at(Vector2(6480,4000),"wall")=="","Adjacent wall foundations meet cleanly on the grid")
 var tile_stock:Dictionary=tiles.resources.duplicate()
 check(tiles.build_at(Vector2(6440,4000),"wall")!="" and tiles.resources==tile_stock,"Partly overlapping grid footprints spend nothing")
 var old_save=Sim.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/frontier-preview.json")))
 check(old_save!=null and old_save.buildings[1].pos==Vector2(4544,3264),"Existing v0.2 free-position settlements keep their progress")
 if old_save!=null:
  check(old_save.producer_deposit(old_save.buildings[1])==0 and old_save.build_at(Map.GROVES[0],"wood")!="","Existing producers reserve their nearby resource site")
 # Resource sites limit producers, retain their identity and survive clear/repair.
 var limited=rich()
 var deposit_count:int=limited.resource_nodes.size()
 check(limited.build_at(Vector2(6100,3700),"stone")!="","Stonemasons cannot be built on empty ground")
 check(limited.build_at(Map.QUARRIES[0],"wood")!="","A woodcutter requires a forest, not a quarry")
 check(limited.build_at(Map.QUARRIES[0],"stone")=="","Stonemason snaps onto its quarry")
 var stone_site:Vector2=limited.buildings[1].pos
 var paid:Dictionary=limited.resources.duplicate()
 check(limited.build_at(Map.QUARRIES[0]+Vector2(40,0),"stone")!="" and limited.resources==paid,"One producer per deposit; duplicate spends nothing")
 check(limited.resource_nodes.size()==deposit_count and limited.resource_nodes[Map.GROVES.size()].pos==Map.QUARRIES[0],"Construction never removes the resource node")
 limited.buildings[1].hp=0
 check(limited.build_at(stone_site,"stone")!="","A ruined producer still reserves its deposit")
 check(limited.repair_at(1)=="" and limited.deposit_owner(Map.GROVES.size())==1,"Repair preserves deposit ownership")
 limited.clear_at(1)
 check(limited.deposit_owner(Map.GROVES.size())==-1 and limited.build_at(Map.QUARRIES[0],"stone")=="","Clearing releases the same deposit for rebuilding")
 var legacy=roundtrip(limited)
 check(legacy!=null and legacy.deposit_owner(Map.GROVES.size())==1,"Deposit ownership survives the existing v2 save format")
 var reward_test=Sim.new(9)
 reward_test.spawn_remaining=0
 reward_test.enemies[0].hp=0
 var before_gold:float=reward_test.resources.gold
 reward_test.step(0.05)
 check(reward_test.kills==1 and reward_test.resources.gold>before_gold+3.99,"Each killed raider awards gold")
 var kill_events:Array=reward_test.events.filter(func(e):return e.type=="kill")
 check(kill_events.size()==1 and kill_events[0].gold==4,"Kill event carries its visible gold amount")
 before_gold=reward_test.resources.gold
 reward_test.step(0.05)
 check(reward_test.resources.gold-before_gold<1,"A removed enemy cannot pay gold twice")
 # A great horde must dispatch fully rather than being overwritten by the next wave.
 var horde=Sim.new(1)
 horde.elapsed=120.0
 horde.wave=5
 horde.enemies.clear()
 horde.begin_wave()
 var expected_horde:int=horde.spawn_remaining
 var first_horde_id:int=horde.next_id
 horde.step(23.0)
 check(horde.next_id-first_horde_id==expected_horde and horde.spawn_remaining==0,"Every doubled-horde attacker dispatches before the next wave")
 # Every structure reaches the same explicit cap, preserving injury percentage.
 for kind in Sim.DEFINITIONS:
  s=rich()
  var index:=0
  if kind!="hall":
   var site:Vector2=Map.GROVES[0] if kind=="wood" else (Map.QUARRIES[0] if kind=="stone" else Vector2(6100,3700))
   check(s.build_at(site,kind)=="","Construct "+kind)
   index=1
  var b:Dictionary=s.buildings[index]
  b.hp=s.stat(b,"hp")*0.4
  var previous_hp:float=s.stat(b,"hp")
  var previous_cost:float=s.upgrade_cost(b)[0]
  for level in range(2,101):
   check(s.upgrade_at(index)=="",kind+" upgrade "+str(level))
   check(b.level==level and s.stat(b,"hp")>previous_hp,kind+" health grows")
   check(absf(b.hp/s.stat(b,"hp")-0.4)<0.00001,kind+" upgrading preserves injury")
   check(s.upgrade_cost(b)[0]>=previous_cost,kind+" prices never decrease")
   previous_hp=s.stat(b,"hp")
   previous_cost=s.upgrade_cost(b)[0]
  check(s.upgrade_at(index)!="" and b.level==100,kind+" cannot exceed level 100")
  b.hp=0
  check(s.upgrade_at(index)!="",kind+" ruins must be repaired")
  check(s.repair_at(index)=="" and b.hp==s.stat(b,"hp") and b.level==100,kind+" ruins retain and restore upgrades")
  var saved=roundtrip(s)
  check(saved!=null and saved.buildings[index].level==100,kind+" level 100 survives JSON disk representation")
 s=rich()
 check(s.build_at(Map.GROVES[0],"wood")=="","Woodcutter occupies its forest deposit")
 check(s.production_bonus(s.buildings[1])==1.25,"Nearby forest production bonus")
 check(s.income_rates().wood==1.5,"Construction does not produce immediately")
 s.step(3)
 check(s.income_rates().wood>6.49,"Completed woodcutter produces income")
 s.buildings[1].hp=0
 check(s.income_rates().wood==1.5,"Ruined producers stop working")
 var clearing=s.cleared_ground.duplicate()
 check(s.clear_at(1)=="" and s.buildings[1]==null,"Ruins can be completely removed")
 check(s.cleared_ground==clearing,"Cleared trees do not regrow after demolition")
 check(s.build_at(Vector2(4544,3264),"market")=="","Other clear ground accepts a marketplace")
 check(s.buildings.size()==2,"Cleared storage slots are reused")
 s.step(3)
 var gold:float=s.resources.gold
 var stone:float=s.resources.stone
 check(s.buy("stone") and s.resources.stone==stone+60 and s.resources.gold==gold-60,"Marketplace purchase has exact price")
 var timber_before:float=s.resources.wood
 gold=s.resources.gold
 check(s.trade("wood") and s.resources.wood==timber_before-60 and s.resources.gold==gold+30,"Marketplace sale has exact proceeds")
 s.buildings[1].level=100
 gold=s.resources.gold
 s.buy("stone")
 s.trade("stone")
 check(s.resources.gold<gold,"Level 100 trading cannot create free gold")
 check(s.clear_at(0)!="","Main hall cannot be dismantled")
 # Unattended raiders physically ruin a structure, which remains repairable.
 s=rich()
 s.buildings[0].cooldown=10000
 s.enemies.clear()
 s.spawn_enemy(s.total_length-400)
 var p:Vector2=s.enemy_position(s.enemies[0])
 var candidate:=s.snap_position(p)
 check(s.build_at(candidate,"wall")=="","Wall may be placed directly across the current approach")
 var wall:Dictionary=s.buildings[1]
 wall.hp=1
 var progress:float=s.enemies[0].progress
 s.step(1.3)
 check(wall.hp==0 and wall.ruined_at>=0,"Enemies destroy buildings into ruins")
 check(s.enemies[0].progress>=progress,"Ruined walls release the approach")
 check(s.repair_at(1)=="" and wall.hp>0,"Enemy-created ruins can be repaired")
 # Body spacing prevents thousands of attackers occupying the same footprint.
 s=rich()
 s.enemies.clear()
 s.spawn_remaining=0
 var leader:Dictionary=s.spawn_enemy(1000)
 var follower:Dictionary=s.spawn_enemy(990)
 leader.lane=0
 follower.lane=0
 s.step(0.05)
 check(leader.progress-follower.progress>=29.99,"Crowds keep physical headway in their approach lane")
 # A removed target's reused index must not damage a new, distant structure.
 s=rich()
 s.enemies.clear()
 s.spawn_enemy(s.total_length-400)
 var enemy:Dictionary=s.enemies[0]
 check(s.build_at(s.enemy_position(enemy),"wall")=="","Build target for reused-index regression")
 enemy.target=1
 enemy.scan=0.2
 enemy.cooldown=-1
 s.clear_at(1)
 s.build_at(Vector2(6400,4000),"wall")
 var remote_hp:float=s.buildings[1].hp
 s.step(0.05)
 check(s.buildings[1].hp==remote_hp,"Cached attacks cannot hit a reused remote building index")
 # Save validation and deterministic continuation, including cleared vegetation.
 s=rich()
 s.build_at(Vector2(6100,3700),"arrow")
 s.step(25)
 var restored=roundtrip(s)
 check(restored!=null,"Full snapshot restores")
 check(restored!=null and restored.buildings[1].pos==s.buildings[1].pos,"World positions survive JSON")
 check(restored!=null and restored.cleared_ground==s.cleared_ground,"Vegetation clearings survive JSON")
 if restored!=null:
  s.step(3)
  restored.step(3)
  check(equivalent(s.snapshot(),restored.snapshot()),"JSON continuation matches within floating-point precision")
 var bad:Dictionary=s.snapshot()
 bad.buildings[1].pos=[-1,100]
 check(Sim.restore(bad)==null,"Invalid saved positions are rejected")
 bad=s.snapshot()
 bad.buildings[0].level=101
 check(Sim.restore(bad)==null,"Saved levels above cap are rejected")
 bad=s.snapshot()
 bad.resources.wood=-2
 check(Sim.restore(bad)==null,"Negative saved resources are rejected")
 bad=s.snapshot()
 bad.cleared_ground=[10240]
 check(Sim.restore(bad)==null,"Invalid clearing cells are rejected")
 check(Sim.restore({"version":1})==null,"Old fixed-plot save cannot corrupt new world")
 # Exact mission boundary and endless continuation.
 s=rich()
 s.elapsed=899.95
 s.wave=30
 s.enemies.clear()
 s.spawn_remaining=0
 s.step(0.1)
 check(s.victory and not s.defeated,"Victory triggers at fifteen in-game minutes")
 s.victory_seen=true
 s.step(35)
 check(s.elapsed>930 and s.wave>30,"Victory permits ongoing waves")
 s.buildings[0].hp=1
 s.buildings[0].cooldown=10000
 s.enemies.clear()
 s.spawn_enemy(s.total_length)
 s.enemies[0].lane=0
 s.step(2)
 check(s.defeated and s.buildings[0].hp==0,"Main hall destruction ends the run")
 var frozen:float=s.elapsed
 s.step(20)
 check(s.elapsed==frozen,"Defeated simulation stops")
 # One normal-cost campaign exercises the public placement/economy loop.
 s=Sim.new(11)
 var bot=Bot.new(s)
 for second in 1100:
  bot.act()
  s.step(1)
  s.events.clear()
  if second%30==0: await process_frame
  if s.defeated: break
 print("FRONTIER CAMPAIGN: ",s.elapsed,"s, wave ",s.wave,", ",s.kills," kills, ",s.active_building_count()," buildings")
 check(s.victory,"Normal-cost campaign reaches mission victory")
 print("RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures>0 else 0)
