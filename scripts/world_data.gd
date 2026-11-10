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

static func water_at(p: Vector2) -> bool:
 return ((p-LAKE_CENTER)/LAKE_RADIUS).length_squared()<1.0

static func rock_at(p: Vector2) -> bool:
 for c in CLIFFS:
  if ((p-c)/Vector2(370,210)).length_squared()<1.0: return true
 return false

static func terrain_error(p: Vector2, radius: float) -> String:
 if not Rect2(Vector2(100,100),SIZE-Vector2(200,200)).encloses(Rect2(p-Vector2.ONE*radius,Vector2.ONE*radius*2)):
  return "Stay inside the frontier boundary."
 for offset in [Vector2.ZERO,Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius)]:
  if water_at(p+offset): return "Build on dry ground."
  if rock_at(p+offset): return "This rocky ridge cannot support foundations."
 for c in GROVES:
  if p.distance_to(c)<105+radius: return "Choose a clearing beside the trees."
 for c in QUARRIES+ORES:
  if p.distance_to(c)<65+radius: return "Leave room around the resource deposit."
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

static func scenery() -> Array:
 var out: Array=[]
 var rng:=RandomNumberGenerator.new()
 rng.seed=42516
 for center in GROVES:
  for j in 58:
   var angle:=rng.randf()*TAU
   var radius:=sqrt(rng.randf())*430
   var p:Vector2=center+Vector2(cos(angle)*radius,sin(angle)*radius*0.72)
   if road_distance(p)<150 or water_at(p) or p.distance_to(HALL)<300: continue
   out.append({"pos":p,"art":rng.randi_range(0,2),"scale":rng.randf_range(0.8,1.35),"flip":rng.randf()<0.5})
 for center in QUARRIES+CLIFFS:
  for j in 10:
   var p:Vector2=center+Vector2(rng.randf_range(-180,180),rng.randf_range(-110,110))
   out.append({"pos":p,"art":4,"scale":rng.randf_range(0.65,1.6),"flip":rng.randf()<0.5})
 for j in 950:
  var p:=Vector2(rng.randf_range(80,SIZE.x-80),rng.randf_range(80,SIZE.y-80))
  if water_at(p) or road_distance(p)<90: continue
  out.append({"pos":p,"art":8 if j%3 else 11,"scale":rng.randf_range(0.3,0.65),"flip":rng.randf()<0.5})
 out.sort_custom(func(a,b):return a.pos.y<b.pos.y)
 return out
