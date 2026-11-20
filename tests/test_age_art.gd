extends SceneTree

const Art = preload("res://scripts/frontier_art.gd")
const Sim = preload("res://scripts/simulation.gd")
const Wall = preload("res://scripts/wall_art.gd")
const CELL = Vector2i(150,190)
var failures := 0
var checks := 0

class AgeGallery extends Node2D:
 var age := 1
 func _draw() -> void:
  draw_rect(Rect2(0,0,1200,400),Color("181710"))
  for index in Art.BUILDING_NAMES.size():
   var x: float = index * CELL.x
   if Art.BUILDING_NAMES[index] == "wall":
    Wall.piece(self,Vector2(x+75,145),{},Color.WHITE,age)
   else:
    Art.building(self,index,Vector2(x+75,155),0.55,Color.WHITE,age)
   Art.building_icon(self,index,Rect2(x+25,195,100,72),age)
  for index in Art.RESEARCH_ICONS.size():
   Art.research_icon(self,Art.RESEARCH_ICONS[index],Rect2(index*CELL.x+50,300,52,52),age)

func _init() -> void:
 call_deferred("run")

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  printerr("FAIL AGE ART: ",label)

func inspect(image: Image, rect: Rect2i, bg: Color, age: int, subject: String, fingerprints: Dictionary) -> void:
 var signature := hash(image.get_region(rect).get_data())
 var seen: Dictionary = fingerprints.get(subject,{})
 var painted := 0
 var first := rect.end
 var last := rect.position
 for y in range(rect.position.y,rect.end.y):
  for x in range(rect.position.x,rect.end.x):
   var c := image.get_pixel(x,y)
   if absf(c.r-bg.r)+absf(c.g-bg.g)+absf(c.b-bg.b)>0.1:
    var point := Vector2i(x,y)
    painted += 1
    first = first.min(point)
    last = last.max(point)
 # A longbow is an open silhouette. Check the painted extent and contrast on
 # the full 52px Workshop control; subsampling can skip individual bowstrings.
 var span := last-first+Vector2i.ONE
 var visible := painted>320
 if subject.begins_with("research "):
  visible = painted>=200 and mini(span.x,span.y)>=17 and maxi(span.x,span.y)>=32
 check(visible,"%s is readable at age %d (%d contrasting pixels, %s extent)"%[subject,age,painted,span])
 check(not seen.has(signature), "%s has distinct age %d artwork"%[subject,age])
 seen[signature] = true
 fingerprints[subject] = seen

func run() -> void:
 root.size = Vector2i(1200,400)
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 var gallery := AgeGallery.new()
 root.add_child(gallery)
 var seen := {}
 for age in range(1,Sim.AGE_NAMES.size()+1):
  gallery.age = age
  gallery.queue_redraw()
  await process_frame
  await process_frame
  await RenderingServer.frame_post_draw
  var image: Image = root.get_texture().get_image()
  var bg := image.get_pixel(1199,399)
  check(Art.age_sheet != null and Art.age_regions.size() == 8, "Packaged building atlas loaded for "+Sim.AGE_NAMES[age-1])
  for i in Art.BUILDING_NAMES.size():
   check(Art.age_regions[i].has_area(), "Source bounds exist for %s in %s"%[Art.BUILDING_NAMES[i],Sim.AGE_NAMES[age-1]])
   inspect(image,Rect2i(i*CELL.x,10,CELL.x,175),bg,age,"world "+Art.BUILDING_NAMES[i],seen)
   inspect(image,Rect2i(i*CELL.x,190,CELL.x,85),bg,age,"catalogue "+Art.BUILDING_NAMES[i],seen)
  var icons_this_age := {}
  for i in Art.RESEARCH_ICONS.size():
   var rect := Rect2i(i*CELL.x+50,300,52,52)
   inspect(image,rect,bg,age,"research "+Art.RESEARCH_ICONS[i],seen)
   icons_this_age[hash(image.get_region(rect).get_data())] = true
  check(Art.research_sheet != null and icons_this_age.size() == Sim.TRACKS.size(),"All six Workshop projects have their own painted icon at "+Sim.AGE_NAMES[age-1])
 gallery.queue_free()
 await process_frame
 print("AGE ART RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
