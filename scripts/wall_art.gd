@static_unload
class_name RampartArt
extends RefCounted
## A continuous textured fortification, built from geometry instead of cropped wall images.
const STONE=preload("res://assets/world/wall-stone.png")
const WALK=preload("res://assets/world/wall-walk.png")
const AGE_MATERIALS = ["wood", "stone", "iron", "steel", "keep", "castle", "citadel", "crown"]
const AGE_HEIGHTS = [36.0, 41.0, 44.0, 47.0, 50.0, 52.0, 56.0, 58.0]
static var stone_surface:CanvasTexture
static var walk_surface:CanvasTexture
static var age_surfaces: Dictionary = {}
static func _static_init()->void:
 stone_surface=CanvasTexture.new()
 stone_surface.diffuse_texture=STONE
 stone_surface.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 stone_surface.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
 walk_surface=CanvasTexture.new()
 walk_surface.diffuse_texture=WALK
 walk_surface.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 walk_surface.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED

static func wall_surface(age: int) -> CanvasTexture:
 if age < 1 or age > AGE_MATERIALS.size():
  return stone_surface
 if not age_surfaces.has(age):
  var texture: Texture2D = load("res://assets/ages/walls/%s.webp" % AGE_MATERIALS[age - 1])
  var age_surface := CanvasTexture.new()
  age_surface.diffuse_texture = texture
  age_surface.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  age_surface.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
  age_surfaces[age] = age_surface
 return age_surfaces[age]

const HEIGHT:=56.0
const HALF:=20.0
const DIRECTIONS=[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]

static func visual_bounds(foundation: Rect2, age: int) -> Rect2:
 var height: float = AGE_HEIGHTS[age-1] if age > 0 else HEIGHT
 var parapet := 13.0 if age == 1 else 22.0
 var rise := height + parapet
 return Rect2(foundation.position - Vector2(rise*0.18,rise), foundation.size + Vector2(rise*0.18,rise))

static func shade(tint:Color,factor:float)->Color:
 return Color(tint.r*factor,tint.g*factor,tint.b*factor,tint.a)

static func exposed_sides(neighbors:Dictionary)->PackedInt32Array:
 var out:=PackedInt32Array()
 for side in 4:
  if not neighbors.has(DIRECTIONS[side]): out.append(side)
 return out

static func footprint(_neighbors:Dictionary)->PackedVector2Array:
 return PackedVector2Array([Vector2(-20,-20),Vector2(20,-20),Vector2(20,20),Vector2(-20,20)])

static func face(canvas:CanvasItem,a:Vector2,b:Vector2,lift:Vector2,tint:Color,origin:Vector2,age:int)->void:
 var delta:=b-a
 var horizontal:bool=absf(delta.x)>absf(delta.y)
 var width := 60.0 if age > 0 else 192.0
 var height: float = AGE_HEIGHTS[age - 1] if age > 0 else 112.0
 var ua:float=(a.x+origin.x)/width if horizontal else (a.y+origin.y)/width
 var ub:float=(b.x+origin.x)/width if horizontal else (b.y+origin.y)/width
 var uv:=PackedVector2Array([Vector2(ua,-lift.y/height),Vector2(ub,-lift.y/height),Vector2(ub,0),Vector2(ua,0)])
 canvas.draw_polygon(PackedVector2Array([a,b,b+lift,a+lift]),PackedColorArray([tint]),uv,wall_surface(age))

static func top(canvas:CanvasItem,points:PackedVector2Array,tint:Color,origin:Vector2,wood:bool)->void:
 var uv:=PackedVector2Array()
 for point in points: uv.append((point+origin)/Vector2(128,112))
 canvas.draw_polygon(points,PackedColorArray([tint]),uv,walk_surface if wood else stone_surface)

static func small_prism(canvas:CanvasItem,rect:Rect2,height:float,tint:Color,origin:Vector2,age:int)->void:
 var lift:=Vector2(-height*0.18,-height)
 var nw:=rect.position
 var ne:=Vector2(rect.end.x,rect.position.y)
 var se:=rect.end
 var sw:=Vector2(rect.position.x,rect.end.y)
 face(canvas,ne,se,lift,shade(tint,0.67),origin,age)
 face(canvas,se,sw,lift,shade(tint,0.94),origin,age)
 top(canvas,PackedVector2Array([nw+lift,ne+lift,se+lift,sw+lift]),shade(tint,1.12),origin,age==1)

static func stake(canvas: CanvasItem, center: Vector2, tint: Color, origin: Vector2) -> void:
 small_prism(canvas,Rect2(center-Vector2(3,3),Vector2(6,6)),6.0,tint,origin,1)
 var root := center + Vector2(-1,-6)
 var peak := root + Vector2(-1,-7)
 canvas.draw_colored_polygon(PackedVector2Array([root+Vector2(-3,3),root+Vector2(3,3),peak]),tint*Color("c09965"))
 canvas.draw_colored_polygon(PackedVector2Array([root+Vector2(3,-3),root+Vector2(3,3),peak]),tint*Color("8b613d"))

static func piece(canvas:CanvasItem,position:Vector2,neighbors:Dictionary,tint:Color=Color.WHITE,age:int=0,height_override:float=-1.0)->void:
 var outline:=footprint(neighbors)
 var height:float=AGE_HEIGHTS[age-1] if age>0 else HEIGHT
 if height_override>=0.0: height=height_override
 var lift:=Vector2(-height*0.18,-height)
 canvas.draw_set_transform(position)
 # Every wall fills its full foundation. Only the outside of a joined mass has
 # vertical faces and parapets; interiors become one continuous raised deck.
 if not neighbors.has(DIRECTIONS[1]): face(canvas,outline[1],outline[2],lift,shade(tint,0.70),position,age)
 if not neighbors.has(DIRECTIONS[2]): face(canvas,outline[2],outline[3],lift,shade(tint,0.94),position,age)
 var upper:=PackedVector2Array()
 for point in outline: upper.append(point+lift)
 top(canvas,upper,shade(tint,0.94),position,age<=4)
 var exposed:=exposed_sides(neighbors)
 for side in [0,3,1,2]:
  if not exposed.has(side): continue
  var horizontal:bool=side in [0,2]
  var edge:float=-20.0 if side in [0,3] else 15.0
  var rect:=Rect2(Vector2(-20,edge),Vector2(40,5)) if horizontal else Rect2(Vector2(edge,-20),Vector2(5,40))
  if age == 1:
   for step in [-15.0,-5.0,5.0,15.0]:
    var at := Vector2(step, edge+2.5) if horizontal else Vector2(edge+2.5, step)
    stake(canvas, at+lift, tint, position)
   continue
  small_prism(canvas,Rect2(rect.position+lift,rect.size),9,tint,position,age)
  for step in [-13.0,7.0]:
   var block:=Rect2(Vector2(step,edge-1),Vector2(9,7)) if horizontal else Rect2(Vector2(edge-1,step),Vector2(7,9))
   small_prism(canvas,Rect2(block.position+lift,block.size),19,shade(tint,0.98),position,age)
 # Four outside corners for a 3x3 block, no towers at interior T/cross junctions.
 for corner in 4:
  var previous:int=(corner+3)%4
  if age != 1 and exposed.has(previous) and exposed.has(corner):
   var at:Vector2=outline[corner]+Vector2(0 if corner in [0,3] else -10,0 if corner in [0,1] else -10)
   small_prism(canvas,Rect2(at+lift,Vector2(10,10)),22,tint,position,age)
 canvas.draw_set_transform(Vector2.ZERO)

static func preview(canvas:CanvasItem,sim,points:Array,tint:Color)->void:
 var nodes:Dictionary={}
 for p in points: nodes[Vector2i((p/40.0).floor())]=true
 for p in points:
  var neighbors:Dictionary={}
  var cell:=Vector2i((p/40.0).floor())
  for direction in DIRECTIONS:
   var other:Vector2=(Vector2(cell+direction)+Vector2.ONE*0.5)*40.0
   var existing:int=sim.wall_at(other)
   if nodes.has(cell+direction) or (existing>=0 and sim.buildings[existing].hp>0): neighbors[direction]=true
  piece(canvas,p,neighbors,tint,sim.settlement_age)
