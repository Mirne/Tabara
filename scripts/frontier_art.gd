@static_unload
class_name FrontierArt
extends RefCounted
const MINIBOSS=preload("res://assets/frontier/miniboss.png")
const ELITES=preload("res://assets/frontier/elites.png")
const PROPS=preload("res://assets/frontier/props.png")
const UNITS=preload("res://assets/frontier/units.png")
const ATTACKS=preload("res://assets/frontier/attacks.png")
const ATTACK_ROWS=[0,1,2,3,-1,4,5]
# Padded attack cells retain the walking sprites' visible body height and feet.
const ATTACK_SCALES=[1.13172,1.10649,1.20202,1.18453,1.0,1.08311,1.14917]
const ATTACK_PIVOTS=[1.05421,1.02699,0.99209,0.96531,1.0,0.98133,0.95132]
const ICONS=preload("res://assets/frontier/icons.png")
const PANEL=preload("res://assets/frontier/panel.png")
const BUILD_RECTS=[Rect2(8,40,385,465),Rect2(404,117,368,380),Rect2(784,119,373,381),Rect2(1230,42,260,463),Rect2(30,645,345,310),Rect2(416,566,303,391),Rect2(750,600,390,367)]
const BUILD_SIZES=[Vector2(235,232),Vector2(170,148),Vector2(174,148),Vector2(115,202),Vector2(98,70),Vector2(132,158),Vector2(190,142),Vector2(235,180)]
# The logical position is the centre of the visible ground footprint, not the image bottom.
const BUILD_PIVOTS=[Vector2(0.5,0.88),Vector2(0.5,0.88),Vector2(0.51,0.88),Vector2(0.5,0.93),Vector2(0.5,0.86),Vector2(0.5,0.89),Vector2(0.5,0.88),Vector2(0.5,0.88)]
const DIRT_SIZES=[Vector2(275,112),Vector2(195,84),Vector2(200,86),Vector2(120,56),Vector2(96,44),Vector2(158,70),Vector2(216,92),Vector2(260,104)]
const PROP_RECTS=[Rect2(0,0,360,405),Rect2(365,65,345,337),Rect2(712,0,390,403),Rect2(1104,0,344,408),Rect2(0,410,359,337),Rect2(366,416,345,331),Rect2(716,419,364,331),Rect2(1088,420,360,330),Rect2(0,758,360,328),Rect2(365,758,345,328),Rect2(715,758,365,328),Rect2(1088,758,360,328)]
const PROP_SIZES=[Vector2(145,220),Vector2(145,168),Vector2(220,215),Vector2(150,160),Vector2(150,108),Vector2(135,110),Vector2(125,100),Vector2(170,115),Vector2(90,65),Vector2(72,65),Vector2(120,105),Vector2(80,53)]
const UNIT_SIZES=[Vector2(67,80),Vector2(67,80),Vector2(83.75,100),Vector2(118,114),Vector2(50,64),Vector2(84,100),Vector2(126,150)]
const AGE_NAMES = ["wood", "stone", "iron", "steel", "keep", "castle", "citadel", "crown"]
const BUILDING_NAMES = ["hall", "wood", "stone", "arrow", "wall", "cannon", "market", "workshop"]
const RESEARCH_ICONS = ["arrow_damage", "arrow_range", "arrow_cadence", "cannon_damage", "cannon_splash", "cannon_cadence"]
static var age_bounds: Dictionary = {}
static var active_age: int = 0
static var age_sheet: Texture2D
static var age_regions: Array[Rect2] = []
static var loaded_ages: Dictionary = {}
static var research_sheet: Texture2D
static var original_workshop: Texture2D
static var original_buildings: Texture2D
static var unit_regions:Array[Rect2]=[]
static var style_cache:Dictionary={}

static func _static_init()->void:
 if FileAccess.file_exists("res://assets/ages/bounds.json"):
  age_bounds = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ages/bounds.json"))
 var cell:=Vector2(UNITS.get_size())/Vector2(4,5)
 for row in 5:
  for frame in 4: unit_regions.append(Rect2(Vector2(frame,row)*cell,cell))

static func load_age(age: int) -> void:
 if active_age == age:
  return
 active_age = age
 if loaded_ages.has(age):
  age_sheet = loaded_ages[age].sheet
  age_regions = loaded_ages[age].regions
  return
 var key: String = AGE_NAMES[age - 1]
 var path := "res://assets/ages/%s.webp" % key
 age_sheet = load(path) if ResourceLoader.exists(path) else null
 age_regions = []
 var bounds: Dictionary = age_bounds.get(key, {})
 for kind in BUILDING_NAMES:
  var region: Array = bounds.get(kind, [])
  age_regions.append(Rect2(region[0], region[1], region[2], region[3]) if region.size() == 4 else Rect2())
 # The Hall screen displays the current and next paintings in the same frame.
 if loaded_ages.size() >= 2:
  loaded_ages.erase(loaded_ages.keys()[0])
 loaded_ages[age] = {"sheet": age_sheet, "regions": age_regions}

static func building_rect(index:int,base:Vector2,scale_value:float=1.0,age:int=0)->Rect2:
 var size:Vector2=BUILD_SIZES[index]*scale_value
 if age >= 1 and age <= AGE_NAMES.size():
  load_age(age)
  var source_size := age_regions[index].size
  if age_sheet and source_size.x > 0 and source_size.y > 0:
   size = source_size * minf(size.x / source_size.x, size.y / source_size.y)
 return Rect2(base-size*BUILD_PIVOTS[index],size)

static func dirt_rect(index:int,base:Vector2)->Rect2:
 return Rect2(base-DIRT_SIZES[index]*0.5,DIRT_SIZES[index])

static func building(canvas:CanvasItem,index:int,base:Vector2,scale_value:float=1.0,tint:Color=Color.WHITE,age:int=0)->void:
 if age >= 1 and age <= AGE_NAMES.size():
  var rect := building_rect(index, base, scale_value, age)
  if age_sheet and age_regions[index].has_area():
   canvas.draw_texture_rect_region(age_sheet, rect, age_regions[index], tint)
   return
 if index == 7:
  if original_workshop == null and ResourceLoader.exists("res://assets/art/workshop.png"):
   original_workshop = load("res://assets/art/workshop.png")
  if original_workshop:
   canvas.draw_texture_rect(original_workshop, building_rect(index,base,scale_value), false, tint)
 else:
  if original_buildings == null and ResourceLoader.exists("res://assets/art/buildings.png"):
   original_buildings = load("res://assets/art/buildings.png")
  if original_buildings:
   canvas.draw_texture_rect_region(original_buildings, building_rect(index,base,scale_value), BUILD_RECTS[index], tint)

static func building_icon(canvas: CanvasItem, index: int, rect: Rect2, age: int, tint: Color = Color.WHITE) -> void:
 load_age(clampi(age, 1, AGE_NAMES.size()))
 var region := age_regions[index]
 if age_sheet and region.has_area():
  var size := region.size * minf(rect.size.x / region.size.x, rect.size.y / region.size.y)
  canvas.draw_texture_rect_region(age_sheet, Rect2(rect.get_center() - size * 0.5, size), region, tint)
  return
 var ratio := minf(rect.size.x / BUILD_SIZES[index].x, rect.size.y / BUILD_SIZES[index].y)
 building(canvas, index, rect.get_center() + (BUILD_PIVOTS[index] - Vector2(0.5,0.5)) * BUILD_SIZES[index] * ratio, ratio, tint)

static func research_icon(canvas: CanvasItem, track: String, rect: Rect2, age: int, tint: Color = Color.WHITE) -> void:
 var index := RESEARCH_ICONS.find(track)
 if index == -1:
  return
 if research_sheet == null and ResourceLoader.exists("res://assets/ages/research.webp"):
  research_sheet = load("res://assets/ages/research.webp")
 if research_sheet:
  var cell := Vector2(research_sheet.get_size()) / Vector2(RESEARCH_ICONS.size(), AGE_NAMES.size())
  var row := clampi(age, 1, AGE_NAMES.size()) - 1
  canvas.draw_texture_rect_region(research_sheet, rect, Rect2(Vector2(index, row) * cell, cell), tint)
 else:
  building_icon(canvas, 3 if index < 3 else 5, rect, age, tint)

static func prop(canvas:CanvasItem,index:int,base:Vector2,scale_value:float=1.0,flip:bool=false,tint:Color=Color.WHITE)->void:
 var size:Vector2=PROP_SIZES[index]*scale_value
 var target:=Rect2(base-Vector2(size.x/2,size.y),size)
 if flip: target.size.x=-target.size.x
 canvas.draw_texture_rect_region(PROPS,target,PROP_RECTS[index],tint)

static func attack_frame(enemy:Dictionary,reduced_motion:bool=false)->int:
 if not bool(enemy.get("attacking",false)):return -1
 if reduced_motion:return 1
 if float(enemy.get("smash_left",0.0))>0:return 0
 var remaining:float=enemy.get("attack_left",0.0)
 if remaining>0:return 1+clampi(int((1.0-remaining/0.66)*3),0,2)
 return 0 if float(enemy.cooldown)<=0.25 else 3

static func unit(canvas:CanvasItem,row:int,frame:int,base:Vector2,scale_value:float=1.0,flip:bool=false,tint:Color=Color.WHITE,attacking:bool=false)->void:
 var attack:bool=attacking and ATTACK_ROWS[row]>=0
 var size:Vector2=UNIT_SIZES[row]*scale_value*(ATTACK_SCALES[row] if attack else 1.0)
 var target:=Rect2(base-Vector2(size.x/2,size.y*(ATTACK_PIVOTS[row] if attack else 1.0)),size)
 if flip: target.size.x=-target.size.x
 if attack:
  var cell:=Vector2(ATTACKS.get_size())/Vector2(4,6)
  canvas.draw_texture_rect_region(ATTACKS,target,Rect2(Vector2(frame,ATTACK_ROWS[row])*cell,cell),tint)
 elif row in [5,6]:
  var texture:Texture2D=MINIBOSS if row==6 else ELITES
  var cell:=Vector2(texture.get_size())/Vector2(4,1)
  canvas.draw_texture_rect_region(texture,target,Rect2(Vector2(frame,0)*cell,cell),tint)
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
