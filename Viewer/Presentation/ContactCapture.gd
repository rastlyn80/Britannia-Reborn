extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	for child in scene.get_children():
		if child is CanvasLayer: child.visible = false
	scene.camera.reparent(scene)
	var views := [
		["tavern-floor-stable",Vector3(1616,1.7,1590),Vector3(1612,0.4,1587)],
		["basement-repaired",Vector3(1619.5,-2.35,1589.5),Vector3(1616,-2.6,1584)],
		["stairs-repaired",Vector3(1622,-1.7,1580),Vector3(1617,-2.0,1576.8)],
		["basement-bedroom-repaired",Vector3(1625,-2.35,1589),Vector3(1628,-2.4,1583)],
		["upper-floor-repaired",Vector3(1587,9.6,1589),Vector3(1586,8.2,1585)],
		["terrain-peaks-repaired",Vector3(1603,10,1614),Vector3(1595,6,1609)],
		["ceiling-repaired",Vector3(1619.3,1.65,1587),Vector3(1620,2.5,1583)]
	]
	var output := ProjectSettings.globalize_path("res://../outputs/validation")
	for view in views:
		scene.camera.global_position = Vector3(view[1].x-scene.world.originX,view[1].y,view[1].z-scene.world.originY)
		scene.camera.look_at(Vector3(view[2].x-scene.world.originX,view[2].y,view[2].z-scene.world.originY))
		for i in 30: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(view[0]+".png"))
	var actor := preload("res://Presentation/Avatar.gd").new()
	actor.position = scene.entity_point(1618,1576,-11)
	scene.add_child(actor)
	scene.camera.global_position = scene.entity_point(1621,1579,-10)+Vector3(0,1.0,0)
	scene.camera.look_at(actor.global_position+Vector3.UP*0.9)
	for i in 80:
		actor.animate(true,-PI/2,1.0/60,1.02)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("stairs-foot-contact.png"))
	print("CONTACT CAPTURE: floor repairs ",scene.reconstruction.floors.repairs,"; ceilings ",scene.interior_shell.ceilings.size(),"; wall caps ",scene.interior_shell.wall_caps.size(),"; corner audit ",scene.reconstruction.facade.audit(),"; natural peak repairs ",scene.terrain_surface.peak_repairs)
	scene.queue_free()
	for i in 5: await process_frame
	quit()
