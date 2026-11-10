extends Node2D
## Raster scenery, animated sprite units, depth ordering, and culled world rendering.
const Map=preload("res://scripts/world_data.gd")
const Art=preload("res://scripts/frontier_art.gd")
const Body=preload("res://assets/fonts/Body.ttf")
const UNIT_ROWS={"raider":0,"runner":1,"brute":2,"siege":3}
var game
var scenery:Array=[]
var ground_view:SubViewport
var ground_sprite:Sprite2D
var water:Sprite2D
var shadow:GradientTexture2D
var cloud:GradientTexture2D
var visible_world:=Rect2()
var drawn_entities:=0
var last_draw_us:=0

func _ready()->void:
 scenery=Map.scenery()
 ground_view=SubViewport.new()
 ground_view.size=Vector2i(4096,2560)
 ground_view.disable_3d=true
 ground_view.render_target_update_mode=SubViewport.UPDATE_ONCE
 ground_view.world_2d=World2D.new()
 var source:=Sprite2D.new()
 source.texture=preload("res://assets/frontier/terrain.png")
 source.centered=false
 source.scale=Vector2(ground_view.size)/source.texture.get_size()
 var material:=ShaderMaterial.new()
 material.shader=preload("res://scripts/frontier_ground.gdshader")
 material.set_shader_parameter("terrain_materials",source.texture)
 material.set_shader_parameter("water_materials",preload("res://assets/frontier/water.png"))
 material.set_shader_parameter("groves",PackedVector2Array(Map.GROVES))
 material.set_shader_parameter("cliffs",PackedVector2Array(Map.CLIFFS))
 material.set_shader_parameter("road",PackedVector2Array(Map.ROAD))
 source.material=material
 ground_view.add_child(source)
 add_child(ground_view)
 ground_sprite=Sprite2D.new()
 ground_sprite.texture=ground_view.get_texture()
 ground_sprite.centered=false
 ground_sprite.scale=Map.SIZE/Vector2(ground_view.size)
 ground_sprite.z_index=-10
 add_child(ground_sprite)
 water=Sprite2D.new()
 water.texture=preload("res://assets/frontier/water.png")
 water.centered=false
 water.position=Vector2(5450,980)
 water.scale=Vector2(2100,1240)/water.texture.get_size()
 water.z_index=-9
 var water_material:=ShaderMaterial.new()
 water_material.shader=preload("res://scripts/frontier_water.gdshader")
 water_material.set_shader_parameter("motion_rate",0.0 if game.reduced_motion else 1.0)
 water.material=water_material
 add_child(water)
 shadow=soft_texture(Color(0.035,0.045,0.025,0.5))
 cloud=soft_texture(Color(0.42,0.39,0.33,0.55))

func soft_texture(color:Color)->GradientTexture2D:
 var texture:=GradientTexture2D.new()
 texture.width=64
 texture.height=64
 texture.fill=GradientTexture2D.FILL_RADIAL
 texture.fill_from=Vector2(0.5,0.5)
 texture.fill_to=Vector2(1,0.5)
 var gradient:=Gradient.new()
 gradient.set_color(0,color)
 gradient.set_color(1,Color(color,0))
 texture.gradient=gradient
 return texture

func _draw()->void:
 if game==null or game.sim==null: return
 var draw_started:=Time.get_ticks_usec()
 var sim=game.sim
 visible_world=Rect2(game.camera_center-game.VIEW.size/(game.zoom*2),game.VIEW.size/game.zoom).grow(300)
 var entities:Array=[]
 for prop in scenery:
  if sim.vegetation_cleared(prop.pos): continue
  if visible_world.has_point(prop.pos): entities.append({"y":prop.pos.y,"prop":prop})
 for i in sim.resource_nodes.size():
  var d:Dictionary=sim.resource_nodes[i]
  if visible_world.has_point(d.pos): entities.append({"y":d.pos.y,"deposit":i})
 for i in sim.buildings.size():
  var b=sim.buildings[i]
  if b!=null and visible_world.has_point(b.pos): entities.append({"y":b.pos.y,"building":i})
 for e in sim.enemies:
  var p:Vector2=sim.enemy_position(e)
  if visible_world.has_point(p): entities.append({"y":p.y,"enemy":e,"pos":p})
 entities.sort_custom(func(a,b):return a.y<b.y)
 drawn_entities=entities.size()
 for b in sim.buildings:
  if b==null or not visible_world.has_point(b.pos): continue
  var width:float=sim.footprint(b.kind)*3.5+55
  draw_texture_rect(preload("res://assets/frontier/earth.png"),Rect2(b.pos-Vector2(width/2,width*0.23),Vector2(width,width*0.46)),false,Color(0.83,0.85,0.75,0.85))
 # Keep ground shadows together so a horde does not switch textures per soldier.
 for entity in entities:
  if entity.has("enemy"):
   draw_texture_rect(shadow,Rect2(entity.pos-Vector2(28,9),Vector2(56,25)),false)
  elif entity.has("building"):
   var b:Dictionary=sim.buildings[entity.building]
   var radius:float=sim.footprint(b.kind)
   draw_texture_rect(shadow,Rect2(b.pos-Vector2(radius+35,27),Vector2(radius*2+70,70)),false)
 if game.selected>=0 and game.selected<sim.buildings.size() and sim.buildings[game.selected]!=null:
  var b:Dictionary=sim.buildings[game.selected]
  if sim.DEFINITIONS[b.kind].has("range") and b.hp>0:
   draw_arc(b.pos,sim.stat(b,"range"),0,TAU,96,Color(0.93,0.77,0.38,0.24),1.3/game.zoom,true)
 for entity in entities:
  if entity.has("prop"):
   var item:Dictionary=entity.prop
   Art.prop(self,item.art,item.pos,item.scale,item.flip)
  elif entity.has("building"): draw_building(entity.building)
  elif entity.has("deposit"): draw_deposit(entity.deposit)
  else: draw_enemy(entity.enemy,entity.pos)
 # Gathering controls stay legible even when foreground canopies overlap a grove.
 for i in sim.resource_nodes.size():
  if visible_world.has_point(sim.resource_nodes[i].pos): draw_deposit_marker(i)
 draw_effects()
 if game.build_kind!="" and visible_world.has_point(game.ghost):
  var error:String=sim.placement_error(game.ghost,game.build_kind)
  var tint:=Color(0.8,1,0.73,0.6) if error=="" and sim.can_afford(sim.DEFINITIONS[game.build_kind].cost) else Color(1,0.38,0.26,0.6)
  var radius:float=sim.footprint(game.build_kind)
  draw_texture_rect(shadow,Rect2(game.ghost-Vector2(radius,radius*0.5),Vector2(radius*2,radius)),false,Color(1,1,1,0.6))
  Art.building(self,sim.DEFINITIONS[game.build_kind].art,game.ghost,1,tint)
  ground_ring(game.ghost,radius,tint)
 last_draw_us=Time.get_ticks_usec()-draw_started

func draw_building(index:int)->void:
 var sim=game.sim
 var b:Dictionary=sim.buildings[index]
 var p:Vector2=b.pos
 var radius:float=sim.footprint(b.kind)
 if b.hp<=0:
  Art.prop(self,7,p,0.7+radius/180.0)
  if sim.elapsed-b.ruined_at<8 and not game.reduced_motion: smoke(p,1.6)
 else:
  var tint:=Color(0.94,0.96,0.89)
  if b.age<sim.BUILD_TIME: tint=Color(0.75,0.7,0.56,0.55+b.age/sim.BUILD_TIME*0.45)
  Art.building(self,sim.DEFINITIONS[b.kind].art,p,1,tint)
  if not game.reduced_motion:
   if b.kind in ["hall","wood","stone","market"]: smoke(p-Vector2(15,Art.BUILD_SIZES[sim.DEFINITIONS[b.kind].art].y*0.75),0.5)
   if b.kind in ["wood","stone","market"]:
    var phase:float=game.animation_clock*0.55+index
    var worker:Vector2=p+Vector2(sin(phase)*65,24+cos(phase)*22)
    Art.unit(self,4,int(game.animation_clock*5+index)%4,worker,0.8,cos(phase)<0)
  if b.hp<sim.stat(b,"hp")*0.4 and not game.reduced_motion: smoke(p-Vector2(0,55),1.2)
 var selected:bool=index==game.selected
 if selected:
  ground_ring(p,radius+7,Color("d9bc71"))
 if selected or b.hp<sim.stat(b,"hp")*0.95:
  var top:Vector2=p-Vector2(42,Art.BUILD_SIZES[sim.DEFINITIONS[b.kind].art].y+13)
  if b.hp<=0: top=p-Vector2(42,105)
  draw_rect(Rect2(top,Vector2(84,6)),Color("242b20"))
  draw_rect(Rect2(top,Vector2(84*clampf(b.hp/sim.stat(b,"hp"),0,1),6)),Color("9bac68") if b.hp>0 else Color("a45839"))
  if selected: draw_string(Body,top-Vector2(0,7),"%s · %d"%[sim.DEFINITIONS[b.kind].name,b.level],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f3e6c2"))

func draw_enemy(e:Dictionary,p:Vector2)->void:
 var row:int=UNIT_ROWS[e.kind]
 var frame:int=int(game.animation_clock*(10 if e.kind=="runner" else 6)+e.phase)%4
 if game.reduced_motion: frame=0
 Art.unit(self,row,frame,p)
 if e.hp<e.max_hp*0.97:
  draw_rect(Rect2(p-Vector2(17,83 if row!=2 else 102),Vector2(34,4)),Color("2b2520"))
  draw_rect(Rect2(p-Vector2(17,83 if row!=2 else 102),Vector2(34*e.hp/e.max_hp,4)),Color("ad6f4c"))

func draw_deposit(index:int)->void:
 var d:Dictionary=game.sim.resource_nodes[index]
 var art:int={"wood":6,"stone":4,"gold":5}[d.kind]
 Art.prop(self,art,d.pos,1.2)

func draw_deposit_marker(index:int)->void:
 var d:Dictionary=game.sim.resource_nodes[index]
 var anchor:Vector2=d.pos+Vector2(0,24)
 Art.skin(self,Rect2(anchor-Vector2(23,22),Vector2(46,42)),Color(0.82,0.88,0.8),7)
 Art.icon(self,["wood","stone","gold"].find(d.kind),Rect2(anchor-Vector2(15,16),Vector2(30,30)),Color(1,1,1,0.5 if game.sim.deposits[index]>0 else 1))
 if game.sim.deposits[index]>0:
  draw_string(Body,anchor+Vector2(27,5),"%ds"%ceili(game.sim.deposits[index]),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e3d7b7"))

func smoke(p:Vector2,scale_value:float)->void:
 for i in 3:
  var t:float=fmod(game.clock*0.23+i/3.0,1.0)
  var size:float=(18+t*38)*scale_value
  var at:Vector2=p+Vector2(t*25,-t*75)*scale_value
  draw_texture_rect(cloud,Rect2(at-Vector2.ONE*size/2,Vector2.ONE*size),false,Color(1,1,1,(1-t)*0.65))

func ground_ring(p:Vector2,radius:float,color:Color)->void:
 draw_set_transform(p,0,Vector2(1,0.45))
 draw_arc(Vector2.ZERO,radius,0,TAU,48,color,2/game.zoom,true)
 draw_set_transform(Vector2.ZERO)

func draw_effects()->void:
 for e in game.fx:
  var t:float=1-e.time/e.duration
  if e.type=="shot":
   var at:Vector2=e.from.lerp(e.pos,t)-Vector2(0,sin(t*PI)*(90 if e.cannon else 24))
   if e.cannon:
    draw_texture_rect(cloud,Rect2(at-Vector2(10,10),Vector2(20,20)),false,Color("12120e"))
   else: draw_line(at,at-(e.pos-e.from).normalized()*19,Color("dbc59a"),2,true)
  elif e.type=="kill":
   var elapsed:float=e.duration-e.time
   var fall:float=clampf((elapsed-0.24)/0.56,0,1)
   if elapsed<0.8:
    draw_set_transform(e.pos+Vector2(fall*14,0),fall*1.25,Vector2.ONE)
    Art.unit(self,UNIT_ROWS.get(e.get("kind","raider"),0),int(e.get("phase",0))%4,Vector2.ZERO,1,false,Color(0.92-fall*0.3,0.89-fall*0.3,0.8-fall*0.3,1-fall))
    draw_set_transform(Vector2.ZERO)
   if elapsed>0.24:
    var size:float=25+fall*55
    draw_texture_rect(cloud,Rect2(e.pos-Vector2.ONE*size/2,Vector2.ONE*size),false,Color(0.7,0.56,0.37,1-fall))
  elif e.type=="ruin":
   var collapse:float=clampf((e.duration-e.time)/0.4,0,1)
   if collapse<1 and e.has("kind"):
    draw_set_transform(e.pos+Vector2(sin(game.clock*55)*2,0),0,Vector2(1,1-collapse*0.4))
    Art.building(self,game.sim.DEFINITIONS[e.kind].art,Vector2.ZERO,1,Color(0.9,0.85,0.72,1-collapse))
    draw_set_transform(Vector2.ZERO)
   var size:float=60+t*200
   draw_texture_rect(cloud,Rect2(e.pos-Vector2.ONE*size/2-Vector2(0,t*30),Vector2.ONE*size),false,Color(0.7,0.6,0.45,1-t))
  elif e.type=="hit":
   var size:float=(30+t*100)*(2 if e.type=="ruin" else 0.5)
   draw_texture_rect(cloud,Rect2(e.pos-Vector2.ONE*size/2-Vector2(0,t*30),Vector2.ONE*size),false,Color(0.7,0.6,0.45,1-t))
  elif e.type in ["gather","build"]:
   draw_string(Body,e.pos-Vector2(30,70+t*30),e.text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(0.95,0.86,0.6,1-t))
