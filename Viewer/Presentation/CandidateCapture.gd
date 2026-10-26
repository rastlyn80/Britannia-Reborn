extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(320,320)
 var stage:=Node3D.new();root.add_child(stage)
 var environment:=WorldEnvironment.new();var settings:=Environment.new()
 settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("303941")
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("d8e0ed");settings.ambient_light_energy=0.7
 environment.environment=settings;stage.add_child(environment)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-35,0);sun.light_energy=1.2;stage.add_child(sun)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.1;stage.add_child(camera)
 camera.position=Vector3(2,1.8,2.8);camera.look_at(Vector3(0,0.6,0))
 var recon:=preload("res://Presentation/Reconstruction.gd").new()
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Art/Quaternius/Props/manifest.json"))
 var folder:=ProjectSettings.globalize_path("res://../outputs/art-review/candidates");DirAccess.make_dir_recursive_absolute(folder)
 var bounds: Dictionary={}
 var candidates: Array=manifest.models.duplicate()
 candidates.append_array(["Village/Window_Wide_Flat1","Village/WindowShutters_Wide_Flat_Open","Village/Prop_Vine1","Village/Door_2_Flat"])
 for name in candidates:
  var path: String=(name if "/" in name else "Props/"+name)+".gltf"
  var sample: Node3D=recon.fitted(path,Vector3.ONE)
  sample.free()
  var box: AABB=recon.bounds[path]
  var dimensions: Vector3=box.size/box.size[box.size.max_axis_index()]*1.5
  var model: Node3D=recon.fitted(path,dimensions);stage.add_child(model)
  bounds[name]={"size":[box.size.x,box.size.y,box.size.z],"origin":[box.position.x,box.position.y,box.position.z]}
  for frame in 3:await process_frame
  await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png(folder.path_join(str(name).replace("/","_")+".png"))==OK)
  model.free()
 var file:=FileAccess.open(folder.path_join("bounds.local.json"),FileAccess.WRITE);file.store_string(JSON.stringify(bounds));file.close()
 stage.free();await process_frame;print("CANDIDATE CAPTURE PASS: ",candidates.size()," licensed models");quit()
