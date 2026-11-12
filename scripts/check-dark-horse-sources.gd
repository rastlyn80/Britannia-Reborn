# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const Clips := ["Idle", "Walk", "Run", "Attack", "Hit", "Death", "Fidget", "Eat"]
const Joints := ["bip01 spine1", "bip01 head", "bip01 neck2", "bip01 tail1",
	"bip01 r finger0", "bip01 l finger0", "bip01 r toe0", "bip01 l toe0"]
var checked := 0


func _initialize() -> void:
	create_timer(80.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	var directory: String = get_script().resource_path.get_base_dir()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--study="):
			directory = argument.trim_prefix("--study=")
	var result := {}
	for form: String in ["nightmare", "firesteed"]:
		result[form] = {}
		for style: String in ["original", "rounded"]:
			var path := directory.path_join("%s-%s.gltf" % [form, style])
			var state := GLTFState.new()
			var loader := GLTFDocument.new()
			assert(loader.append_from_file(path, state) == OK)
			var actor := loader.generate_scene(state)
			root.add_child(actor)
			if style == "rounded" and "--pack" in OS.get_cmdline_user_args():
				var packed := PackedScene.new()
				assert(packed.pack(actor) == OK)
				assert(ResourceSaver.save(packed, directory.path_join(form + "-source.scn"), ResourceSaver.FLAG_COMPRESS) == OK)
			result[form][style] = review(actor)
			actor.free()
	var receipt := FileAccess.open(directory.path_join("source-engine-receipt.json"), FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"weighted_poses": checked, "forms": result}, "  "))
	receipt.close()
	print("THIRD DAWN DARK HORSE SOURCE: ", checked, " weighted poses on four imported models")
	quit()


func review(actor: Node3D) -> Dictionary:
	var mesh := actor.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert(rig.get_bone_count() == 37 and mesh.mesh.get_surface_count() == 1)
	var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	assert(material != null and material.albedo_texture.get_size() == Vector2(128, 128))
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skin := Ground.skin_points(mesh, rig)
	var motions := {}
	var neutral := {}
	var fittings := {}
	for clip: String in Clips:
		assert(player.has_animation(clip))
		player.stop()
		rig.reset_bone_poses()
		player.play(clip, 0.0)
		player.advance(0.0)
		var length := player.current_animation_length
		var gap := Vector2(INF, -INF)
		for index in 33:
			player.seek(length * index / 32.0, true)
			rig.force_update_all_bone_transforms()
			var bounds := Geometry.deformed_bounds(mesh, rig)
			assert(bounds.is_finite() and bounds.get_longest_axis_size() > 1.25 and bounds.get_longest_axis_size() < 4.5)
			var height := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
			gap.x = minf(gap.x, height)
			gap.y = maxf(gap.y, height)
			checked += 1
			if clip == "Idle" and index == 0:
				for joint: String in Joints:
					var point := rig.to_global(rig.get_bone_global_pose(rig.find_bone(joint)).origin)
					neutral[joint] = [point.x, point.y, point.z]
				fittings = fitting_landmarks(skin, rig)
		motions[clip] = {"duration": length, "floor_min": gap.x, "floor_max": gap.y}
	return {"idle_joints": neutral, "idle_fittings": fittings, "motions": motions}


func fitting_landmarks(skin: Dictionary, rig: Skeleton3D) -> Dictionary:
	var matrices: Array[Transform3D] = []
	for index in skin.bones.size():
		matrices.append(rig.get_bone_global_pose(skin.bones[index]) * skin.bind_poses[index])
	var back := -INF
	var snout := AABB()
	var first := true
	for surface: Dictionary in skin.surfaces:
		for index in surface.points.size():
			var point := Vector3.ZERO
			for slot in int(surface.stride):
				var influence: int = index * surface.stride + slot
				var weight: float = surface.weights[influence]
				point += (matrices[surface.bindings[influence]] * surface.points[index]) * weight
			point = rig.to_global(point)
			if absf(point.x) < .18 and absf(point.z) < .15:
				back = maxf(back, point.y)
			if point.z > 1.02 and point.y > 1.18:
				snout = AABB(point, Vector3.ZERO) if first else snout.expand(point)
				first = false
	assert(is_finite(back) and not first)
	return {"back_top_y": back, "muzzle_bounds_min": [snout.position.x, snout.position.y, snout.position.z],
		"muzzle_bounds_max": [snout.end.x, snout.end.y, snout.end.z]}
