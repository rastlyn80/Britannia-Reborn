extends SceneTree

func _initialize() -> void: call_deferred("run")

func difference(a: Image,b: Image) -> float:
	a.resize(320,200)
	b.resize(320,200)
	var sum := 0.0
	for y in range(100,200):
		for x in 320:
			var delta := a.get_pixel(x,y)-b.get_pixel(x,y)
			sum += (absf(delta.r)+absf(delta.g)+absf(delta.b))/3
	return sum/32000

func run() -> void:
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	for child in scene.get_children():
		if child is CanvasLayer: child.visible = false
	for material in scene.reconstruction.nature_materials.values(): material.set_shader_parameter("time_override",0.0)
	if scene.reconstruction.water_material: scene.reconstruction.water_material.set_shader_parameter("time_override",0.0)
	scene.camera.reparent(scene)
	var output := ProjectSettings.globalize_path("res://../outputs/validation")
	var views := [
		["stable-tavern",Vector3(1616,2.7,1590),Vector3(1612,0.4,1587)],
		["stable-doorway",Vector3(1580,10,1594),Vector3(1585,8.1,1592)],
		["stable-banks",Vector3(1607,5,1620),Vector3(1623,7,1627)]
	]
	var failures := 0
	for view in views:
		var position: Vector3 = view[1]-Vector3(scene.world.originX,0,scene.world.originY)
		var target: Vector3 = view[2]-Vector3(scene.world.originX,0,scene.world.originY)
		scene.camera.position = position
		scene.camera.look_at(target)
		for i in 48: await process_frame
		await RenderingServer.frame_post_draw
		var before := root.get_texture().get_image()
		if view[0] == "stable-doorway":
			var pixel: Vector2 = scene.camera.unproject_position(Vector3(1583.4226-scene.world.originX,8,1589.49037-scene.world.originY))
			var color := before.get_pixelv(Vector2i(pixel))
			var pale := minf(color.r,minf(color.g,color.b)) > 0.5
			print("DOORWAY CAP REGRESSION: ","FAIL" if pale else "PASS", "; floor pixel ",color)
			if pale: failures += 1

		before.save_png(output.path_join(view[0]+".png"))
		for i in 24:
			scene.camera.position = position+Vector3(sin(i*TAU/24)*0.12,0,0)
			scene.camera.look_at(target)
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(view[0]+"-%02d.png" % i))
		scene.camera.position = position
		scene.camera.look_at(target)
		for i in 48: await process_frame
		await RenderingServer.frame_post_draw
		var error := difference(before,root.get_texture().get_image())
		print("STABILITY ",view[0],": return-view floor RGB difference ",error)
		if error > 0.025: failures += 1
	scene.free()
	for i in 4: await process_frame
	quit(failures)
