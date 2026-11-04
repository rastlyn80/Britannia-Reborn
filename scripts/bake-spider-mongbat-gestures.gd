extends SceneTree
## Authored Classic slot 11 gestures on each creature's archived rig.

const TIMES := [0.0, 0.13, 0.29, 0.47, 0.67, 0.84]
const FORMS := {
	28: ["arachnids_spider_giant", "AbdomenShift"],
	39: ["mongbats_mongbat", "WingSettle"],
}
# Joint name, rotation axis, and radians at the six gesture phases.
const MOTIONS := {
	28: [
		["bone02", Vector3.RIGHT, [0.0, -0.08, -0.15, 0.18, 0.26, 0.0]],
		["bone16", Vector3.RIGHT, [0.0, -0.13, -0.26, -0.12, -0.04, 0.0]],
		["bone17", Vector3.RIGHT, [0.0, -0.07, -0.20, -0.11, 0.0, 0.0]],
		["bone18", Vector3.RIGHT, [0.0, 0.06, 0.14, 0.08, 0.0, 0.0]],
	],
	39: [
		["bip01 spine2", Vector3.RIGHT, [0.0, 0.035, 0.064, 0.043, 0.018, 0.0]],
		["bip01 neck", Vector3.RIGHT, [0.0, 0.021, 0.038, 0.031, 0.013, 0.0]],
		["mongbat l wingmain2", Vector3(0, 0.97, 0.24), [1.33, 1.34, 1.42, 1.39, 1.35, 1.33]],
		["mongbat r wingmain2", Vector3(0, 0.97, 0.24), [-1.33, -1.34, -1.42, -1.39, -1.35, -1.33]],
		["mongbat l wingmain1", Vector3(0, 0.97, 0.24), [1.33, 1.34, 1.42, 1.39, 1.35, 1.33]],
		["mongbat r wingmain1", Vector3(0, 0.97, 0.24), [-1.33, -1.34, -1.42, -1.39, -1.35, -1.33]],
		["bip01 tail1", Vector3.UP, [0.0, 0.03, 0.085, 0.05, 0.018, 0.0]],
	],
}

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	for body: int in FORMS:
		for treatment in ["original", "rounded", "modern"]:
			if not bake(body, treatment):
				quit(1)
				return
	quit()

func bake(body: int, treatment: String) -> bool:
	var form: Array = FORMS[body]
	var input := "res://local-art/creatures/%s-%s.gltf" % [form[0], treatment]
	var model := (load(input) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("")
	var motion := library.get_animation("Idle").duplicate(true) as Animation
	motion.length = TIMES[-1]
	motion.loop_mode = Animation.LOOP_NONE
	var rotation_tracks := {}
	for track in motion.get_track_count():
		var value: Variant = motion.track_get_key_value(track, 0)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		motion.track_insert_key(track, 0.0, value)
		var path := motion.track_get_path(track)
		if motion.track_get_type(track) == Animation.TYPE_ROTATION_3D and path.get_subname_count() == 1:
			rotation_tracks[str(path.get_subname(0))] = track
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	if body == 39:
		set_mongbat_wing_rest(rig, motion, rig_path)
		if treatment != "modern":
			var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold = 0.12
				mesh.mesh.surface_set_material(surface, material)
	rig.force_update_all_bone_transforms()
	var idle: Array[Quaternion] = []
	for joint: Array in MOTIONS[body]:
		var bone := rig.find_bone(joint[0])
		assert(bone >= 0)
		idle.append(rig.get_bone_pose_rotation(bone))
		if not rotation_tracks.has(joint[0]):
			rotation_tracks[joint[0]] = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(rotation_tracks[joint[0]], NodePath("%s:%s" % [rig_path, joint[0]]))
	var world_to_rig := rig.global_basis.inverse()
	var joints: Array = MOTIONS[body]
	for frame in 102:
		var time: float = motion.length * float(frame) / 101.0
		var phase := 0
		while phase < TIMES.size() - 2 and time > TIMES[phase + 1]:
			phase += 1
		var blend := smoothstep(TIMES[phase], TIMES[phase + 1], time)
		for i in joints.size():
			rig.set_bone_pose_rotation(rig.find_bone(joints[i][0]), idle[i])
		for joint: Array in joints:
			rig.force_update_all_bone_transforms()
			var bone := rig.find_bone(joint[0])
			var pose := rig.get_bone_global_pose(bone)
			var axis := (world_to_rig * (joint[1] as Vector3)).normalized()
			var angle := lerpf(joint[2][phase], joint[2][phase + 1], blend)
			pose.basis = Basis(Quaternion(axis, angle)) * pose.basis
			rig.set_bone_global_pose(bone, pose)
			motion.rotation_track_insert_key(rotation_tracks[joint[0]], time, rig.get_bone_pose_rotation(bone))
	player.stop()
	assert(library.add_animation(form[1], motion) == OK)
	var scene := PackedScene.new()
	var path := "res://local-art/creatures/mul-gesture-%d-%s.scn" % [body, treatment]
	var saved := scene.pack(model) == OK and ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS) == OK
	model.free()
	print("CLASSIC ", body, " ", treatment, ": ", form[1], " on original source joints")
	return saved

func set_mongbat_wing_rest(rig: Skeleton3D, motion: Animation, rig_path: NodePath) -> void:
	for bone in rig.get_bone_count():
		var name := rig.get_bone_name(bone)
		if not "wing" in name:
			continue
		rig.reset_bone_pose(bone)
		var path := NodePath("%s:%s" % [rig_path, name])
		var position := motion.find_track(path, Animation.TYPE_POSITION_3D)
		var rotation := motion.find_track(path, Animation.TYPE_ROTATION_3D)
		if position >= 0:
			motion.position_track_insert_key(position, 0.0, rig.get_bone_pose_position(bone))
		if rotation >= 0:
			motion.rotation_track_insert_key(rotation, 0.0, rig.get_bone_pose_rotation(bone))
