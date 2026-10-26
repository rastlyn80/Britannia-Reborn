extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var data:=preload("res://Presentation/AtlasData.gd").new()
 if not data.open("res://../outputs/britain/atlas.json"):quit(1);return
 var land:=0
 var statics:=0
 var nodes:=0
 for entry in data.manifest.chunks:
  var at:=Vector2i(entry.x,entry.y)
  var path:="res://../outputs/britain/prepared/near_%d_%d.res" % [at.x,at.y]
  var prepared: Resource=load(path)
  if prepared==null:push_error("Missing prepared district "+path);quit(1);return
  var decoded: Dictionary=prepared.decode()
  var original: Dictionary=data.chunk(at)
  if decoded!=original:push_error("Prepared native source differs at "+str(at));quit(1);return
  var scene: Node3D=prepared.scene.instantiate()
  if int(scene.get_meta("collision_triangles",0))<=0:push_error("Missing prepared collision");quit(1);return
  var incremental: Node3D=prepared.root_scene.instantiate()
  for part in prepared.parts:incremental.add_child(part.instantiate())
  if incremental.get_child_count()!=scene.get_child_count() or incremental.get_meta("collision_triangles",0)!=scene.get_meta("collision_triangles",0):
   push_error("Incremental prepared scene differs from complete scene");quit(1);return
  for i in scene.get_child_count():
   var expected: Node3D=scene.get_child(i)
   var actual: Node3D=incremental.get_child(i)
   if expected.get_class()!=actual.get_class() or not expected.transform.is_equal_approx(actual.transform):
    push_error("Incremental prepared placement differs from complete scene");quit(1);return
  incremental.free()
  nodes+=scene.get_child_count()
  scene.free()
  land+=decoded.terrain.size();statics+=decoded.statics.size()
  await process_frame
 print("PREPARED PARITY PASS: ",land," terrain / ",statics," statics / ",nodes," top-level compact nodes across 88 districts")
 quit()
