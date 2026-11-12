# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Derived := ["Fly", "TakeOff", "Land", "AirAttack", "AirHit", "AirDeath", "EagleQuietWatch",
	"EagleGlance", "EagleWingBeat", "AirEagleWingBeat"]


func _initialize() -> void:
	create_timer(50.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	check_baked(preview_folder())


func check_baked(folder: String) -> void:
	for treatment: String in ["original", "rounded", "modern"]:
		var asset := folder.path_join("5-%s.scn" % treatment)
		var source := (load(asset) as PackedScene).instantiate() as Node3D
		root.add_child(source)
		var geometry := audit(source, Derived, ["bip01 head", "bip01 l foot", "bip01 r foot", "bip01 pelvis"])
		for clip: String in Derived:
			assert(geometry[clip].floor[0] >= -.006, "%s %s floor %s" % [treatment, clip, geometry[clip].floor])
		for clip: String in ["Fly", "AirAttack", "AirHit"]:
			assert(geometry[clip].floor[0] > .11, "%s %s expected airborne, measured %s" % [treatment, clip, geometry[clip].floor])
		assert(geometry["AirEagleWingBeat"].floor[0] > .045, "The dive must stay above its landing plane")
		assert(geometry["Fly"].width[1] > 1.85)
		assert(geometry["EagleWingBeat"].width[1] > 1.60)
		assert(geometry["EagleQuietWatch"].width[1] < .58)
		var player := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var rig := source.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var perch := posed_joints(player, rig, "Idle", 0.0)
		var flying := posed_joints(player, rig, "Fly", 0.0)
		assert(delta(flying, posed_joints(player, rig, "Fly", .99999)) < .001)
		assert(delta(perch, posed_joints(player, rig, "TakeOff", 0.0)) < .007)
		assert(delta(flying, posed_joints(player, rig, "TakeOff", 1.0)) < .007)
		assert(delta(flying, posed_joints(player, rig, "Land", 0.0)) < .007)
		assert(delta(perch, posed_joints(player, rig, "Land", 1.0)) < .007)
		source.free()
	print("EAGLE FLIGHT GEOMETRY: 1830 full-skin poses, 15 joint-space handoffs across 3 treatments")
	quit()


func posed_joints(player: AnimationPlayer, rig: Skeleton3D, clip: String, phase: float) -> PackedVector3Array:
	rig.reset_bone_poses()
	player.play(clip, 0.0)
	player.advance(0.0)
	player.seek(player.current_animation_length * phase, true)
	rig.force_update_all_bone_transforms()
	var result := PackedVector3Array()
	for bone in rig.get_bone_count():
		result.append(rig.to_global(rig.get_bone_global_pose(bone).origin))
	return result


func delta(before: PackedVector3Array, after: PackedVector3Array) -> float:
	var largest := 0.0
	for index in before.size():
		largest = maxf(largest, before[index].distance_to(after[index]))
	return largest


func audit(scene: Node3D, names: Array, landmarks: Array) -> Dictionary:
	var rig := scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := scene.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skins: Array[Dictionary] = []
	for part: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if part.skin != null and part.name != &"SourceContactReference":
			skins.append(Ground.skin_points(part, rig))
	assert(not skins.is_empty())
	var report := {}
	for label: String in names:
		assert(player.has_animation(label))
		player.play(label, 0.0)
		player.advance(0.0)
		var width := Vector2(INF, -INF)
		var bottom := Vector2(INF, -INF)
		var tops := Vector2(INF, -INF)
		var markers := {}
		for index in 61:
			player.seek(player.current_animation_length * index / 60.0, true)
			rig.force_update_all_bone_transforms()
			var bounds := sample_bounds(skins, rig)
			width = envelope(width, bounds.size.x)
			bottom = envelope(bottom, bounds.position.y)
			tops = envelope(tops, bounds.end.y)
			for name: String in landmarks:
				var joint := rig.find_bone(name)
				assert(joint >= 0)
				var y := rig.to_global(rig.get_bone_global_pose(joint).origin).y
				markers[name] = envelope(markers.get(name, Vector2(INF, -INF)), y)
		report[label] = {"seconds": player.current_animation_length, "width": [width.x, width.y],
			"floor": [bottom.x, bottom.y], "top": [tops.x, tops.y], "landmark_height": {}}
		for name: String in markers:
			var extent: Vector2 = markers[name]
			report[label].landmark_height[name] = [extent.x, extent.y]
	return report


func envelope(previous: Vector2, sample: float) -> Vector2:
	return Vector2(minf(previous.x, sample), maxf(previous.y, sample))


func sample_bounds(skins: Array[Dictionary], rig: Skeleton3D) -> AABB:
	var first := true
	var bounds := AABB()
	for skin: Dictionary in skins:
		var matrices: Array[Transform3D] = []
		for index in skin.bones.size():
			matrices.append(rig.global_transform * rig.get_bone_global_pose(skin.bones[index]) * skin.bind_poses[index])
		for surface: Dictionary in skin.surfaces:
			for vertex in surface.points.size():
				var point := Vector3.ZERO
				for influence in surface.stride:
					var slot: int = vertex * surface.stride + influence
					var weight: float = surface.weights[slot]
					if weight > 0.0:
						point += matrices[surface.bindings[slot]] * surface.points[vertex] * weight
				bounds = AABB(point, Vector3.ZERO) if first else bounds.expand(point)
				first = false
	return bounds


func preview_folder() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--eagle-preview="):
			return argument.trim_prefix("--eagle-preview=")
	return "res://local-art/creatures/original-eagle"
