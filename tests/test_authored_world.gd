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
 for layout in 3:
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
  check(valid and count>15000,"Every cached route descends safely without corner cutting for layout %d"%layout)
  var original=Sim.new(43,layout)
  original.resources={"wood":400.0,"stone":300.0,"gold":200.0}
  original.step(7)
  var restored=Sim.restore(JSON.parse_string(JSON.stringify(original.snapshot(),"",true,true)))
  check(restored!=null and restored.terrain_revision==layout and restored.buildings[0].pos==Map.HALL and restored.enemies[0].pos.is_equal_approx(original.enemies[0].pos),"Version five roundtrip retains geography and units for layout %d"%layout)
  if layout<2:
   var old:Dictionary=original.snapshot()
   old.version=4
   old.erase("terrain_revision")
   var migrated=Sim.restore(JSON.parse_string(JSON.stringify(old,"",true,true)))
   check(migrated!=null and migrated.terrain_revision==layout and migrated.resources==original.resources and migrated.enemies[0].pos.is_equal_approx(original.enemies[0].pos),"Version four settlements retain original geography %d"%layout)
 var s=Sim.new(19)
 s.resources={"wood":1e8,"stone":1e8,"gold":1e8}
 check(s.terrain_revision==2,"New settlements use the authored basin")
 for node in s.resource_nodes:
  if node.kind in ["wood","stone"]:
   check(s.build_at(node.pos,node.kind)=="","Matching producer is buildable on resource site %s"%str(node.pos))
 var images:Dictionary={}
 for i in s.resource_nodes.size():
  var art:=Map.unique_resource(i)
  var key:="%d:%d"%[int(art.atlas),int(art.frame)]
  check(not images.has(key),"Resource site %d has its own atlas object"%i)
  images[key]=true
 check(Map.scenery().is_empty(),"The authored landscape does not scatter repeated decorative props")
 var ridges:Dictionary={}
 for ridge in Map.mountain_sprites(): ridges[ridge.id]=true
 check(ridges.size()==4 and Map.mountain_sprites().size()==4,"Four distinct mountain formations are each placed once")
 var landmarks:Dictionary={}
 var frames:Dictionary={}
 for item in Map.authored_landmarks():
  landmarks[item.id]=true
  frames[item.frame]=true
  var c:=Map.cell_of(item.footprint.get_center())
  check(Map.cell_terrain(c,2)>0 and not s.navigation.passable(Map.cell_center(c)),"Landmark %s has an impassable construction footprint"%item.id)
 check(landmarks.size()==6 and frames.size()==6,"Six different landmarks use six distinct atlas frames")
 var bad:Dictionary=s.snapshot()
 for value in [-1,3,1.5,"2",null]:
  bad.terrain_revision=value
  check(Sim.restore(bad)==null,"Malformed terrain revision is rejected: %s"%str(value))
 print("AUTHORED RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
