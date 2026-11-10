extends RefCounted
## Shared reverse Dijkstra field over terrain. Buildings are attacked, not avoided.
const Map=preload("res://scripts/world_data.gd")
const CELL:=Map.CELL
const WIDTH:=Map.GRID_WIDTH
const HEIGHT:=Map.GRID_HEIGHT
const STEPS=[Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1),Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]
var blocked:=PackedByteArray()
var costs:=PackedFloat32Array()
var following:=PackedInt32Array()
var sight:Dictionary={}
var goal:Vector2
var goal_cell:Vector2i
var heap:Array[Vector2]=[]
var loaded_baked:=false

func _init(destination:Vector2,layout:Variant=Map.AUTHORED_REVISION,use_baked:bool=true)->void:
 goal=destination
 goal_cell=cell_of(goal)
 blocked.resize(WIDTH*HEIGHT)
 costs.resize(WIDTH*HEIGHT)
 costs.fill(INF)
 following.resize(WIDTH*HEIGHT)
 following.fill(-1)
 var terrain:=Map.terrain_field(layout)
 for i in terrain.size(): blocked[i]=1 if terrain[i]>0 else 0
 blocked[index(goal_cell)]=0
 var signature:=JSON.stringify(Array(terrain)).sha256_text()
 var baked:Variant=Map.authored.get("navigation",{}).get(str(Map.revision(layout)))
 if use_baked and goal==Map.HALL and baked is Dictionary and baked.get("signature","")==signature:
  var links:Variant=baked.get("following")
  var weights:Variant=baked.get("costs")
  if links is Array and weights is Array and links.size()==WIDTH*HEIGHT and weights.size()==WIDTH*HEIGHT:
   loaded_baked=true
   following=PackedInt32Array(links)
   for i in weights.size(): costs[i]=INF if float(weights[i])<0 else float(weights[i])
   return
 costs[index(goal_cell)]=0
 push(Vector2(0,index(goal_cell)))
 while not heap.is_empty():
  var item:=pop()
  var current:=int(item.y)
  if item.x>costs[current]+0.01: continue
  var cell:=Vector2i(current%WIDTH,current/WIDTH)
  for move in STEPS:
   var next:Vector2i=cell+move
   if solid(next): continue
   if move.x!=0 and move.y!=0 and (solid(cell+Vector2i(move.x,0)) or solid(cell+Vector2i(0,move.y))): continue
   var n:=index(next)
   var distance:float=item.x+(CELL*1.41421356237 if move.x!=0 and move.y!=0 else CELL)
   if distance+0.01<costs[n]:
    costs[n]=distance
    following[n]=current
    push(Vector2(distance,n))

func cell_of(p:Vector2)->Vector2i:
 return Vector2i(clampi(floori(p.x/CELL),0,WIDTH-1),clampi(floori(p.y/CELL),0,HEIGHT-1))
func index(c:Vector2i)->int: return c.y*WIDTH+c.x
func center(c:Vector2i)->Vector2: return (Vector2(c)+Vector2.ONE*0.5)*CELL
func solid(c:Vector2i)->bool:
 return c.x<0 or c.y<0 or c.x>=WIDTH or c.y>=HEIGHT or blocked[index(c)]==1
func passable(p:Vector2)->bool:
 return not solid(Map.cell_of(p))

func sees_goal(c:Vector2i)->bool:
 var key:=index(c)
 if sight.has(key): return sight[key]
 var a:=center(c)
 var steps:=maxi(1,ceili(a.distance_to(goal)/28.0))
 var previous:=c
 for i in range(1,steps+1):
  var next:=cell_of(a.lerp(goal,float(i)/steps))
  if solid(next) or (next.x!=previous.x and next.y!=previous.y and (solid(Vector2i(next.x,previous.y)) or solid(Vector2i(previous.x,next.y)))):
   sight[key]=false
   return false
  previous=next
 sight[key]=true
 return true

func direction(p:Vector2)->Vector2:
 var c:=cell_of(p)
 if sees_goal(c): return p.direction_to(goal)
 var next:=following[index(c)]
 if next<0: return Vector2.ZERO
 return p.direction_to(center(Vector2i(next%WIDTH,next/WIDTH)))

func push(value:Vector2)->void:
 heap.append(value)
 var i:=heap.size()-1
 while i>0:
  var parent:=(i-1)/2
  if heap[parent].x<=value.x: break
  heap[i]=heap[parent]
  i=parent
 heap[i]=value
func pop()->Vector2:
 var result:=heap[0]
 var tail:Vector2=heap.pop_back()
 if heap.is_empty(): return result
 var i:=0
 while i*2+1<heap.size():
  var child:=i*2+1
  if child+1<heap.size() and heap[child+1].x<heap[child].x: child+=1
  if heap[child].x>=tail.x: break
  heap[i]=heap[child]
  i=child
 heap[i]=tail
 return result

func can_step(a:Vector2,b:Vector2)->bool:
 var previous:=Map.cell_of(a)
 var target:=Map.cell_of(b)
 if previous==target: return not solid(target)
 # A fixed simulation step crosses at most one cell edge. No sample loop needed.
 if absi(previous.x-target.x)<=1 and absi(previous.y-target.y)<=1:
  if solid(target): return false
  return previous.x==target.x or previous.y==target.y or not (solid(Vector2i(target.x,previous.y)) or solid(Vector2i(previous.x,target.y)))
 var samples:=maxi(1,ceili(a.distance_to(b)/10.0))
 for i in range(1,samples+1):
  var next:=Map.cell_of(a.lerp(b,float(i)/samples))
  if solid(next): return false
  if next.x!=previous.x and next.y!=previous.y and (solid(Vector2i(next.x,previous.y)) or solid(Vector2i(previous.x,next.y))): return false
  previous=next
 return true

func nearest_open(p:Vector2)->Vector2:
 if passable(p): return p
 var origin:=Map.cell_of(p)
 for radius in range(1,30):
  var best:=INF
  var result:=p
  for y in range(-radius,radius+1):
   for x in range(-radius,radius+1):
    if absi(x)!=radius and absi(y)!=radius: continue
    var c:=origin+Vector2i(x,y)
    if solid(c): continue
    var candidate:=center(c)
    if candidate.distance_squared_to(p)<best:
     result=candidate
     best=candidate.distance_squared_to(p)
  if best<INF: return result
 return p
