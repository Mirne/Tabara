extends Node2D
## Raster scenery, animated sprite units, depth ordering, and culled world rendering.
const Map=preload("res://scripts/world_data.gd")
const Art=preload("res://scripts/frontier_art.gd")
const RESOURCE_SITES=preload("res://assets/frontier/resource-sites.png")
const MOUNTAINS=preload("res://assets/frontier/mountains.png")
const WALL_KIT=preload("res://assets/frontier/wall-kit.png")
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
var ground_mountains:=true
var mountain_sprites:Array=[]
var terrain_overlays:Dictionary={}
var preview_range:=0.0
var blocked_view:Sprite2D

func _ready()->void:
 scenery=Map.scenery()
 mountain_sprites=Map.mountain_sprites()
 for prop in scenery:
  prop.protected=prop.art==4 or Map.protected_resource_scenery(prop.pos)
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
 var ridge_data:=PackedVector4Array()
 for rect in Map.MOUNTAIN_RECTS: ridge_data.append(Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
 material.set_shader_parameter("ridge_rects",ridge_data)
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
 blocked_view=Sprite2D.new()
 blocked_view.centered=false
 blocked_view.scale=Vector2.ONE*Map.CELL
 blocked_view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 blocked_view.z_index=-5
 blocked_view.visible=false
 add_child(blocked_view)
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
 if ground_mountains!=sim.mountains_enabled:
  ground_mountains=sim.mountains_enabled
  ground_view.get_child(0).material.set_shader_parameter("mountains_on",ground_mountains)
  ground_view.render_target_update_mode=SubViewport.UPDATE_ONCE
 blocked_view.visible=game.build_kind!=""
 if game.build_kind!="": draw_grid()
 if sim.mountains_enabled:
  for mountain in mountain_sprites:
   if visible_world.grow(300).has_point(mountain.pos): entities.append({"y":mountain.pos.y,"mountain":mountain})
 for prop in scenery:
  if not scenery_visible(prop): continue
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
  draw_texture_rect(preload("res://assets/frontier/earth.png"),Art.dirt_rect(sim.DEFINITIONS[b.kind].art,b.pos),false,Color(0.83,0.85,0.75,0.85))
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
  if entity.has("mountain"):
   var mountain:Dictionary=entity.mountain
   draw_texture_rect(MOUNTAINS,Rect2(mountain.pos-mountain.size*Vector2(0.5,0.86),mountain.size),false)
  elif entity.has("prop"):
   var item:Dictionary=entity.prop
   Art.prop(self,item.art,item.pos,item.scale,item.flip)
  elif entity.has("building"): draw_building(entity.building)
  elif entity.has("deposit"): draw_deposit(entity.deposit)
  else: draw_enemy(entity.enemy,entity.pos)
 draw_effects()
 preview_range=0.0
 if game.build_kind!="" and sim.DEFINITIONS[game.build_kind].has("range"):
  preview_range=float(sim.DEFINITIONS[game.build_kind].range)
  draw_circle(game.ghost,preview_range,Color(0.85,0.73,0.35,0.07))
  draw_arc(game.ghost,preview_range,0,TAU,128,Color(0.96,0.82,0.4,0.85),2/game.zoom,true)
  draw_string(Body,game.ghost+Vector2(14,preview_range-12),"Range %d"%preview_range,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f3e6c2"))
 if game.build_kind=="wall" and not game.wall_points.is_empty():
  var preview:Dictionary=sim.wall_preview(game.wall_points)
  var tint:=Color(0.8,1,0.73,0.7) if preview.error=="" else Color(1,0.38,0.26,0.7)
  for i in game.wall_points.size():
   var p:Vector2=game.wall_points[i]
   draw_rect(sim.foundation_rect(p,"wall"),Color(tint,0.16))
   draw_rect(sim.foundation_rect(p,"wall"),tint,false,1.5/game.zoom)
   if i>0: wall_edge(game.wall_points[i-1],p,tint)
  if game.wall_points.size()==1: wall_edge(game.wall_points[0]-Vector2(40,0),game.wall_points[0]+Vector2(40,0),tint)
  wall_post(game.wall_points[0],tint)
  wall_post(game.wall_points[-1],tint)
 elif game.build_kind!="" and visible_world.has_point(game.ghost):
  var error:String=sim.placement_error(game.ghost,game.build_kind)
  var tint:=Color(0.8,1,0.73,0.6) if error=="" and sim.can_afford(sim.DEFINITIONS[game.build_kind].cost) else Color(1,0.38,0.26,0.6)
  var foundation:Rect2=sim.foundation_rect(game.ghost,game.build_kind)
  draw_rect(foundation,Color(tint,0.17))
  draw_rect(foundation,tint,false,2/game.zoom)
  Art.building(self,sim.DEFINITIONS[game.build_kind].art,game.ghost,1,tint)
 last_draw_us=Time.get_ticks_usec()-draw_started

func scenery_visible(prop:Dictionary)->bool:
 if not game.sim.vegetation_cleared(prop.pos): return true
 if not prop.protected: return false
 if prop.art==4: return true
 for i in game.sim.nearby_buildings(prop.pos,160):
  if game.sim.buildings[i].kind=="wood" and game.sim.foundation_rect(game.sim.buildings[i].pos,"wood").has_point(prop.pos): return false
 return true

func draw_grid()->void:
 var grid:float=game.sim.GRID_SIZE
 var layout:bool=game.sim.mountains_enabled
 if not terrain_overlays.has(layout):
  var field:=Map.terrain_field(layout)
  var pixels:=PackedByteArray()
  pixels.resize(field.size()*4)
  for i in field.size():
   pixels[i*4]=215
   pixels[i*4+1]=50
   pixels[i*4+2]=35
   pixels[i*4+3]=55 if field[i]>0 else 0
  var image:=Image.create_from_data(Map.GRID_WIDTH,Map.GRID_HEIGHT,false,Image.FORMAT_RGBA8,pixels)
  terrain_overlays[layout]=ImageTexture.create_from_image(image)
 blocked_view.texture=terrain_overlays[layout]
 for b in game.sim.buildings:
  if b==null or not visible_world.has_point(b.pos): continue
  var color:=Color(0.91,0.2,0.14,0.26) if b.hp>0 else Color(0.7,0.47,0.2,0.2)
  draw_rect(game.sim.foundation_rect(b.pos,b.kind),color)
  draw_rect(game.sim.foundation_rect(b.pos,b.kind),Color(color,0.85),false,1.2/game.zoom)
 var area:=Rect2(game.camera_center-game.VIEW.size/(game.zoom*2),game.VIEW.size/game.zoom)
 for x in range(maxi(0,floori(area.position.x/grid)),mini(int(Map.SIZE.x/grid),ceili(area.end.x/grid))+1):
  draw_line(Vector2(x*grid,maxf(0,area.position.y)),Vector2(x*grid,minf(Map.SIZE.y,area.end.y)),Color(0.91,0.86,0.65,0.16 if x%2 else 0.28),1/game.zoom)
 for y in range(maxi(0,floori(area.position.y/grid)),mini(int(Map.SIZE.y/grid),ceili(area.end.y/grid))+1):
  draw_line(Vector2(maxf(0,area.position.x),y*grid),Vector2(minf(Map.SIZE.x,area.end.x),y*grid),Color(0.91,0.86,0.65,0.16 if y%2 else 0.28),1/game.zoom)
 if game.build_kind in ["wood","stone"]:
  for i in game.sim.resource_nodes.size():
   var node:Dictionary=game.sim.resource_nodes[i]
   if node.kind!=game.build_kind or not area.grow(180).has_point(node.pos): continue
   var site:Rect2=game.sim.foundation_rect(game.sim.snap_position(node.pos,game.build_kind),game.build_kind)
   draw_rect(site,Color(0.91,0.72,0.34,0.18))
   draw_rect(site,Color("b59455") if game.sim.deposit_owner(i)>=0 else Color("c4d295"),false,2/game.zoom)

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
  if b.kind=="wall": draw_joined_wall(index,tint)
  else: Art.building(self,sim.DEFINITIONS[b.kind].art,p,1,tint)
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
  var top:Vector2=Vector2(p.x-42,Art.building_rect(sim.DEFINITIONS[b.kind].art,p).position.y-13)
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
 if d.kind=="gold":
  Art.prop(self,5,d.pos,0.85)
  return
 var cell:=Vector2(RESOURCE_SITES.get_width()/2,RESOURCE_SITES.get_height())
 var size:=Vector2(240,220) if d.kind=="wood" else Vector2(220,140)
 draw_texture_rect_region(RESOURCE_SITES,Rect2(d.pos-size*Vector2(0.5,0.84),size),Rect2(Vector2.ZERO if d.kind=="wood" else Vector2(cell.x,0),cell))

func wall_region(index:int)->Rect2:
 var regions=[Rect2(58,257,653,236),Rect2(1046,44,84,638),Rect2(1687,175,242,355)]
 var region:Rect2=regions[index]
 var factor:=Vector2(WALL_KIT.get_size())/Vector2(2172,724)
 return Rect2(region.position*factor,region.size*factor)

func wall_edge(a:Vector2,b:Vector2,tint:Color=Color.WHITE)->void:
 if absf(a.x-b.x)>1:
  draw_texture_rect_region(WALL_KIT,Rect2(minf(a.x,b.x),a.y-43,absf(a.x-b.x)+1,47),wall_region(0),tint)
 else:
  # A complete top-down sprite has no sheared/cropped brick edges.
  draw_texture_rect_region(WALL_KIT,Rect2(a.x-12,minf(a.y,b.y)-20,24,absf(a.y-b.y)+1),wall_region(1),tint)

func wall_post(p:Vector2,tint:Color=Color.WHITE)->void:
 draw_texture_rect_region(WALL_KIT,Rect2(p-Vector2(19,48),Vector2(38,56)),wall_region(2),tint)

func draw_joined_wall(index:int,tint:Color)->void:
 var sim=game.sim
 var p:Vector2=sim.buildings[index].pos
 var neighbors:Dictionary=sim.wall_neighbors(index)
 for direction in [Vector2i(2,0),Vector2i(0,2)]:
  if neighbors.has(direction): wall_edge(p,sim.buildings[neighbors[direction]].pos,tint)
 if neighbors.is_empty():
  wall_edge(p-Vector2(40,0),p+Vector2(40,0),tint)
  wall_post(p-Vector2(40,0),tint)
  wall_post(p+Vector2(40,0),tint)
 elif neighbors.size()==1:
  var direction:Vector2=Vector2(neighbors.keys()[0]).normalized()
  var end:=p-direction*40
  wall_edge(p,end,tint)
  wall_post(end,tint)
 elif not (neighbors.size()==2 and (neighbors.has(Vector2i(2,0)) and neighbors.has(Vector2i(-2,0)) or neighbors.has(Vector2i(0,2)) and neighbors.has(Vector2i(0,-2)))):
  wall_post(p,tint)

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
   if e.has("gold"):
    var at:Vector2=e.pos+Vector2(-23,-110-t*30)
    Art.icon(self,2,Rect2(at,Vector2(20,20)),Color(1,1,1,1-t))
    draw_string(Body,at+Vector2(24,17),"+%d"%int(e.gold),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(0.99,0.85,0.43,1-t))
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
