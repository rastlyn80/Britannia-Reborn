extends SceneTree
## Reference-based slot 11 motion for the standard and frost Troll rigs.

const Bounds := preload("res://Presentation/SkinGeometry.gd")
const LENGTH := 1.34
# Time, crouch depth, right-arm lift and left-arm brace.
const POSES := [
	[0.0, 0.0, 0.0, 0.0],
	[0.18, 0.7, 0.18, 0.62],
	[0.34, 1.0, 0.67, 0.95],
	[0.55, 1.0, 1.0, 0.87],
	[0.76, 0.98, 0.89, 0.94],
	[0.94, 0.88, 0.48, 0.82],
	[1.15, 0.35, 0.14, 0.32],
	[LENGTH, 0.0, 0.0, 0.0],
]

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func bone(rig: Skeleton3D, name: String) -> int:
	var index := rig.find_bone("bip01" if name.is_empty() else "bip01 " + name)
	assert(index >= 0)
	return index

func origin(rig: Skeleton3D, joint: int) -> Vector3:
	return rig.get_bone_global_pose(joint).origin

func rotate_joint(rig: Skeleton3D, joint: int, axis: Vector3, radians: float) -> void:
	var pose := rig.get_bone_global_pose(joint)
	pose.basis = Basis(Quaternion(axis, radians)) * pose.basis
	rig.set_bone_global_pose(joint, pose)
	rig.force_update_all_bone_transforms()

func aim(rig: Skeleton3D, joint: int, child: int, direction: Vector3) -> void:
	var from := (origin(rig, child) - origin(rig, joint)).normalized()
	var pose := rig.get_bone_global_pose(joint)
	pose.basis = Basis(Quaternion(from, direction.normalized())) * pose.basis
	rig.set_bone_global_pose(joint, pose)
	rig.force_update_all_bone_transforms()

func fold_leg(rig: Skeleton3D, side: String, depth: float, axes: Basis) -> void:
	var hip := bone(rig, side + " thigh")
	var knee := bone(rig, side + " calf")
	var foot := bone(rig, side + " foot")
	var outward := -1.0 if side == "r" else 1.0
	var thigh := (origin(rig, knee) - origin(rig, hip)).normalized()
	var shin := (origin(rig, foot) - origin(rig, knee)).normalized()
	var resting_foot := rig.get_bone_global_pose(foot).basis
	var bent_thigh := axes * Vector3(outward * 0.21, -0.56, 0.78)
	var bent_shin := axes * Vector3(outward * 0.10, 0.27, -0.96)
	aim(rig, hip, knee, thigh.lerp(bent_thigh, depth))
	aim(rig, knee, foot, shin.lerp(bent_shin, depth))
	var posed_foot := rig.get_bone_global_pose(foot)
	posed_foot.basis = Basis(Quaternion(axes.x, 0.48 * depth)) * resting_foot
	rig.set_bone_global_pose(foot, posed_foot)
	rig.force_update_all_bone_transforms()

func shape_pose(rig: Skeleton3D, mesh: MeshInstance3D, axes: Basis, depth: float, lift: float, brace: float) -> void:
	var hips := bone(rig, "")
	var pose := rig.get_bone_global_pose(hips)
	pose.origin -= rig.global_basis.inverse() * Vector3(0, 0.84 * depth, 0.12 * depth)
	rig.set_bone_global_pose(hips, pose)
	rig.force_update_all_bone_transforms()
	rotate_joint(rig, bone(rig, "spine1"), axes.x, depth * 0.45)
	rotate_joint(rig, bone(rig, "spine2"), axes.y, lift * -0.23)
	rotate_joint(rig, bone(rig, "head"), axes.x, depth * -0.13)
	rotate_joint(rig, bone(rig, "r upperarm"), axes.x, lift * -2.47)
	rotate_joint(rig, bone(rig, "r forearm"), axes.x, lift * -0.18)
	rotate_joint(rig, bone(rig, "l upperarm"), axes.x, brace * -0.52)
	rotate_joint(rig, bone(rig, "l forearm"), axes.x, brace * 0.48)
	fold_leg(rig, "r", depth, axes)
	fold_leg(rig, "l", depth, axes)

	# Keep the lowered body above the flat reference through the whole motion.
	var gap := Bounds.deformed_bounds(mesh, rig).position.y
	if gap < 0.003:
		pose = rig.get_bone_global_pose(hips)
		pose.origin += rig.global_basis.inverse() * (Vector3.UP * (0.003 - gap))
		rig.set_bone_global_pose(hips, pose)

func run() -> void:
	for treatment in ["original", "rounded", "modern"]:
		bake("trolls_troll", treatment)
		bake("trolls_troll_frost", treatment)
	quit()

func bake(kind: String, treatment: String) -> void:
	var path := "res://local-art/creatures/%s-%s.gltf" % [kind, treatment]
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	player.play("Idle")
	player.advance(0.0)
	var idle: Array[Transform3D] = []
	for joint in rig.get_bone_count():
		idle.append(rig.get_bone_pose(joint))

	var motion := Animation.new()
	motion.length = LENGTH
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var translation_tracks: Array[int] = []
	var rotation_tracks: Array[int] = []
	for joint in rig.get_bone_count():
		var target := NodePath("%s:%s" % [rig_path, rig.get_bone_name(joint)])
		var translation := motion.add_track(Animation.TYPE_POSITION_3D)
		motion.track_set_path(translation, target)
		translation_tracks.append(translation)
		var rotation := motion.add_track(Animation.TYPE_ROTATION_3D)
		motion.track_set_path(rotation, target)
		rotation_tracks.append(rotation)
		var scale := motion.add_track(Animation.TYPE_SCALE_3D)
		motion.track_set_path(scale, target)
		motion.scale_track_insert_key(scale, 0.0, idle[joint].basis.get_scale())

	var axes := rig.global_basis.inverse().orthonormalized()
	var phase := 0
	for sample in 121:
		var time := LENGTH * float(sample) / 120.0
		while phase + 1 < POSES.size() - 1 and time > float(POSES[phase + 1][0]):
			phase += 1
		var from: Array = POSES[phase]
		var to: Array = POSES[phase + 1]
		var blend := smoothstep(float(from[0]), float(to[0]), time)
		for joint in rig.get_bone_count():
			var pose := idle[joint]
			rig.set_bone_pose_position(joint, pose.origin)
			rig.set_bone_pose_rotation(joint, pose.basis.get_rotation_quaternion())
			rig.set_bone_pose_scale(joint, pose.basis.get_scale())
		rig.force_update_all_bone_transforms()
		if sample > 0 and sample < 120:
			shape_pose(rig, mesh, axes, lerpf(from[1], to[1], blend), lerpf(from[2], to[2], blend), lerpf(from[3], to[3], blend))
		for joint in rig.get_bone_count():
			motion.position_track_insert_key(translation_tracks[joint], time, rig.get_bone_pose_position(joint))
			motion.rotation_track_insert_key(rotation_tracks[joint], time, rig.get_bone_pose_rotation(joint))

	player.stop()
	player.get_animation_library("").add_animation("KneelingSwing", motion)
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	var suffix := "" if treatment == "modern" else "-" + treatment
	var output := "res://local-art/creatures/%s-slot11-trial%s.scn" % [kind, suffix]
	assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
	print(kind, ": 121 kneeling swing keys on the original rig")
	model.free()
