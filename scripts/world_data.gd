@static_unload
class_name FrontierMap
extends RefCounted
## Immutable geography shared by simulation, terrain rendering, and minimap.
const SIZE := Vector2(8192,5120)
const HALL := Vector2(4800,2800)
const ROAD := [Vector2(256,2700),Vector2(1350,2700),Vector2(2200,1900),Vector2(3350,1900),Vector2(3950,2500),HALL]
const LAKE_CENTER := Vector2(6500,1600)
const LAKE_RADIUS := Vector2(950,520)
const GROVES := [Vector2(4380,3030),Vector2(5110,2420),Vector2(3390,2840),Vector2(2800,1400),Vector2(1650,3200),Vector2(900,1800),Vector2(5900,3450),Vector2(6900,3500),Vector2(7350,2200),Vector2(4100,1100),Vector2(5900,600),Vector2(2600,4100),Vector2(950,4350),Vector2(7450,4550)]
const QUARRIES := [Vector2(5150,3110),Vector2(3760,2080),Vector2(2100,3450),Vector2(6900,2600),Vector2(4550,650),Vector2(1150,950),Vector2(5950,4400),Vector2(7550,800)]
const ORES := [Vector2(4500,2390),Vector2(3080,3350),Vector2(1490,2200),Vector2(5750,3050),Vector2(7200,4050),Vector2(3500,730)]
const CLIFFS := [Vector2(1730,650),Vector2(4800,4300),Vector2(3600,4350)]

const CELL := 40.0
const GRID_WIDTH := 205
const GRID_HEIGHT := 128
# Two continuous spines meet the map edges, leaving a 480-unit mountain pass.
const MOUNTAIN_RECTS := [Rect2(3600,0,320,1440),Rect2(3680,1280,480,320),Rect2(4000,1440,240,1120),Rect2(4000,3040,240,2080)]
const AUTHORED_REVISION:=5
static var terrain_fields:Dictionary={}
static var authored:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/hearthvale.json"))
static var woodland:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/woodland.json"))
static var stronghold:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/stronghold.json"))
static var open_approach:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/open-approach.json"))
static var forest_shapes:Array=[]
static var forest_pockets:Array=[]
static var city_shape:=PackedVector2Array()
static var canopy_cells:Dictionary={}
static var water_cells:Dictionary={}
static var stronghold_infills:Array=[]

static func _static_init()->void:
 for key in authored.get("water_cells",[]): water_cells[int(key)]=true
 for item in woodland.regions:
  var shape:=PackedVector2Array()
  for pair in item.polygon: shape.append(Vector2(pair[0],pair[1]))
  forest_shapes.append(shape)
 for item in woodland.working_pockets:
  forest_pockets.append({"pos":Vector2(item.pos[0],item.pos[1]),"radius":float(item.radius)})
 for pair in woodland.city_clearing: city_shape.append(Vector2(pair[0],pair[1]))
 for key in woodland.get("forest_cells",[]): canopy_cells[int(key)]=true
 stronghold_infills=_make_forest_infills()

static func forest_regions()->Array:
 var result:Array=[]
 for item in woodland.regions:
  var a:Array=item.rect
  result.append({"id":item.id,"belt":item.belt,"texture":item.texture,"rect":Rect2(a[0],a[1],a[2],a[3])})
 return result

static func forest_at(p:Vector2)->bool:
 if Geometry2D.is_point_in_polygon(p,city_shape): return false
 var a:Array=woodland.protected_approach
 if Rect2(a[0],a[1],a[2],a[3]).has_point(p): return false
 for pocket in forest_pockets:
  if p.distance_squared_to(pocket.pos)<pocket.radius*pocket.radius: return false
 if not canopy_cells.is_empty():
  var c:=cell_of(p)
  return canopy_cells.has(c.y*GRID_WIDTH+c.x)
 for shape in forest_shapes:
  if Geometry2D.is_point_in_polygon(p,shape): return true
 return false

static func stronghold_forest_at(p:Vector2)->bool:
 if Geometry2D.is_point_in_polygon(p,city_shape): return false
 var a:Array=woodland.protected_approach
 if Rect2(a[0],a[1],a[2],a[3]).has_point(p): return false
 for item in stronghold_infills:
  if p.distance_squared_to(item.pos)<pow(item.size.x*0.4,2): return true
 var c:=cell_of(p)
 if canopy_cells.has(c.y*GRID_WIDTH+c.x): return true
 # Solid forest belts include their former isolated logging holes.
 for shape in forest_shapes:
  if Geometry2D.is_point_in_polygon(p,shape): return true
 return false

static func forest_infills()->Array:
 return stronghold_infills

static func _make_forest_infills()->Array:
 var result:Array=[]
 for pocket in forest_pockets:
  var p:Vector2=pocket.pos
  if Geometry2D.is_point_in_polygon(p,city_shape) or water_at(p,4) or mountain_at(p,4) or rock_at(p): continue
  var active:=false
  for node in resource_nodes(4):
   if node.pos.distance_to(p)<190: active=true
  if active: continue
  for shape in forest_shapes:
   if Geometry2D.is_point_in_polygon(p,shape):
    result.append({"pos":p,"size":Vector2.ONE*(pocket.radius*2+140)})
    break
 return result

static func revision(value:Variant)->int:
 if value is bool: return 1 if value else 0
 return clampi(int(value),0,AUTHORED_REVISION)

static func polygon(name:String)->PackedVector2Array:
 var result:=PackedVector2Array()
 for pair in authored[name]: result.append(Vector2(pair[0],pair[1]))
 return result

static func authored_landmarks()->Array:
 var result:Array=[]
 for item in authored.landmarks:
  result.append({"id":item.id,"frame":int(item.frame),"pos":Vector2(item.pos[0],item.pos[1]),"size":Vector2(item.size[0],item.size[1]),"footprint":Rect2(item.footprint[0],item.footprint[1],item.footprint[2],item.footprint[3])})
 return result

static func unique_resource(index:int,layout:int=AUTHORED_REVISION)->Dictionary:
 if layout>=4:
  return {"atlas":0,"frame":index%3 if index<4 else 3+(index-4)%3,"size":Vector2(220,185) if index<4 else Vector2(260,190)}
 var wood_count:int=GROVES.size()
 if index<wood_count: return {"atlas":0,"frame":index%3,"size":Vector2(245,225)}
 if index<wood_count+QUARRIES.size():
  var n:=index-wood_count
  return {"atlas":0,"frame":3+n%3,"size":Vector2(245,175)}
 return {"atlas":0,"frame":3+(index-wood_count-QUARRIES.size())%3,"size":Vector2(145,115)}

static func cell_of(p:Vector2)->Vector2i: return Vector2i(floori(p.x/CELL),floori(p.y/CELL))
static func cell_center(c:Vector2i)->Vector2: return (Vector2(c)+Vector2.ONE*0.5)*CELL
static func resource_rect(index:int,layout:int=AUTHORED_REVISION)->Rect2:
 var center:Vector2=resource_nodes(layout)[index].pos.snapped(Vector2.ONE*CELL)
 return Rect2(center-Vector2(80,80),Vector2(160,160))
static func mountain_at(p:Vector2,layout:Variant=AUTHORED_REVISION)->bool:
 if revision(layout)==0: return false
 if revision(layout)==1:
  for rect in MOUNTAIN_RECTS:
   if rect.has_point(p): return true
  return false
 return Geometry2D.is_point_in_polygon(p,polygon("north_polygon")) or Geometry2D.is_point_in_polygon(p,polygon("south_polygon"))

static func mountain_conflict(rect:Rect2,layout:Variant=AUTHORED_REVISION)->bool:
 if revision(layout)==0: return false
 if revision(layout)==1:
  for ridge in MOUNTAIN_RECTS:
   if ridge.intersects(rect): return true
  return false
 var box:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
 for name in ["north_polygon","south_polygon"]:
  if not Geometry2D.intersect_polygons(box,polygon(name)).is_empty(): return true
 return false

static func compute_field(layout:int)->PackedInt32Array:
 var field:=PackedInt32Array()
 field.resize(GRID_WIDTH*GRID_HEIGHT)
 var boundary:=Rect2(Vector2(100,100),SIZE-Vector2(200,200))
 var north:=polygon("north_polygon")
 var south:=polygon("south_polygon")
 var monuments:Array=authored_landmarks() if layout==2 else []
 for y in GRID_HEIGHT:
  for x in GRID_WIDTH:
   var c:=Vector2i(x,y)
   var rect:=Rect2(Vector2(c)*CELL,Vector2.ONE*CELL)
   var value:=0
   if not boundary.encloses(rect): value=1
   else:
    for offset in [Vector2.ZERO,Vector2(-19,-19),Vector2(19,-19),Vector2(-19,19),Vector2(19,19)]:
     var point:Vector2=cell_center(c)+offset
     if water_at(point,layout): value=2
     elif rock_at(point): value=3
     if layout>=2 and (Geometry2D.is_point_in_polygon(point,north) or Geometry2D.is_point_in_polygon(point,south)): value=4
     if layout==3 and value==0 and forest_at(point): value=6
     if layout>=4 and value==0 and stronghold_forest_at(point): value=6
    if layout==1:
     for ridge in MOUNTAIN_RECTS:
      if ridge.intersects(rect): value=4
    if layout==2 and value==0:
     for monument in monuments:
      if monument.footprint.intersects(rect): value=5
   field[y*GRID_WIDTH+x]=value
 if layout>=5:
  # The former eight edge-site foundations remain open after their resources
  # move away. In particular the old logging apron beside the pass can take walls.
  for i in resource_nodes(4).size():
   var old_rect:=resource_rect(i,4)
   for y in range(floori(old_rect.position.y/CELL),ceili(old_rect.end.y/CELL)):
    for x in range(floori(old_rect.position.x/CELL),ceili(old_rect.end.x/CELL)):
     var key:=y*GRID_WIDTH+x
     if key>=0 and key<field.size() and field[key]==6: field[key]=0
 var nodes:=resource_nodes(layout)
 for i in nodes.size():
  var rect:=resource_rect(i,layout)
  for y in range(floori(rect.position.y/CELL),ceili(rect.end.y/CELL)):
   for x in range(floori(rect.position.x/CELL),ceili(rect.end.x/CELL)):
    var key:=y*GRID_WIDTH+x
    if key>=0 and key<field.size() and field[key] in [0,6]: field[key]=10+i
 if layout>=4:
  # No foundations in inaccessible islands between tree crowns. Terrain and
  # movement use this same field, so a red cell always blocks both systems.
  var reached:Dictionary={}
  var first:=cell_of(HALL)
  var queue:Array[Vector2i]=[first]
  reached[first]=true
  var read:=0
  while read<queue.size():
   var c:Vector2i=queue[read]
   read+=1
   for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
    var next:Vector2i=c+offset
    if next.x<0 or next.y<0 or next.x>=GRID_WIDTH or next.y>=GRID_HEIGHT or reached.has(next): continue
    if field[next.y*GRID_WIDTH+next.x]!=0: continue
    reached[next]=true
    queue.append(next)
  for y in GRID_HEIGHT:
   for x in GRID_WIDTH:
    if field[y*GRID_WIDTH+x]==0 and not reached.has(Vector2i(x,y)): field[y*GRID_WIDTH+x]=7
 return field

static func terrain_field(layout:Variant=AUTHORED_REVISION)->PackedInt32Array:
 var rev:=revision(layout)
 if terrain_fields.has(rev): return terrain_fields[rev]
 var baked:Variant=authored.get("terrain_fields",{}).get(str(rev))
 var field:PackedInt32Array=PackedInt32Array(baked) if baked is Array and baked.size()==GRID_WIDTH*GRID_HEIGHT else compute_field(rev)
 terrain_fields[rev]=field
 return field

static func cell_terrain(c:Vector2i,layout:Variant=AUTHORED_REVISION)->int:
 if c.x<0 or c.y<0 or c.x>=GRID_WIDTH or c.y>=GRID_HEIGHT: return 1
 return terrain_field(layout)[c.y*GRID_WIDTH+c.x]

static func mountain_sprites()->Array:
 var result:Array=[]
 for item in authored.mountain_objects:
  var a:Array=item.rect
  result.append({"id":item.id,"rect":Rect2(a[0],a[1],a[2],a[3]),"pos":Vector2(a[0]+a[2]*0.5,a[1]+a[3]*0.8)})
 return result

static func legacy_mountain_sprites()->Array:
 var result:Array=[]
 for rect in MOUNTAIN_RECTS:
  for y in range(int(rect.position.y)+80,int(rect.end.y)+1,160):
   result.append({"pos":Vector2(rect.get_center().x,y),"size":Vector2(rect.size.x+60,260)})
 return result

static func water_at(p:Vector2,layout:Variant=AUTHORED_REVISION)->bool:
 if revision(layout)<2: return ((p-LAKE_CENTER)/LAKE_RADIUS).length_squared()<1.0
 if not water_cells.is_empty():
  var c:=cell_of(p)
  return water_cells.has(c.y*GRID_WIDTH+c.x)
 return Geometry2D.is_point_in_polygon(p,polygon("lake_polygon"))

static func rock_at(p: Vector2) -> bool:
 for c in CLIFFS:
  if ((p-c)/Vector2(370,210)).length_squared()<1.0: return true
 return false

static func terrain_error(p:Vector2,radius:float,own_deposit:int=-1,layout:Variant=AUTHORED_REVISION)->String:
 var rect:=Rect2(p-Vector2.ONE*radius,Vector2.ONE*radius*2)
 var reasons=["","Stay inside the frontier boundary.","Build on dry ground.","This rocky ridge cannot support foundations.","Mountains block this ground. Build walls across the pass.","This landmark occupies the ground.","Dense woodland blocks this ground. Use the clearings and timber sites.","This enclosed forest pocket is inaccessible. Build on connected open ground."]
 for y in range(floori(rect.position.y/CELL),ceili(rect.end.y/CELL)):
  for x in range(floori(rect.position.x/CELL),ceili(rect.end.x/CELL)):
   var value:=cell_terrain(Vector2i(x,y),layout)
   if value>=10:
    if value-10!=own_deposit: return "Leave this resource deposit clear, or build its matching producer on it."
   elif value>0: return reasons[value]
 return ""

static func road_distance(p: Vector2) -> float:
 var best := INF
 for i in ROAD.size()-1:
  best=minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,ROAD[i],ROAD[i+1])))
 return best

static func resource_nodes(layout:int=AUTHORED_REVISION) -> Array:
 var out: Array=[]
 if layout>=4:
  for item in (open_approach if layout>=5 else stronghold).nodes:
   out.append({"pos":Vector2(item.pos[0],item.pos[1]),"kind":item.kind,"zone":item.zone,"amount":float(item.amount)})
  return out
 for group in [[GROVES,"wood",36.0],[QUARRIES,"stone",30.0],[ORES,"gold",24.0]]:
  for p in group[0]: out.append({"pos":p,"kind":group[1],"amount":group[2]})
 return out

static func protected_resource_scenery(p: Vector2) -> bool:
 for center in GROVES:
  if center.distance_to(p)<180: return true
 return false

static func scenery()->Array:
 # Natural detail is painted into the authored floor. Every major object is placed once.
 return []
