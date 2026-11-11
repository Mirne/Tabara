extends SceneTree
## Reproducible static terrain/navigation bake. No gameplay rules or grants are changed.
const Map=preload("res://scripts/world_data.gd")
const Navigator=preload("res://scripts/assault_navigation.gd")
func _init()->void:call_deferred("run")
func run()->void:
 var data:Dictionary=Map.authored.duplicate(true)
 data["terrain_fields"]={}
 data["navigation"]={}
 for revision in range(Map.AUTHORED_REVISION+1):
  var started:=Time.get_ticks_msec()
  var field:PackedInt32Array=Map.compute_field(revision)
  Map.terrain_fields[revision]=field
  var nav=Navigator.new(Map.HALL,revision,false)
  var weights:Array=[]
  for cost in nav.costs:weights.append(float(cost) if is_finite(cost) else -1.0)
  data.terrain_fields[str(revision)]=Array(field)
  data.navigation[str(revision)]={"signature":JSON.stringify(Array(field)).sha256_text(),"following":Array(nav.following),"costs":weights}
  print("BAKED layout ",revision," in ",Time.get_ticks_msec()-started,"ms")
 var pixels:=PackedByteArray()
 pixels.resize(Map.GRID_WIDTH*Map.GRID_HEIGHT*4)
 var field:PackedInt32Array=Map.terrain_fields[2]
 for y in Map.GRID_HEIGHT:
  for x in Map.GRID_WIDTH:
   var index:int=y*Map.GRID_WIDTH+x
   var point:=Map.cell_center(Vector2i(x,y))
   var road:=0.0
   for path_index in Map.authored.trails.size():
    var trail:Array=Map.authored.trails[path_index]
    var width:float=64 if path_index==0 else 30
    for i in range(trail.size()-1):
     var a:=Vector2(trail[i][0],trail[i][1])
     var b:=Vector2(trail[i+1][0],trail[i+1][1])
     var distance:float=point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b))
     road=maxf(road,1.0-smoothstep(width,width+45,distance))
   var common:float=((point-Map.HALL)/Vector2(330,230)).length()
   road=maxf(road,(1.0-smoothstep(0.55,1.25,common))*0.55)
   var rock:=0.0
   var wet:=0.0
   for dy in range(-2,3):
    for dx in range(-2,3):
     var cx:=x+dx
     var cy:=y+dy
     if cx<0 or cy<0 or cx>=Map.GRID_WIDTH or cy>=Map.GRID_HEIGHT:continue
     var kind:int=field[cy*Map.GRID_WIDTH+cx]
     var strength:float=1.0-float(absi(dx)+absi(dy))/5.0
     if kind in [3,4]:rock=maxf(rock,strength)
     if kind==2:wet=maxf(wet,strength)
   var dry:float=smoothstep(3250,4750,point.y)*(1.0-smoothstep(2700,3700,point.x))
   pixels[index*4]=roundi(road*255)
   pixels[index*4+1]=roundi(rock*255)
   pixels[index*4+2]=roundi(wet*255)
   pixels[index*4+3]=roundi(dry*255)
 data["surface_pixels"]=Marshalls.raw_to_base64(pixels)
 var file:=FileAccess.open("res://assets/world/hearthvale.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(data,"",true,true))
 file.close()
 var woods:Dictionary=Map.woodland.duplicate(true)
 var woodland_pixels:=PackedByteArray()
 woodland_pixels.resize(pixels.size())
 var woodland_field:PackedInt32Array=Map.terrain_fields[3]
 for y in Map.GRID_HEIGHT:
  for x in Map.GRID_WIDTH:
   var index:int=y*Map.GRID_WIDTH+x
   var tree:=0.0
   for dy in range(-4,5):
    for dx in range(-4,5):
     var cx:=x+dx
     var cy:=y+dy
     if cx<0 or cy<0 or cx>=Map.GRID_WIDTH or cy>=Map.GRID_HEIGHT: continue
     if woodland_field[cy*Map.GRID_WIDTH+cx]==6:
      tree=maxf(tree,1.0-Vector2(dx,dy).length()/5.0)
   woodland_pixels[index*4]=pixels[index*4]
   woodland_pixels[index*4+1]=pixels[index*4+1]
   woodland_pixels[index*4+2]=pixels[index*4+2]
   woodland_pixels[index*4+3]=roundi(tree*255)
 woods["surface_pixels"]=Marshalls.raw_to_base64(woodland_pixels)
 woods.erase("forest_cells")
 var woodland_file:=FileAccess.open("res://assets/world/woodland.json",FileAccess.WRITE)
 woodland_file.store_string(JSON.stringify(woods,"",true,true))
 woodland_file.close()
 print("WORLD BAKE COMPLETE: ",Map.GRID_WIDTH*Map.GRID_HEIGHT," cells per layout")
 quit()
