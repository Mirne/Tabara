extends Node2D
## Rendered once into a texture; keeps static terrain off the per-frame draw path.
const Sim = preload("res://scripts/simulation.gd")
const Atlas = preload("res://assets/art/buildings.png")
const Body = preload("res://assets/fonts/Body.ttf")

func _draw() -> void:
 var outline := PackedVector2Array([Vector2(42,198),Vector2(154,150),Vector2(886,145),Vector2(1108,233),Vector2(1106,584),Vector2(974,653),Vector2(161,635),Vector2(42,544)])
 var lower := PackedVector2Array()
 for p in outline: lower.append(p+Vector2(0,25))
 draw_colored_polygon(lower,Color("655f40"))
 draw_colored_polygon(outline,Color("8c9d67"))
 draw_colored_polygon(PackedVector2Array([Vector2(42,198),Vector2(154,150),Vector2(886,145),Vector2(1108,233),Vector2(765,275),Vector2(358,205)]),Color("99a976"))
 draw_colored_polygon(PackedVector2Array([Vector2(42,544),Vector2(250,470),Vector2(551,512),Vector2(974,653),Vector2(161,635)]),Color("82935f"))
 var rng := RandomNumberGenerator.new()
 rng.seed = 18
 for i in 180:
  var p := Vector2(rng.randf_range(58,1090),rng.randf_range(165,626))
  var r := rng.randf_range(1,3)
  draw_circle(p,r,Color(0.26,0.37,0.20,rng.randf_range(0.08,0.23)))
 var points := PackedVector2Array(Sim.PATH)
 for entry in [[61.0,"7b8154"],[49.0,"c6b586"],[32.0,"d1c095"]]:
  draw_polyline(points,Color(entry[1]),entry[0],true)
  for p in points: draw_circle(p,entry[0]/2.0,Color(entry[1]))
 var sim = Sim.new()
 for distance in range(60,int(sim.total_length)-50,63):
  var p: Vector2 = sim.path_point(distance)
  draw_line(p+Vector2(-4,-2),p+Vector2(4,1),Color("b4a577"),2,true)
 for entry in [[108,239,0.88],[137,265,0.8],[245,232,0.78],[398,221,0.62],[103,494,0.78],[159,581,0.95],[1029,215,0.7],[1070,582,0.7],[855,594,0.6]]:
  var dims := Vector2(132,115)*float(entry[2])
  var p := Vector2(entry[0],entry[1])
  draw_texture_rect_region(Atlas,Rect2(p-Vector2(dims.x/2,dims.y),dims),Rect2(1152,512,384,512))
 for entry in [[702,214,17],[736,221,22],[761,189,14],[743,169,12],[196,526,8],[1029,566,10]]:
  var p := Vector2(entry[0],entry[1])
  var r: float = entry[2]
  draw_colored_polygon(PackedVector2Array([p+Vector2(-r,4),p+Vector2(-r*0.6,-r*0.6),p+Vector2(r*0.3,-r),p+Vector2(r,0),p+Vector2(r*0.5,r*0.5)]),Color("adb4a2"))
  draw_line(p+Vector2(-r*0.6,-r*0.6),p+Vector2(r*0.2,-r*0.3),Color("d5dac6"),3,true)
 draw_string(Body,Vector2(469,200),"P I N E W A T C H",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("d8dfb4"))
 draw_string(Body,Vector2(51,347),"WESTERN APPROACH",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("465c3e"))
