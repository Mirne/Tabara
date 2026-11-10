@static_unload
class_name RampartArt
extends RefCounted
## A continuous textured fortification, built from geometry instead of cropped wall images.
const STONE=preload("res://assets/world/wall-stone.png")
const WALK=preload("res://assets/world/wall-walk.png")
static var stone_surface:CanvasTexture
static var walk_surface:CanvasTexture
static func _static_init()->void:
 stone_surface=CanvasTexture.new()
 stone_surface.diffuse_texture=STONE
 stone_surface.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 stone_surface.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
 walk_surface=CanvasTexture.new()
 walk_surface.diffuse_texture=WALK
 walk_surface.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 walk_surface.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED

const HEIGHT:=56.0
const HALF:=28.0
const DIRECTIONS=[Vector2i(0,-2),Vector2i(2,0),Vector2i(0,2),Vector2i(-2,0)]

static func shade(tint:Color,factor:float)->Color:
 return Color(tint.r*factor,tint.g*factor,tint.b*factor,tint.a)

static func footprint(neighbors:Dictionary)->PackedVector2Array:
 var p:=PackedVector2Array([Vector2(-HALF,-HALF)])
 if neighbors.has(DIRECTIONS[0]): p.append_array(PackedVector2Array([Vector2(-HALF,-40),Vector2(HALF,-40)]))
 p.append(Vector2(HALF,-HALF))
 if neighbors.has(DIRECTIONS[1]): p.append_array(PackedVector2Array([Vector2(40,-HALF),Vector2(40,HALF)]))
 p.append(Vector2(HALF,HALF))
 if neighbors.has(DIRECTIONS[2]): p.append_array(PackedVector2Array([Vector2(HALF,40),Vector2(-HALF,40)]))
 p.append(Vector2(-HALF,HALF))
 if neighbors.has(DIRECTIONS[3]): p.append_array(PackedVector2Array([Vector2(-40,HALF),Vector2(-40,-HALF)]))
 return p

static func face(canvas:CanvasItem,a:Vector2,b:Vector2,lift:Vector2,tint:Color,origin:Vector2)->void:
 var delta:=b-a
 var horizontal:bool=absf(delta.x)>absf(delta.y)
 var ua:float=(a.x+origin.x)/192.0 if horizontal else (a.y+origin.y)/192.0
 var ub:float=(b.x+origin.x)/192.0 if horizontal else (b.y+origin.y)/192.0
 var uv:=PackedVector2Array([Vector2(ua,lift.length()/112.0),Vector2(ub,lift.length()/112.0),Vector2(ub,0),Vector2(ua,0)])
 canvas.draw_polygon(PackedVector2Array([a,b,b+lift,a+lift]),PackedColorArray([tint]),uv,stone_surface)

static func top(canvas:CanvasItem,points:PackedVector2Array,tint:Color,origin:Vector2,wood:bool)->void:
 var uv:=PackedVector2Array()
 for point in points: uv.append((point+origin)/Vector2(128,112))
 canvas.draw_polygon(points,PackedColorArray([tint]),uv,walk_surface if wood else stone_surface)

static func small_prism(canvas:CanvasItem,rect:Rect2,height:float,tint:Color,origin:Vector2)->void:
 var lift:=Vector2(-height*0.18,-height)
 var nw:=rect.position
 var ne:=Vector2(rect.end.x,rect.position.y)
 var se:=rect.end
 var sw:=Vector2(rect.position.x,rect.end.y)
 face(canvas,ne,se,lift,shade(tint,0.67),origin)
 face(canvas,se,sw,lift,shade(tint,0.94),origin)
 top(canvas,PackedVector2Array([nw+lift,ne+lift,se+lift,sw+lift]),shade(tint,1.12),origin,false)

static func piece(canvas:CanvasItem,position:Vector2,neighbors:Dictionary,tint:Color=Color.WHITE)->void:
 var links:Dictionary=neighbors.duplicate()
 if links.is_empty():
  links[DIRECTIONS[1]]=true
  links[DIRECTIONS[3]]=true
 var outline:=footprint(links)
 var lift:=Vector2(-10, -HEIGHT)
 canvas.draw_set_transform(position)
 for i in outline.size():
  var a:Vector2=outline[i]
  var b:Vector2=outline[(i+1)%outline.size()]
  var delta:=b-a
  var internal:bool=(is_equal_approx(a.x,40) and is_equal_approx(b.x,40) and neighbors.has(DIRECTIONS[1])) or (is_equal_approx(a.y,40) and is_equal_approx(b.y,40) and neighbors.has(DIRECTIONS[2]))
  if not internal and (delta.y>0 or delta.x<0): face(canvas,a,b,lift,shade(tint,0.7 if delta.y>0 else 0.94),position)
 var upper:=PackedVector2Array()
 for point in outline:upper.append(point+lift)
 top(canvas,upper,shade(tint,0.9),position,true)
 var horizontal:bool=links.has(DIRECTIONS[1]) or links.has(DIRECTIONS[3])
 var vertical:bool=links.has(DIRECTIONS[0]) or links.has(DIRECTIONS[2])
 # Continuous parapet rails and regular crenels align across the 80-unit lattice.
 if horizontal:
  for y in [-HALF,HALF-8]:
   small_prism(canvas,Rect2(Vector2(-40,y)+lift,Vector2(80,8)),8,tint,position)
   for x in [-25.0,15.0]: small_prism(canvas,Rect2(Vector2(x,y-2)+lift,Vector2(18,12)),19,shade(tint,0.98),position)
 if vertical:
  for x in [-HALF,HALF-8]:
   small_prism(canvas,Rect2(Vector2(x,-40)+lift,Vector2(8,80)),8,tint,position)
   for y in [-25.0,15.0]: small_prism(canvas,Rect2(Vector2(x-2,y)+lift,Vector2(12,18)),19,shade(tint,0.98),position)
 var junction:bool=neighbors.size()>=3 or (neighbors.size()==2 and horizontal and vertical)
 if junction:
  small_prism(canvas,Rect2(Vector2(-30,-30),Vector2(60,60)),HEIGHT+8,shade(tint,0.94),position)
  for offset in [Vector2(-30,-30),Vector2(12,-30),Vector2(-30,12),Vector2(12,12)]:
   small_prism(canvas,Rect2(offset+Vector2(-12,-HEIGHT-8),Vector2(18,18)),18,tint,position)
 elif neighbors.size()==1:
  var direction:=Vector2(neighbors.keys()[0]).normalized()
  var center:Vector2=-direction*23
  small_prism(canvas,Rect2(center-Vector2(25,25),Vector2(50,50)),HEIGHT+7,shade(tint,0.94),position)
  for offset in [Vector2(-25,-25),Vector2(9,-25),Vector2(-25,9),Vector2(9,9)]:
   small_prism(canvas,Rect2(center+offset+Vector2(-11,-HEIGHT-7),Vector2(16,16)),16,tint,position)
 canvas.draw_set_transform(Vector2.ZERO)

static func preview(canvas:CanvasItem,sim,points:Array,tint:Color)->void:
 var nodes:Dictionary={}
 for p in points: nodes[Vector2i((p/40.0).round())]=true
 for p in points:
  var neighbors:Dictionary={}
  var cell:=Vector2i((p/40.0).round())
  for direction in DIRECTIONS:
   var other:Vector2=Vector2(cell+direction)*40.0
   var existing:int=sim.wall_at(other)
   if nodes.has(cell+direction) or (existing>=0 and sim.buildings[existing].hp>0): neighbors[direction]=true
  piece(canvas,p,neighbors,tint)
