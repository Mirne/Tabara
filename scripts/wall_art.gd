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
const HALF:=40.0
const DIRECTIONS=[Vector2i(0,-2),Vector2i(2,0),Vector2i(0,2),Vector2i(-2,0)]

static func shade(tint:Color,factor:float)->Color:
 return Color(tint.r*factor,tint.g*factor,tint.b*factor,tint.a)

static func exposed_sides(neighbors:Dictionary)->PackedInt32Array:
 var out:=PackedInt32Array()
 for side in 4:
  if not neighbors.has(DIRECTIONS[side]): out.append(side)
 return out

static func footprint(_neighbors:Dictionary)->PackedVector2Array:
 return PackedVector2Array([Vector2(-40,-40),Vector2(40,-40),Vector2(40,40),Vector2(-40,40)])

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
 var outline:=footprint(neighbors)
 var lift:=Vector2(-10,-HEIGHT)
 canvas.draw_set_transform(position)
 # Every wall fills its full foundation. Only the outside of a joined mass has
 # vertical faces and parapets; interiors become one continuous raised deck.
 if not neighbors.has(DIRECTIONS[1]): face(canvas,outline[1],outline[2],lift,shade(tint,0.70),position)
 if not neighbors.has(DIRECTIONS[2]): face(canvas,outline[2],outline[3],lift,shade(tint,0.94),position)
 var upper:=PackedVector2Array()
 for point in outline: upper.append(point+lift)
 top(canvas,upper,shade(tint,0.94),position,true)
 var exposed:=exposed_sides(neighbors)
 for side in [0,3,1,2]:
  if not exposed.has(side): continue
  var horizontal:bool=side in [0,2]
  var edge:float=-40.0 if side in [0,3] else 32.0
  var rect:=Rect2(Vector2(-40,edge),Vector2(80,8)) if horizontal else Rect2(Vector2(edge,-40),Vector2(8,80))
  small_prism(canvas,Rect2(rect.position+lift,rect.size),9,tint,position)
  for step in [-26.0,14.0]:
   var block:=Rect2(Vector2(step,edge-2),Vector2(18,12)) if horizontal else Rect2(Vector2(edge-2,step),Vector2(12,18))
   small_prism(canvas,Rect2(block.position+lift,block.size),19,shade(tint,0.98),position)
 # Four outside corners for a 3x3 block, no towers at interior T/cross junctions.
 for corner in 4:
  var previous:int=(corner+3)%4
  if exposed.has(previous) and exposed.has(corner):
   var at:Vector2=outline[corner]+Vector2(0 if corner in [0,3] else -16,0 if corner in [0,1] else -16)
   small_prism(canvas,Rect2(at+lift,Vector2(16,16)),22,tint,position)
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
