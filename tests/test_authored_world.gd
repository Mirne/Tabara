extends SceneTree
## Offline bakes must agree with the authoritative terrain and shortest paths.
const Map=preload("res://scripts/world_data.gd")
const Nav=preload("res://scripts/assault_navigation.gd")
const Sim=preload("res://scripts/simulation.gd")
var checks:=0
var failures:=0
func _init()->void: call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures+=1
  printerr("FAIL AUTHORED: ",label)
func run()->void:
 for layout in range(Map.AUTHORED_REVISION+1):
  check(Map.terrain_field(layout)==Map.compute_field(layout),"Baked terrain exactly matches layout %d"%layout)
  var cached=Nav.new(Map.HALL,layout)
  var computed=Nav.new(Map.HALL,layout,false)
  check(cached.loaded_baked and not computed.loaded_baked,"Hall loads the offline route field for layout %d"%layout)
  check(cached.following==computed.following and cached.costs==computed.costs,"Baked paths equal a fresh shortest-path search for layout %d"%layout)
  var valid:=true
  var count:=0
  for i in cached.following.size():
   var next:int=cached.following[i]
   if next<0: continue
   count+=1
   if next>=cached.following.size() or cached.blocked[next]!=0 or cached.costs[next]>=cached.costs[i]:
    valid=false
    break
   var a:=Vector2i(i%Map.GRID_WIDTH,i/Map.GRID_WIDTH)
   var b:=Vector2i(next%Map.GRID_WIDTH,next/Map.GRID_WIDTH)
   if not cached.can_step(Map.cell_center(a),Map.cell_center(b)): valid=false
  check(valid and count>5000,"Every cached route descends safely without corner cutting for layout %d"%layout)
  var original=Sim.new(43,layout)
  original.resources={"wood":400.0,"stone":300.0,"gold":200.0}
  original.step(7)
  var restored=Sim.restore(JSON.parse_string(JSON.stringify(original.snapshot(),"",true,true)))
  check(restored!=null and restored.terrain_revision==layout and restored.buildings[0].pos==Map.HALL and restored.enemies[0].pos.is_equal_approx(original.enemies[0].pos),"Save roundtrip retains geography and units for layout %d"%layout)
  if layout<2:
   var old:Dictionary=original.snapshot()
   old.version=4
   old.erase("terrain_revision")
   var migrated=Sim.restore(JSON.parse_string(JSON.stringify(old,"",true,true)))
   check(migrated!=null and migrated.terrain_revision==layout and migrated.resources==original.resources and migrated.enemies[0].pos.is_equal_approx(original.enemies[0].pos),"Version four settlements retain original geography %d"%layout)
 var s=Sim.new(19)
 s.resources={"wood":1e8,"stone":1e8,"gold":1e8}
 check(s.terrain_revision==5,"New settlements use the connected woodland basin")
 for node in s.resource_nodes:
  if node.kind in ["wood","stone"]:
   check(s.build_at(node.pos,node.kind)=="","Matching producer is buildable on resource site %s"%str(node.pos))
 # Whole 160-unit foundations leave painted trails and the wall opening clear.
 for node in s.resource_nodes:
  var distance:=INF
  for trail in Map.authored.trails:
   for i in range(trail.size()-1):
    distance=minf(distance,node.pos.distance_to(Geometry2D.get_closest_point_to_segment(node.pos,Vector2(trail[i][0],trail[i][1]),Vector2(trail[i+1][0],trail[i+1][1]))))
  check(distance>=220,"Resource site is off all painted paths: "+str(node.pos))
  var pass_edge:=Vector2(clampf(node.pos.x,4080,4240),clampf(node.pos.y,2560,3040))
  check(node.pos.distance_to(pass_edge)>=300,"Resource site leaves the fortification opening clear")
 check(s.placement_error(Vector2(4400,3040),"wall")=="","The former near-pass logging foundation can now take walls")
 # Composition is reviewed as a landscape; tests protect the shared terrain rules.
 var trees:=0
 var open:=0
 var reachable:=0
 var canopy_solid:=true
 for i in Map.terrain_field(5).size():
  var kind:int=Map.terrain_field(5)[i]
  if kind==6:
   trees+=1
   if s.navigation.passable(Map.cell_center(Vector2i(i%Map.GRID_WIDTH,i/Map.GRID_WIDTH))): canopy_solid=false
  if kind==0:
   open+=1
   if is_finite(s.navigation.costs[i]): reachable+=1
 check(canopy_solid,"Every dense canopy cell blocks movement")
 check(float(trees)/Map.terrain_field(5).size()>0.35 and float(trees)/Map.terrain_field(5).size()<0.65,"Forest belts occupy a coherent substantial part of the basin")
 check(open>5000 and reachable==open,"The main connected meadow provides a broad playable basin")
 for point in [Vector2(1800,2700),Vector2(3900,2800),Vector2(4160,2800),Vector2(6100,2800),Vector2(6900,2900),Vector2(7600,1600)]:
  check(is_finite(s.navigation.costs[s.navigation.index(Map.cell_of(point))]),"Approach, pass, expansion meadow and eastern shore connect to the Hall: %s"%point)
 check(is_finite(s.navigation.costs[s.navigation.index(Map.cell_of(Map.ROAD[0]))]),"Western entry reaches the Hall through the mountain pass")
 check(Map.scenery().is_empty(),"New map does not scatter decorative specimens")
 for item in Map.authored_landmarks():
  var c:=Map.cell_of(item.footprint.get_center())
  check(Map.cell_terrain(c,2)==5,"Old landmark footprint stays in old saves")
 var previous:Dictionary=Sim.new(20,2).snapshot()
 previous.version=5
 previous.terrain_revision=2
 var preserved=Sim.restore(JSON.parse_string(JSON.stringify(previous,"",true,true)))
 check(preserved!=null and preserved.terrain_revision==2 and preserved.resources==previous.resources,"Version five settlements preserve their original terrain")
 var bad:Dictionary=s.snapshot()
 for value in [-1,6,1.5,"2",null]:
  bad.terrain_revision=value
  check(Sim.restore(bad)==null,"Malformed terrain revision is rejected: %s"%str(value))
 print("AUTHORED RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
