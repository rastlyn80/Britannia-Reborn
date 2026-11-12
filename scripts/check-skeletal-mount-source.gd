# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const Hues := preload("res://Presentation/HumanHue.gd")
const Clips := ["Attack", "Attack2", "Death", "Eat", "Fidget", "Fidget2", "Hit", "Idle", "Run", "Walk"]
const Frame := Vector2i(500, 360)
var checked := 0


func _initialize() -> void:
	create_timer(100.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	var folder: String = get_script().resource_path.get_base_dir()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--study="):
			folder = argument.trim_prefix("--study=")
	var viewport := SubViewport.new()
	viewport.size = Frame
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.6
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(4.8, 2.15, 2.25), Vector3(0., .75, 0.))
	camera.make_current()
	var render := DisplayServer.get_name() != "headless"
	var sheet := Image.create(Frame.x * 3, Frame.y * 4, false, Image.FORMAT_RGB8)
	var shader := load("res://Presentation/SourceSkeletalHorseSurface.gdshader") as Shader if render else null
	var reports := {}
	for row in (4 if render else 2):
		var treatment: String = "original" if row == 0 else "rounded"
		var loader := GLTFDocument.new()
		var state := GLTFState.new()
		assert(loader.append_from_file(folder.path_join("body-793-%s.gltf" % treatment), state) == OK)
		var actor := loader.generate_scene(state)
		viewport.add_child(actor)
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var mesh := actor.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var source := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		assert(rig.get_bone_count() == 34 and source.albedo_texture.get_size() == Vector2(256, 256))
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		if row < 2:
			reports[treatment] = inspect(player, rig, mesh)
		if render:
			if row >= 2:
				var material := ShaderMaterial.new()
				material.shader = shader
				material.set_shader_parameter("albedo_texture", source.albedo_texture)
				material.set_shader_parameter("hue_palette", Hues.palette(0x21))
				material.set_shader_parameter("use_hue", row == 3)
				mesh.set_surface_override_material(0, material)
			for column in 3:
				var selection: Array = [["Idle", .38], ["Walk", .33], ["Death", 1.]][column]
				pose(player, rig, selection[0], selection[1])
				for frame in 4:
					await RenderingServer.frame_post_draw
				var view := viewport.get_texture().get_image()
				assert(view != null and view.get_size() == Frame)
				view.convert(Image.FORMAT_RGB8)
				sheet.blit_rect(view, Rect2i(Vector2i.ZERO, Frame), Vector2i(column * Frame.x, row * Frame.y))
		if row == 1:
			pose(player, rig, "Idle", 0.)
			player.stop()
			rig.reset_bone_poses()
			var scene := PackedScene.new()
			assert(scene.pack(actor) == OK)
			assert(ResourceSaver.save(scene, folder.path_join("skeletal-mount-source.scn"), ResourceSaver.FLAG_COMPRESS) == OK)
		actor.free()
	if render:
		for column in 3:
			var changed := 0
			for y in range(0, Frame.y, 3):
				for x in range(0, Frame.x, 3):
					var original := sheet.get_pixel(column * Frame.x + x, 2 * Frame.y + y)
					var dyed := sheet.get_pixel(column * Frame.x + x, 3 * Frame.y + y)
					if absf(original.r - dyed.r) + absf(original.g - dyed.g) + absf(original.b - dyed.b) > .075:
						changed += 1
			assert(changed > 500)
			print("SKELETAL MOUNT HUE 0x21, view ", column, ": ", changed, " sampled pixels changed")
		assert(sheet.save_png(folder.path_join("original-and-rounded.png")) == OK)
	var receipt := FileAccess.open(folder.path_join("geometry-proof.json"), FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"checks": checked, "treatments": reports, "renderer": DisplayServer.get_name()}, "  "))
	receipt.close()
	print("SKELETAL MOUNT SOURCE: ", checked, " weighted poses across both treatments and all ten original labels")
	quit()


func pose(player: AnimationPlayer, rig: Skeleton3D, clip: String, phase: float) -> void:
	player.stop()
	rig.reset_bone_poses()
	player.play(clip, 0.)
	player.advance(0.)
	player.seek(player.current_animation_length * phase, true)
	rig.force_update_all_bone_transforms()


func inspect(player: AnimationPlayer, rig: Skeleton3D, mesh: MeshInstance3D) -> Dictionary:
	var skin := Ground.skin_points(mesh, rig)
	var report := {}
	for clip: String in Clips:
		assert(player.has_animation(clip))
		var gap := Vector2(INF, -INF)
		for sample in 33:
			pose(player, rig, clip, float(sample) / 32.)
			var box := Geometry.deformed_bounds(mesh, rig)
			assert(box.is_finite() and box.get_longest_axis_size() > 1.15 and box.get_longest_axis_size() < 4.5)
			var floor_gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
			gap.x = minf(gap.x, floor_gap)
			gap.y = maxf(gap.y, floor_gap)
			checked += 1
		report[clip] = {"minimum": gap.x, "maximum": gap.y}
	pose(player, rig, "Idle", .28)
	var anchors := {}
	for bone: String in ["bip01 spine1", "bip01 head", "bip01 l foot", "bip01 r foot",
			"bip01 l finger0", "bip01 r finger0"]:
		var point := rig.to_global(rig.get_bone_global_pose(rig.find_bone(bone)).origin)
		anchors[bone] = [point.x, point.y, point.z]
	report["anchors"] = anchors
	return report
