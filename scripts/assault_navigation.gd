extends RefCounted
## Shared reverse Dijkstra field over terrain. Buildings are attacked, not avoided.
const Map=preload("res://scripts/world_data.gd")
const CELL:=80.0
const WIDTH:=103
const HEIGHT:=64
const STEPS=[Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1),Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]
var blocked:=PackedByteArray()
var costs:=PackedFloat32Array()
var following:=PackedInt32Array()
var sight:Dictionary={}
var goal:Vector2
var goal_cell:Vector2i
var heap:Array[Vector2]=[]

func _init(destination:Vector2)->void:
 goal=destination
 goal_cell=cell_of(goal)
 blocked.resize(WIDTH*HEIGHT)
 costs.resize(WIDTH*HEIGHT)
 costs.fill(INF)
 following.resize(WIDTH*HEIGHT)
 following.fill(-1)
 for y in HEIGHT:
  for x in WIDTH:
   var p:=center(Vector2i(x,y))
   var solid:bool=p.x<60 or p.y<60 or p.x>Map.SIZE.x-60 or p.y>Map.SIZE.y-60
   for offset in [Vector2.ZERO,Vector2(24,0),Vector2(-24,0),Vector2(0,24),Vector2(0,-24)]:
    if Map.water_at(p+offset) or Map.rock_at(p+offset): solid=true
   blocked[y*WIDTH+x]=1 if solid else 0
 blocked[index(goal_cell)]=0
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
   var distance:float=item.x+(113.137085 if move.x!=0 and move.y!=0 else CELL)
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
 return p.x>=30 and p.y>=30 and p.x<Map.SIZE.x-30 and p.y<Map.SIZE.y-30 and not solid(cell_of(p))

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
