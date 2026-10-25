extends SceneTree
var output := ""
func _initialize() -> void: call_deferred("run")
func frame() -> Image:
 for i in 3: await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run() -> void:
 output = ProjectSettings.globalize_path("res://../outputs/validation")
 var stage := Node3D.new()
 root.add_child(stage)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-45,-30,0)
 stage.add_child(sun)
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_COLOR
 environment.environment.background_color = Color("506270")
 environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color = Color.WHITE
 environment.environment.ambient_light_energy = 0.6
 stage.add_child(environment)
 var camera := Camera3D.new()
 stage.add_child(camera)
 camera.current = true
 var reconstruction = preload("res://Presentation/Reconstruction.gd").new()
 var failures := 0
 var realtime_failures := 0
 for kind in ["tree","grass","water"]:
  reconstruction.nature_materials.clear()
  var plant: Node3D
  var materials: Array = []
  if kind == "water":
   var water := MeshInstance3D.new()
   var plane := PlaneMesh.new()
   plane.size = Vector2(4,4)
   water.mesh = plane
   var mat := ShaderMaterial.new()
   mat.shader = preload("res://Presentation/Water.gdshader")
   water.material_override = mat
   materials.append(mat)
   plant = water
   camera.position = Vector3(3,3,4)
   camera.look_at(Vector3.ZERO)
  else:
   plant = reconstruction.fitted("Nature/CommonTree_1.gltf" if kind == "tree" else "Nature/Grass_Wispy_Short.gltf",Vector3(3.2,5.8,3.2) if kind == "tree" else Vector3(0.65,0.3,0.65))
   materials = reconstruction.nature_materials.values()
   camera.position = Vector3(7,4,9) if kind == "tree" else Vector3(0.8,0.5,1.0)
   camera.look_at(Vector3(0,2.7,0) if kind == "tree" else Vector3(0,0.15,0))
  stage.add_child(plant)
  var anchored := plant.transform
  for mat in materials: mat.set_shader_parameter("time_override",0.0)
  var first := await frame()
  for mat in materials: mat.set_shader_parameter("time_override",1.7)
  var second := await frame()
  first.save_png(output.path_join("wind-test-"+kind+"-0.png"))
  second.save_png(output.path_join("wind-test-"+kind+"-1.png"))
  var changed := 0
  for y in range(0,first.get_height(),2):
   for x in range(0,first.get_width(),2):
    var a := first.get_pixel(x,y)
    var b := second.get_pixel(x,y)
    if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.025: changed += 1
  var ok: bool = changed > 80 and anchored == plant.transform
  if not ok: failures += 1
  print(("PASS " if ok else "FAIL ")+kind+" actual GPU motion; changed sample pixels "+str(changed)+"; root remains anchored")
  for mat in materials: mat.set_shader_parameter("time_override",-1.0)
  var live_first := await frame()
  await create_timer(0.5).timeout
  var live_second := await frame()
  var live_changed := 0
  for y in range(0,live_first.get_height(),2):
   for x in range(0,live_first.get_width(),2):
    var a := live_first.get_pixel(x,y)
    var b := live_second.get_pixel(x,y)
    if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>0.025: live_changed+=1
  var live_ok: bool = live_changed>40 and anchored==plant.transform
  if not live_ok: realtime_failures+=1
  print(("PASS " if live_ok else "FAIL ")+kind+" running-clock animation; changed sample pixels "+str(live_changed))
  plant.free()
 print("ENVIRONMENT GPU: %d passed / 3 total" % [3-failures])
 print("REALTIME GPU: %d passed / 3 total" % [3-realtime_failures])
 stage.queue_free()
 for i in 4: await process_frame
 quit(failures+realtime_failures)
