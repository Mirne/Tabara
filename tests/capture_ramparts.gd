extends SceneTree
## Screenshot fixture for every possible cardinal wall connection.
class WallSample:
 extends Node2D
 const Wall=preload("res://scripts/wall_art.gd")
 var links:Dictionary={}
 func _draw()->void:
  for direction in links:
   Wall.piece(self,Vector2(direction)*40.0,{-direction:true},Color(0.78,0.8,0.75))
  Wall.piece(self,Vector2.ZERO,links)
func _init()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1440,810)
 var background:=ColorRect.new()
 background.size=Vector2(1440,810)
 background.color=Color("333a2b")
 root.add_child(background)
 for mask in 16:
  var sample:=WallSample.new()
  sample.position=Vector2(180+(mask%4)*350,140+(mask/4)*180)
  sample.scale=Vector2.ONE*0.6
  for i in 4:
   if mask&(1<<i):sample.links[WallSample.Wall.DIRECTIONS[i]]=true
  root.add_child(sample)
  var label:=Label.new()
  label.text="%02d"%mask
  label.position=sample.position+Vector2(-130,-105)
  root.add_child(label)
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/v06-wall-matrix.png")
 print("RAMPART MATRIX: rendered all 16 cardinal connection combinations")
 background.queue_free()
 for node in root.get_children():node.queue_free()
 await process_frame
 quit()
