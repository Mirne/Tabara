@static_unload
class_name FrontierArt
extends RefCounted
const ELITES=preload("res://assets/frontier/elites.png")
const WORKSHOP=preload("res://assets/art/workshop.png")
const BUILDINGS=preload("res://assets/art/buildings.png")
const PROPS=preload("res://assets/frontier/props.png")
const UNITS=preload("res://assets/frontier/units.png")
const ICONS=preload("res://assets/frontier/icons.png")
const PANEL=preload("res://assets/frontier/panel.png")
const BUILD_RECTS=[Rect2(8,40,385,465),Rect2(404,117,368,380),Rect2(784,119,373,381),Rect2(1230,42,260,463),Rect2(30,645,345,310),Rect2(416,566,303,391),Rect2(750,600,390,367)]
const BUILD_SIZES=[Vector2(235,232),Vector2(170,148),Vector2(174,148),Vector2(115,202),Vector2(98,70),Vector2(132,158),Vector2(190,142),Vector2(235,180)]
# The logical position is the centre of the visible ground footprint, not the image bottom.
const BUILD_PIVOTS=[Vector2(0.5,0.88),Vector2(0.5,0.88),Vector2(0.51,0.88),Vector2(0.5,0.93),Vector2(0.5,0.86),Vector2(0.5,0.89),Vector2(0.5,0.88),Vector2(0.5,0.88)]
const DIRT_SIZES=[Vector2(275,112),Vector2(195,84),Vector2(200,86),Vector2(120,56),Vector2(96,44),Vector2(158,70),Vector2(216,92),Vector2(260,104)]
const PROP_RECTS=[Rect2(0,0,360,405),Rect2(365,65,345,337),Rect2(712,0,390,403),Rect2(1104,0,344,408),Rect2(0,410,359,337),Rect2(366,416,345,331),Rect2(716,419,364,331),Rect2(1088,420,360,330),Rect2(0,758,360,328),Rect2(365,758,345,328),Rect2(715,758,365,328),Rect2(1088,758,360,328)]
const PROP_SIZES=[Vector2(145,220),Vector2(145,168),Vector2(220,215),Vector2(150,160),Vector2(150,108),Vector2(135,110),Vector2(125,100),Vector2(170,115),Vector2(90,65),Vector2(72,65),Vector2(120,105),Vector2(80,53)]
const UNIT_SIZES=[Vector2(67,80),Vector2(67,80),Vector2(83.75,100),Vector2(118,114),Vector2(50,64),Vector2(84,100)]
static var unit_regions:Array[Rect2]=[]
static var style_cache:Dictionary={}
static var wall_icon:Texture2D

static func _static_init()->void:
 if ResourceLoader.exists("res://assets/world/wall-icon.png"):wall_icon=load("res://assets/world/wall-icon.png")
 var cell:=Vector2(UNITS.get_size())/Vector2(4,5)
 for row in 5:
  for frame in 4: unit_regions.append(Rect2(Vector2(frame,row)*cell,cell))

static func building_rect(index:int,base:Vector2,scale_value:float=1.0)->Rect2:
 var size:Vector2=BUILD_SIZES[index]*scale_value
 return Rect2(base-size*BUILD_PIVOTS[index],size)

static func dirt_rect(index:int,base:Vector2)->Rect2:
 return Rect2(base-DIRT_SIZES[index]*0.5,DIRT_SIZES[index])

static func building(canvas:CanvasItem,index:int,base:Vector2,scale_value:float=1.0,tint:Color=Color.WHITE)->void:
 if index==7: canvas.draw_texture_rect(WORKSHOP,building_rect(index,base,scale_value),false,tint)
 else: canvas.draw_texture_rect_region(BUILDINGS,building_rect(index,base,scale_value),BUILD_RECTS[index],tint)

static func prop(canvas:CanvasItem,index:int,base:Vector2,scale_value:float=1.0,flip:bool=false,tint:Color=Color.WHITE)->void:
 var size:Vector2=PROP_SIZES[index]*scale_value
 var target:=Rect2(base-Vector2(size.x/2,size.y),size)
 if flip: target.size.x=-target.size.x
 canvas.draw_texture_rect_region(PROPS,target,PROP_RECTS[index],tint)

static func unit(canvas:CanvasItem,row:int,frame:int,base:Vector2,scale_value:float=1.0,flip:bool=false,tint:Color=Color.WHITE)->void:
 var size:Vector2=UNIT_SIZES[row]*scale_value
 var target:=Rect2(base-Vector2(size.x/2,size.y),size)
 if flip: target.size.x=-target.size.x
 if row==5:
  var cell:=Vector2(ELITES.get_size())/Vector2(4,1)
  canvas.draw_texture_rect_region(ELITES,target,Rect2(Vector2(frame,0)*cell,cell),tint)
 else: canvas.draw_texture_rect_region(UNITS,target,unit_regions[row*4+frame],tint)

static func icon(canvas:CanvasItem,index:int,rect:Rect2,tint:Color=Color.WHITE)->void:
 var cell:=Vector2(ICONS.get_size())/Vector2(4,2)
 canvas.draw_texture_rect_region(ICONS,rect,Rect2(Vector2(index%4,index/4)*cell,cell),tint)

static func skin(canvas:CanvasItem,rect:Rect2,tint:Color=Color.WHITE,edge:float=12.0)->void:
 # Native nine-patch rendering; local scaling keeps source corners crisp and small.
 var key:=str(tint)
 var style:StyleBoxTexture
 if style_cache.has(key): style=style_cache[key]
 else:
  style=StyleBoxTexture.new()
  style.texture=PANEL
  style.modulate_color=tint
  for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_texture_margin(side,72)
  if style_cache.size()<64: style_cache[key]=style
 var factor:=edge/72.0
 canvas.draw_set_transform(rect.position,0,Vector2.ONE*factor)
 canvas.draw_style_box(style,Rect2(Vector2.ZERO,rect.size/factor))
 canvas.draw_set_transform(Vector2.ZERO)
