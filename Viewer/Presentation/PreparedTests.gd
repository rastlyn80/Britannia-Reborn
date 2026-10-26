extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
 else:print("PASS ",label)
func _initialize()->void:
 var data:=preload("res://Presentation/PreparedDistrict.gd").new()
 data.origin=Vector2i(1088,1408)
 data.land=PackedInt32Array([7,-5,8,20])
 data.statics=PackedInt32Array([123,63|(17<<6),-12,456])
 var decoded:=data.decode()
 check(decoded.terrain[0]=={"x":1088,"y":1408,"id":7,"z":-5},"Packed terrain preserves native origin and negative elevation")
 check(decoded.terrain[1].x==1089 and decoded.terrain[1].y==1408,"Packed terrain preserves row ordering")
 check(decoded.statics[0]=={"x":1151,"y":1425,"id":123,"z":-12,"hue":456},"Packed statics preserve relative position, ID, signed Z and hue")
 var surface:=preload("res://Presentation/MovementSurface.gd").new()
 surface.add_chunk(decoded)
 surface.dynamic_items[1]={"id":123}
 check(surface.terrain.size()==2 and surface.statics.size()==1,"Streamed source installs only its own cells")
 surface.remove_chunk(data.origin)
 check(surface.terrain.is_empty() and surface.statics.is_empty() and surface.dynamic_items.has(1),"Source eviction releases cells and preserves native dynamic ownership")
 var root:=Node3D.new()
 var material:=StandardMaterial3D.new()
 for at in [Vector3(1,2,3),Vector3(5,2,3)]:
  var parent:=Node3D.new();parent.position=at;root.add_child(parent)
  var node:=MeshInstance3D.new();node.mesh=BoxMesh.new();node.material_override=material;parent.add_child(node)
 var sign:=Node3D.new();sign.set_meta("kind","sign");root.add_child(sign)
 var sign_mesh:=MeshInstance3D.new();sign_mesh.mesh=BoxMesh.new();sign.add_child(sign_mesh)
 var body:=StaticBody3D.new();root.add_child(body)
 preload("res://Presentation/CompactDistrict.gd").new().apply(root)
 var instances:Array=[]
 for node in root.get_children():
  if node is MultiMeshInstance3D:instances.append(node)
 check(instances.size()==1 and instances[0].instance_data.size()==24,"Offline compaction instances equal geometry/materials")
 check(Vector3(instances[0].instance_data[15],instances[0].instance_data[19],instances[0].instance_data[23])==Vector3(5,2,3),"Instancing preserves complete source placement")
 check(sign_mesh.mesh!=null and body.get_parent()==root,"Compaction preserves native sign anchors and physical bodies")
 check(root.get_child_count()==3,"Compaction removes empty model nodes rather than hiding them")
 preload("res://Presentation/CompactDistrict.gd").own(root,root)
 var packed:=PackedScene.new();packed.pack(root);data.scene=packed
 var path:="user://prepared-test.res"
 check(ResourceSaver.save(data,path,ResourceSaver.FLAG_COMPRESS)==OK,"Prepared scenes and packed source serialize together")
 var restored:Resource=load(path)
 check(restored.decode()==decoded,"Prepared resource reload preserves exact native source data")
 var copy:Node3D=restored.scene.instantiate()
 check(copy.get_child_count()==3,"Prepared scene reload retains compact rendering and collision structure")
 var instance_values:=PackedFloat32Array()
 for child in copy.get_children():
  if child is MultiMeshInstance3D:instance_values=child.instance_data
 check(instance_values.size()==24 and instance_values[15]==5 and instance_values[19]==2 and instance_values[23]==3,"Headless baking preserves exported instance matrices through disk reload")
 copy.free();root.free();DirAccess.remove_absolute(path)
 var dependencies: Dictionary={}
 preload("res://Presentation/BakeStreaming.gd").dependency_signature("res://Presentation/BakeStreaming.gd",dependencies)
 check(dependencies.has("res://Presentation/CollisionBuilder.gd") and dependencies.has("res://Presentation/InstancedPatch.gd") and dependencies.has("res://Presentation/TerrainSurface.gd"),"Bake invalidation follows transitive collision, instancing and terrain rule dependencies")
 print("PREPARED TESTS: ",checks," checks / ",failures," failures")
 quit(1 if failures else 0)
