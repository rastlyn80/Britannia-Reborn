extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var scene = load("res://Main.tscn").instantiate()
 root.add_child(scene)
 scene.set_process(false)
 for child in scene.get_children():
  if child is CanvasLayer: child.visible = false
 var lighting = scene.get_node("DistrictLighting")
 lighting.set_process(false)
 scene.camera.reparent(scene)
 scene.camera.position = Vector3(1607-scene.world.originX,7.5,1620-scene.world.originY)
 scene.camera.look_at(Vector3(1624-scene.world.originX,7.0,1630-scene.world.originY))
 var failures := 0
 var captures := {}
 var suffix := "-compatibility" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else ""
 var output := ProjectSettings.globalize_path("res://../outputs/validation")
 DirAccess.make_dir_recursive_absolute(output)
 for sample in [["afternoon",900.0,0.0,0.0],["rain",900.0,1.0,4.0],["snow",900.0,1.0,4.0],["night",90.0,0.0,12.0]]:
  lighting.cloud_clock = 100.0
  lighting._apply_atmosphere(sample[1],sample[2],sample[3],0.0)
  lighting.receive_server_environment({"weather_type":2 if sample[0] == "snow" else (0 if sample[2] > 0.0 else 255),"density":70 if sample[2] > 0.0 else 0})
  lighting.visual_weather = sample[2]
  lighting._animate_precipitation(0.3)
  for frame in 60: await process_frame
  await RenderingServer.frame_post_draw
  var capture := root.get_texture().get_image()
  captures[sample[0]] = capture
  capture.save_png(output.path_join("environment-"+sample[0]+suffix+".png"))
  print("ENVIRONMENT CAPTURE: ",sample[0]," (controlled server-state fixture)")
 # Compare controlled states, then verify a real interior suppresses precipitation.
 if captures.afternoon.get_pixel(800,100).get_luminance() <= captures.night.get_pixel(800,100).get_luminance()+0.15:
  push_error("Day/night sky contrast missing")
  failures += 1
 lighting.cloud_clock = 600.0
 lighting._apply_atmosphere(900.0,0.0,0.0,0.0)
 lighting.precipitation.visible = false
 for frame in 60: await process_frame
 await RenderingServer.frame_post_draw
 var moved := root.get_texture().get_image()
 var difference := 0.0
 for y in range(0,300,10):
  for x in range(0,1200,10):
   difference += absf(moved.get_pixel(x,y).get_luminance()-captures.afternoon.get_pixel(x,y).get_luminance())
 if difference/3600.0 < 0.0001:
  push_error("Cloud clock did not change rendered sky")
  failures += 1
 scene.camera.position = Vector3(1610-scene.world.originX,1.8,1588-scene.world.originY)
 scene.camera.look_at(Vector3(1616-scene.world.originX,1.5,1588-scene.world.originY))
 for frame in 4: await physics_frame
 lighting.visual_weather = 1.0
 lighting.shelter_check = 0.0
 lighting._animate_precipitation(0.3)
 if not lighting.sheltered or lighting.precipitation.visible:
  push_error("Real building ceiling failed to shelter precipitation")
  failures += 1
 print("ENVIRONMENT GPU: day/night contrast, animated clouds, real ceiling shelter; failures=",failures)
 scene.free()
 for frame in 4: await process_frame
 quit(failures)
