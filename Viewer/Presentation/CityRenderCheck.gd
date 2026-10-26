extends SceneTree
# Owned-data graphical check, separate from native multiplayer tests. In this
# reference view the wall probe is entirely inside an installed detail district.
var scene: Node3D
var instances_checked:=0
func check_instances(node: Node) -> bool:
 if node.get_script()==preload("res://Presentation/InstancedPatch.gd"):
  if node.multimesh==null:return false
  for i in [0,node.multimesh.instance_count-1]:
   var a: PackedFloat32Array=node.instance_data
   var j: int=i*12
   var expected:=Transform3D(Basis(Vector3(a[j],a[j+4],a[j+8]),Vector3(a[j+1],a[j+5],a[j+9]),Vector3(a[j+2],a[j+6],a[j+10])),Vector3(a[j+3],a[j+7],a[j+11]))
   if not node.multimesh.get_instance_transform(i).is_equal_approx(expected):return false
   instances_checked+=1
 for child in node.get_children():
  if not check_instances(child):return false
 return true
func _initialize() -> void: call_deferred("run")
func snapshot() -> Image:
 for frame in 8: await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run() -> void:
 root.size = Vector2i(1280,800)
 scene = load("res://Main.tscn").instantiate()
 root.add_child(scene)
 var started := Time.get_ticks_msec()
 while not scene.world_ready:
  if Time.get_ticks_msec()-started>180000: push_error("City render startup timeout"); quit(1); return
  await process_frame
 while not scene.city_stream.settled():await process_frame
 if not check_instances(scene.city_stream) or instances_checked==0:
  push_error("Prepared GPU instance transforms differ from saved CPU placement");quit(1);return
 print("INSTANCE GPU PASS: ",instances_checked," first/last matrices match native prepared placement")
 scene.set_process(false)
 # Compare ownership, not temporal AA/AO history or moving sky irradiance.
 root.use_taa = false
 var lighting: Node3D = scene.get_node("DistrictLighting")
 lighting.set_process(false)
 lighting.environment.ssao_enabled = false
 # Detach from the spring arm so its internal physics cannot move the probe.
 scene.camera.reparent(scene)
 scene.camera.global_position = scene.entity_point(1599,1567,20)+Vector3(-2.4,2.8,5.0)
 scene.camera.look_at(scene.entity_point(1599,1567,20)+Vector3.UP)
 var combined: Image = await snapshot()
 scene.city_stream.get_child(0).hide()
 var near_only: Image = await snapshot()
 var changed := 0
 for y in range(320,390):
  for x in range(120,480):
   var difference := combined.get_pixel(x,y)-near_only.get_pixel(x,y)
   if maxf(absf(difference.r),maxf(absf(difference.g),absf(difference.b)))>8.0/255.0: changed+=1
 var directory := ProjectSettings.globalize_path("res://../outputs/validation/")
 var renderer := RenderingServer.get_current_rendering_method()
 combined.save_png(directory+"city-mask-"+renderer+".png")
 near_only.save_png(directory+"city-mask-near-only-"+renderer+".png")
 scene.free()
 if changed>0:
  push_error("Distant architecture changed %d / 25200 pixels on an installed nearby wall" % changed)
  quit(1)
  return
 print("CITY MASK GPU PASS: 25200 nearby wall pixels unchanged within 8/255 when distant geometry is hidden / ",renderer)
 quit()
