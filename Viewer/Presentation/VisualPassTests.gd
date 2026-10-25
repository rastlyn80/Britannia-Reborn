extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, title: String) -> void:
 checks += 1
 if not ok: failures += 1
 print(("PASS " if ok else "FAIL ")+title)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var facade = preload("res://Presentation/Facade.gd").new()
 var catalog := {"1":{"kind":"corner","axis":"x"},"2":{"kind":"wall","axis":"x"},"3":{"kind":"wall","axis":"y"}}
 var complete := true
 for origin in [Vector2i.ZERO,Vector2i(2100,3200),Vector2i(-120,680)]:
  for sx in [-1,1]:
   for sy in [-1,1]:
    var world := {"staticData":{"1":{"height":20},"2":{"height":20},"3":{"height":20}},"statics":[{"id":1,"x":origin.x,"y":origin.y,"z":20},{"id":2,"x":origin.x+sx,"y":origin.y,"z":20},{"id":3,"x":origin.x,"y":origin.y+sy,"z":20}]}
    facade.index(JSON.parse_string(JSON.stringify(world)),catalog)
    complete = complete and facade.corners[0].directions.size() == 2
    var corner: Node3D = facade.corner(4,facade.corners[0],"plaster")
    for point in [Vector3.ZERO,Vector3(sx*0.5,0,0),Vector3(0,0,sy*0.5)]:
     for height in [0.01,2.0,3.99]:
      var covered := false
      for mesh in corner.get_children(): covered = covered or (mesh.transform*mesh.get_aabb()).has_point(point+Vector3(0,height,0))
      complete = complete and covered
    corner.free()
 var implicit_closed := true
 for axis_y in [false,true]:
  for direction in [-1,1]:
   var offset := Vector2i(0,direction) if axis_y else Vector2i(direction,0)
   var implicit_world := {"staticData":{"2":{"height":20},"3":{"height":20}},"statics":[{"id":3 if axis_y else 2,"x":520,"y":870,"z":20},{"id":2 if axis_y else 3,"x":520+offset.x,"y":870+offset.y,"z":20}]}
   facade.index(implicit_world,catalog)
   var panel: Node3D = facade.panel(4,false,facade.plans[0],"plaster")
   if axis_y: panel.rotation.y = PI/2
   var covered := false
   var endpoint := Vector3(offset.x*0.9,2,offset.y*0.9)
   for mesh in panel.get_children(): covered = covered or (panel.transform*mesh.transform*mesh.get_aabb()).has_point(endpoint)
   implicit_closed = implicit_closed and covered
   panel.free()
 check(implicit_closed,"perpendicular wall ends meet without an explicit corner record in either orientation")
 check(complete,"corner arms seal centre and neighboring wall planes in all rotations and translated regions")
 var world := {"elevationScale":0.2,"staticData":{"2":{"height":20}},"statics":[{"id":2,"x":0,"y":0,"z":0},{"id":2,"x":0,"y":0,"z":21},{"id":2,"x":3,"y":0,"z":0}]}
 facade.index(world,catalog)
 check(is_equal_approx(facade.plans[0].height_extension,0.2),"one-Z storey seam closes without moving source anchors")
 check(facade.plans[2].height_extension == 0,"isolated wall does not grow into an intentional opening")
 var reconstruction = preload("res://Presentation/Reconstruction.gd").new()
 var arch_world := {"staticData":{},"statics":[{"id":320,"x":0,"y":0,"z":20},{"id":317,"x":0,"y":3,"z":20}]}
 reconstruction.index(arch_world)
 check(reconstruction.groups[0].size == Vector2(1,4) and reconstruction.groups[0].indices.size() == 2,"separated complementary arch ends make one complete wide entrance")
 arch_world.statics.append({"id":311,"x":0,"y":1,"z":20})
 reconstruction.index(arch_world)
 check(not reconstruction.groups.has(0),"arch assembly cannot bridge an intervening source wall")
 var tree: Node3D = reconstruction.fitted("Nature/CommonTree_1.gltf",Vector3(3.2,5.8,3.2))
 var grass: Node3D = reconstruction.fitted("Nature/Grass_Wispy_Short.gltf",Vector3(0.65,0.3,0.65))
 var bounded: bool = reconstruction.nature_materials.size() > 0
 for mat in reconstruction.nature_materials.values():
  bounded = bounded and float(mat.get_shader_parameter("amplitude")) <= 0.14 and float(mat.get_shader_parameter("plant_height")) > 0
 check(bounded,"nature wind is bounded in metres and uses height-weighted materials")
 tree.free()
 if grass: grass.free()
 reconstruction.show_boundary_fragments = true
 reconstruction.nature_materials.clear()
 tree = reconstruction.fitted("Nature/CommonTree_1.gltf",Vector3(3.2,5.8,3.2))
 var stable := true
 for mat in reconstruction.nature_materials.values(): stable = stable and mat.get_shader_parameter("amplitude") == 0.0
 check(stable,"north-up source comparison can disable nature deformation")
 tree.free()
 print("VISUAL PASS: %d passed / %d total" % [checks-failures,checks])
 quit(failures)
