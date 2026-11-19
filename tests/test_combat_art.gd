extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Art=preload("res://scripts/frontier_art.gd")
var checks:=0
var failures:=0
class PoseSheet extends Node2D:
 const Artwork=preload("res://scripts/frontier_art.gd")
 const LabelFont=preload("res://assets/fonts/Body.ttf")
 func _draw()->void:
  draw_rect(Rect2(0,0,1440,810),Color("21372a"))
  var headings:=["Walk right","Walk left","Attack right","Attack left","Recovery"]
  for c in 5:draw_string(LabelFont,Vector2([200,440,700,940,1200][c]-50,28),headings[c],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("eee3c9"))
  var rows:=[0,1,2,3,5,6]
  for r in rows.size():
   var y:=145+r*125
   draw_string(LabelFont,Vector2(12,y-25),["Raider","Runner","Brute","Siege","Elite","Warlord"][r],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("d5b775"))
   Artwork.unit(self,rows[r],1,Vector2(200,y),0.65)
   Artwork.unit(self,rows[r],1,Vector2(440,y),0.65,true)
   Artwork.unit(self,rows[r],1,Vector2(700,y),0.65,false,Color.WHITE,true)
   Artwork.unit(self,rows[r],1,Vector2(940,y),0.65,true,Color.WHITE,true)
   Artwork.unit(self,rows[r],3,Vector2(1200,y),0.65,false,Color.WHITE,true)
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures+=1
  printerr("FAIL COMBAT ART: ",label)
func frame()->void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
func sample(image:Image,rect:Rect2i)->Dictionary:
 var count:=0
 var centroid:=Vector2.ZERO
 var bg:=Color("21372a")
 for y in rect.size.y:
  for x in rect.size.x:
   var c:=image.get_pixel(rect.position.x+x,rect.position.y+y)
   if absf(c.r-bg.r)+absf(c.g-bg.g)+absf(c.b-bg.b)>0.12:
    count+=1
    centroid+=Vector2(x,y)
 return {"count":count,"center":centroid/maxi(1,count)}
func mirror_check(image:Image,a:Rect2i,b:Rect2i,label:String)->void:
 var one:=sample(image,a)
 var two:=sample(image,b)
 check(one.count>50 and two.count>50,label+" contains real sprite pixels")
 check(absf(one.center.x+two.center.x-(a.size.x-1))<1.5 and absf(one.center.y-two.center.y)<1.0,label+" mirrors without moving the anchor")
 var difference:=0.0
 for y in a.size.y:
  for x in a.size.x:
   var ca:=image.get_pixel(a.position.x+x,a.position.y+y)
   var cb:=image.get_pixel(b.end.x-1-x,b.position.y+y)
   difference+=absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)
 check(difference/(a.size.x*a.size.y*3)<0.005,label+" is the horizontal mirror of the same artwork")
func run()->void:
 DirAccess.make_dir_recursive_absolute("res://test-results")
 var atlas:=Image.load_from_file("res://assets/frontier/attacks.png")
 check(atlas.get_size()==Vector2i(1024,1536),"Attack atlas has the exact four-column/six-row grid")
 for row in 6:
  for col in 4:
   var clean:=true
   for edge in 256:
    for point in [Vector2i(col*256+edge,row*256),Vector2i(col*256+edge,row*256+255),Vector2i(col*256,row*256+edge),Vector2i(col*256+255,row*256+edge)]:
     if atlas.get_pixelv(point).a>0.25:clean=false
   check(clean,"Weapon/feet silhouettes stay inside attack cell %d,%d"%[col,row])
 root.size=Vector2i(1440,810)
 var sheet:=PoseSheet.new()
 root.add_child(sheet)
 await frame()
 var image:Image=root.get_texture().get_image()
 image.save_png("res://test-results/combat-art-directions.png")
 for row in 6:
  var y:=145+row*125-110
  mirror_check(image,Rect2i(100,y,200,115),Rect2i(340,y,200,115),"Walking row "+str(row))
  mirror_check(image,Rect2i(600,y,200,115),Rect2i(840,y,200,115),"Attacking row "+str(row))
  check(image.get_region(Rect2i(600,y,200,115)).get_data()!=image.get_region(Rect2i(1100,y,200,115)).get_data(),"Attack and recovery really change pose for row "+str(row))
 var actor:={"attacking":true,"attack_left":0.0,"cooldown":0.2}
 check(Art.attack_frame(actor)==0,"Contact stance winds up before the next hit")
 actor.attack_left=0.66
 check(Art.attack_frame(actor)==1,"Actual hit selects the impact frame")
 actor.attack_left=0.33
 check(Art.attack_frame(actor)==2,"The swing follows through")
 actor.attack_left=0.01
 check(Art.attack_frame(actor)==3,"The swing recovers")
 check(Art.attack_frame(actor,true)==1,"Reduced motion keeps a still attack pose")
 actor.attacking=false
 check(Art.attack_frame(actor)==-1,"Moving actors leave the attack cycle")
 sheet.queue_free()
 await frame()
 # Actual game-world presentation: six combat units attack walls in both directions.
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 await frame()
 game.set_process(false)
 game.sim=Sim.new(73)
 game.sim.resources={"wood":10000.0,"stone":10000.0,"gold":10000.0}
 game.sim.enemies.clear()
 game.sim.spawn_remaining=0
 game.sim.elapsed=899.95
 game.sim.wave=30
 game.sim.boss_intervals=2
 game.sim.step(0.05)
 var final_boss:Dictionary={}
 for enemy in game.sim.enemies:
  if enemy.mission_boss:final_boss=enemy
 game.sim.enemies=[final_boss]
 var kinds:=["raider","runner","brute","siege","elite","boss"]
 for i in kinds.size():
  var position:=Vector2(5880+(i%3)*320,2720+(i/3)*320).snapped(Vector2.ONE*40)
  check(game.sim.build_at(position,"wall")=="","Combat scene wall foundation is legal")
 game.sim.apply_global_level("wall",100)
 for b in game.sim.buildings:
  if b!=null:b.age=10
 for i in kinds.size():
  var enemy:Dictionary=final_boss if kinds[i]=="boss" else game.sim.spawn_enemy(0,kinds[i])
  var target:int=i+1
  enemy.pos=game.sim.buildings[target].pos+Vector2(60 if i%2 else -60,0)
  enemy.cooldown=0
  game.sim.attack_building(enemy,target)
  check(enemy.attacking and enemy.facing_left==(i%2==1),"Game-world attack has correct facing: "+kinds[i])
 game.screen="mission"
 game.world_container.visible=true
 game.selected=-1
 game.camera_center=Vector2(6200,2880)
 game.zoom=0.85
 game.apply_camera()
 game.animation_clock=game.sim.elapsed
 game.world.queue_redraw()
 game.queue_redraw()
 await frame()
 root.get_texture().get_image().save_png("res://test-results/combat-art-battle-impact.png")
 for enemy in game.sim.enemies:enemy.attack_left=0.22
 game.world.queue_redraw()
 await frame()
 root.get_texture().get_image().save_png("res://test-results/combat-art-battle-recovery.png")
 game.music_player.stop()
 game.sfx_player.stop()
 game.music_player.stream=null
 game.sfx_player.stream=null
 game.sounds.clear()
 await create_timer(0.2).timeout
 game.queue_free()
 await process_frame
 await process_frame
 print("COMBAT ART RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
