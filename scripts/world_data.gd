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
static var terrain_fields:Dictionary={}

static func cell_of(p:Vector2)->Vector2i: return Vector2i(floori(p.x/CELL),floori(p.y/CELL))
static func cell_center(c:Vector2i)->Vector2: return (Vector2(c)+Vector2.ONE*0.5)*CELL
static func resource_rect(index:int)->Rect2:
 var center:Vector2=resource_nodes()[index].pos.snapped(Vector2.ONE*CELL)
 return Rect2(center-Vector2(80,80),Vector2(160,160))
static func mountain_at(p:Vector2)->bool:
 for rect in MOUNTAIN_RECTS:
  if rect.has_point(p): return true
 return false
static func mountain_conflict(rect:Rect2)->bool:
 for ridge in MOUNTAIN_RECTS:
  if ridge.intersects(rect): return true
 return false

static func terrain_field(mountains_enabled:bool=true)->PackedInt32Array:
 if terrain_fields.has(mountains_enabled): return terrain_fields[mountains_enabled]
 var field:=PackedInt32Array()
 field.resize(GRID_WIDTH*GRID_HEIGHT)
 var boundary:=Rect2(Vector2(100,100),SIZE-Vector2(200,200))
 for y in GRID_HEIGHT:
  for x in GRID_WIDTH:
   var c:=Vector2i(x,y)
   var rect:=Rect2(Vector2(c)*CELL,Vector2.ONE*CELL)
   var value:=0
   if not boundary.encloses(rect): value=1
   elif mountains_enabled and mountain_conflict(rect): value=4
   else:
    for offset in [Vector2.ZERO,Vector2(-19,-19),Vector2(19,-19),Vector2(-19,19),Vector2(19,19)]:
     var point:Vector2=cell_center(c)+offset
     if water_at(point): value=2
     elif rock_at(point): value=3
   field[y*GRID_WIDTH+x]=value
 var nodes:=resource_nodes()
 for i in nodes.size():
  var rect:=resource_rect(i)
  for y in range(floori(rect.position.y/CELL),ceili(rect.end.y/CELL)):
   for x in range(floori(rect.position.x/CELL),ceili(rect.end.x/CELL)):
    var key:=y*GRID_WIDTH+x
    if key>=0 and key<field.size() and field[key]==0: field[key]=10+i
 terrain_fields[mountains_enabled]=field
 return field

static func cell_terrain(c:Vector2i,mountains_enabled:bool=true)->int:
 if c.x<0 or c.y<0 or c.x>=GRID_WIDTH or c.y>=GRID_HEIGHT: return 1
 return terrain_field(mountains_enabled)[c.y*GRID_WIDTH+c.x]

static func mountain_sprites()->Array:
 var out:Array=[]
 for rect in MOUNTAIN_RECTS:
  for y in range(int(rect.position.y)+80,int(rect.end.y)+1,160):
   out.append({"pos":Vector2(rect.get_center().x,y),"size":Vector2(rect.size.x+60,260)})
 return out

static func water_at(p: Vector2) -> bool:
 return ((p-LAKE_CENTER)/LAKE_RADIUS).length_squared()<1.0

static func rock_at(p: Vector2) -> bool:
 for c in CLIFFS:
  if ((p-c)/Vector2(370,210)).length_squared()<1.0: return true
 return false

static func terrain_error(p:Vector2,radius:float,own_deposit:int=-1,mountains_enabled:bool=true)->String:
 var rect:=Rect2(p-Vector2.ONE*radius,Vector2.ONE*radius*2)
 var reasons=["","Stay inside the frontier boundary.","Build on dry ground.","This rocky ridge cannot support foundations.","Mountains block this ground. Build walls across the pass."]
 for y in range(floori(rect.position.y/CELL),ceili(rect.end.y/CELL)):
  for x in range(floori(rect.position.x/CELL),ceili(rect.end.x/CELL)):
   var value:=cell_terrain(Vector2i(x,y),mountains_enabled)
   if value>=10:
    if value-10!=own_deposit: return "Leave this resource deposit clear, or build its matching producer on it."
   elif value>0: return reasons[value]
 return ""

static func road_distance(p: Vector2) -> float:
 var best := INF
 for i in ROAD.size()-1:
  best=minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,ROAD[i],ROAD[i+1])))
 return best

static func resource_nodes() -> Array:
 var out: Array=[]
 for group in [[GROVES,"wood",36.0],[QUARRIES,"stone",30.0],[ORES,"gold",24.0]]:
  for p in group[0]: out.append({"pos":p,"kind":group[1],"amount":group[2]})
 return out

static func protected_resource_scenery(p: Vector2) -> bool:
 for center in GROVES:
  if center.distance_to(p)<180: return true
 return false

static func scenery() -> Array:
 var out: Array=[]
 var rng:=RandomNumberGenerator.new()
 rng.seed=42516
 # Each forest/quarry is one compact authored resource image, not scattered copies.
 for center in CLIFFS:
  for j in 10:
   var p:Vector2=center+Vector2(rng.randf_range(-180,180),rng.randf_range(-110,110))
   out.append({"pos":p,"art":4,"scale":rng.randf_range(0.65,1.6),"flip":rng.randf()<0.5})
 for j in 950:
  var p:=Vector2(rng.randf_range(80,SIZE.x-80),rng.randf_range(80,SIZE.y-80))
  if water_at(p) or road_distance(p)<90: continue
  out.append({"pos":p,"art":8 if j%3 else 11,"scale":rng.randf_range(0.3,0.65),"flip":rng.randf()<0.5})
 out.sort_custom(func(a,b):return a.pos.y<b.pos.y)
 return out
