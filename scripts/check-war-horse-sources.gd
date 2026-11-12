# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/check-dark-horse-sources.gd"

const Studio := preload("res://Presentation/ItemStudio.gd")
const Frame := Vector2i(410, 290)
const Bodies := [117, 118, 119, 120, 121, 115, 291]


func run() -> void:
	var folder: String = get_script().resource_path.get_base_dir()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--study="):
			folder = argument.trim_prefix("--study=")
	var output := folder.path_join("prepared")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var viewport := SubViewport.new()
	viewport.size = Frame
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	Studio.studio_lights(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.7
	viewport.add_child(camera)
	camera.make_current()
	camera.look_at_from_position(Vector3(5.2, 2.25, 2.55), Vector3(0., .91, .04))
	var sheet := Image.create(Frame.x * 4, Frame.y * 2, false, Image.FORMAT_RGB8)
	var reports := {}
	for body: int in Bodies:
		var source := folder.path_join("body-%d-rounded.gltf" % body)
		var loader := GLTFDocument.new()
		var state := GLTFState.new()
		assert(loader.append_from_file(source, state) == OK)
		var actor := loader.generate_scene(state)
		viewport.add_child(actor)
		var mesh := actor.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var space := actor.find_child("SourceSpace", true, false) as Node3D
		var source_transform := space.transform
		if body == 291:
			reports[body] = verify_pack(mesh, rig, player)
		else:
			reports[body] = review(actor)
		if body in [117, 118, 291]:
			player.stop()
			rig.reset_bone_poses()
			space.transform = source_transform
			var names := {117: "silver-steed-source.scn", 118: "war-horse-source.scn", 291: "pack-horse-source.scn"}
			var scene := PackedScene.new()
			assert(scene.pack(actor) == OK and ResourceSaver.save(scene, output.path_join(names[body]), ResourceSaver.FLAG_COMPRESS) == OK)
		if body in [115, 119, 120, 121]:
			var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
			assert(material.albedo_texture.get_image().save_png(output.path_join("horse-%d.png" % body)) == OK)
		if DisplayServer.get_name() != "headless":
			player.play("Walk", 0.)
			player.advance(0.)
			player.seek(player.current_animation_length * .38, true)
			for frame in 4:
				await RenderingServer.frame_post_draw
			var picture := viewport.get_texture().get_image()
			assert(picture != null and picture.get_size() == Frame)
			picture.convert(Image.FORMAT_RGB8)
			var row := Bodies.find(body)
			sheet.blit_rect(picture, Rect2i(Vector2i.ZERO, Frame), Vector2i((row % 4) * Frame.x, floori(float(row) / 4.) * Frame.y))
		actor.free()
	if DisplayServer.get_name() != "headless":
		assert(sheet.save_png(folder.path_join("original-horse-coats.png")) == OK)
	var file := FileAccess.open(folder.path_join("engine-source-proof.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"poses": checked, "bodies": reports}, "  "))
	file.close()
	print("SOURCE HORSE RIGS: ", checked, " weighted samples on seven original atlas and rig combinations")
	quit()


func verify_pack(mesh: MeshInstance3D, rig: Skeleton3D, player: AnimationPlayer) -> Dictionary:
	assert(rig.get_bone_count() == 38 and mesh.mesh.get_surface_count() == 2)
	var joint := rig.find_bone("equines_horse_pack")
	assert(joint >= 0 and rig.get_bone_name(rig.get_bone_parent(joint)) == "bip01 spine")
	var geometry := mesh.mesh.surface_get_arrays(1)
	var indices: PackedInt32Array = geometry[Mesh.ARRAY_INDEX]
	var vertices: PackedVector3Array = geometry[Mesh.ARRAY_VERTEX]
	var weights: PackedFloat32Array = geometry[Mesh.ARRAY_WEIGHTS]
	var bones: PackedInt32Array = geometry[Mesh.ARRAY_BONES]
	assert(indices.size() == 36 * 3)
	for vertex in vertices.size():
		var bind := bones[vertex * 4]
		var bone := mesh.skin.get_bind_bone(bind)
		if bone < 0:
			bone = rig.find_bone(mesh.skin.get_bind_name(bind))
		assert(bone == joint and is_equal_approx(weights[vertex * 4], 1.0))
		for offset in range(1, 4):
			assert(is_zero_approx(weights[vertex * 4 + offset]))
	var points := Ground.skin_points(mesh, rig)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var cargo_range := 0.
	for clip: String in Clips:
		player.stop()
		player.play(clip, 0.)
		player.advance(0.)
		var origin := rig.get_bone_global_pose(joint).origin
		for frame in 33:
			player.seek(player.current_animation_length * float(frame) / 32., true)
			rig.force_update_all_bone_transforms()
			assert(is_finite(Ground.minimum_plane_gap(points, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)))
			cargo_range = maxf(cargo_range, origin.distance_to(rig.get_bone_global_pose(joint).origin))
			checked += 1
	assert(cargo_range > .10)
	return {"cargo_joint": joint, "triangles": 36, "sampled_cargo_displacement": cargo_range}
