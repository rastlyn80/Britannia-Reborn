extends SceneTree
var output := ""
func _initialize() -> void: call_deferred("capture")
func image_now(path: String) -> Image:
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 image.save_png(output.path_join(path))
 return image
func camera_at(scene: Node3D, at: Vector3, target: Vector3) -> void:
 scene.camera.global_position = at
 scene.camera.look_at(target)
 for i in 24: await process_frame
func capture() -> void:
 output = ProjectSettings.globalize_path("res://../outputs/validation")
 var scene = load("res://Main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 for child in scene.get_children():
  if child is CanvasLayer: child.visible = false
 scene.camera.reparent(scene)
 await camera_at(scene,scene.entity_point(1605,1591,20)+Vector3(0,1.7,0),scene.entity_point(1598,1591,30))
 await image_now("visual-street.png")
 await camera_at(scene,scene.entity_point(1630,1604,85),scene.entity_point(1617,1586,10))
 await image_now("visual-roof-corners.png")
 await camera_at(scene,scene.entity_point(1620,1627,65),scene.entity_point(1609,1615,0))
 await image_now("visual-shoreline.png")
 await camera_at(scene,scene.entity_point(1606,1618,65),scene.entity_point(1593,1608,30))
 for frame in 30:
  for mat in scene.reconstruction.nature_materials.values(): mat.set_shader_parameter("time_override",frame*0.1)
  if scene.reconstruction.water_material: scene.reconstruction.water_material.set_shader_parameter("time_override",frame*0.1)
  for i in 2: await process_frame
  await image_now("nature-frame-%02d.png" % frame)
 await camera_at(scene,scene.entity_point(1614,1622,10),scene.entity_point(1612,1615,0))
 for frame in 30:
  if scene.reconstruction.water_material: scene.reconstruction.water_material.set_shader_parameter("time_override",frame*0.1)
  for i in 2: await process_frame
  await image_now("water-frame-%02d.png" % frame)
 print("VISUAL CAPTURE: street, roof/corners and thirty forest and thirty water animation frames")
 scene.queue_free()
 for i in 5: await process_frame
 quit()
