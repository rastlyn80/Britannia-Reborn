extends SceneTree

const INPUT := "res://Art/Creatures/Fire/fire-elemental.scn"
const OUTPUT := "res://local-art/creatures/fire-distinct-actions.res"
const CANDIDATE := "res://local-art/creatures/fire-distinct-candidate.scn"
const JOINTS := ["spine_02", "spine_03", "Head", "upperarm_l", "lowerarm_l", "upperarm_r", "lowerarm_r"]
const CLIPS := ["EmberFlinch", "FlameGuard", "FlareSpread"]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model := (load(INPUT) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := AnimationLibrary.new()
	for mode in CLIPS.size():
		assert(library.add_animation(CLIPS[mode], fit(player, rig, mode)) == OK)
	assert(ResourceSaver.save(library, OUTPUT, ResourceSaver.FLAG_COMPRESS) == OK)
	var existing := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", existing)
	assert(existing.get_animation_list().size() == 15)
	for clip: String in library.get_animation_list():
		assert(existing.add_animation(clip, library.get_animation(clip)) == OK)
	player.stop()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK and ResourceSaver.save(scene, CANDIDATE, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	var receipt := FileAccess.open("res://local-art/creatures/fire-distinct-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"source": FileAccess.get_sha256(INPUT), "scene": FileAccess.get_sha256(CANDIDATE),
		"library": FileAccess.get_sha256(OUTPUT), "recipe": FileAccess.get_sha256(get_script().resource_path)}))
	receipt.close()
	print("FIRE DISTINCT ACTIONS: three independent motions on the distributed carrier")
	quit()

func fit(player: AnimationPlayer, rig: Skeleton3D, mode: int) -> Animation:
	var idle := player.get_animation("Idle")
	var motion := idle.duplicate(true) as Animation
	motion.length = [0.42, 0.56, 0.88][mode]
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		for key in range(motion.track_get_key_count(track) - 1, 0, -1):
			motion.track_remove_key(track, key)
	var path := player.get_node(player.root_node).get_path_to(rig)
	var rotations := {}
	for joint: String in JOINTS:
		var track := motion.find_track(NodePath("%s:%s" % [path, joint]), Animation.TYPE_ROTATION_3D)
		assert(track >= 0)
		rotations[joint] = track
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := float(frame) / 80.0
		var pulse := smoothstep(0.03, 0.38, phase) * (1.0 - smoothstep(0.58, 1.0, phase))
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		turn(rig, "spine_02", Vector3.FORWARD, [-0.21, 0.25, 0.07][mode] * pulse)
		turn(rig, "spine_03", Vector3.RIGHT, [-0.23, 0.27, -0.09][mode] * pulse)
		turn(rig, "Head", Vector3.UP, [0.20, -0.31, 0.19][mode] * pulse)
		turn(rig, "upperarm_l", Vector3.FORWARD, [-0.28, -0.36, -0.64][mode] * pulse)
		turn(rig, "upperarm_r", Vector3.FORWARD, [0.23, 0.31, 0.59][mode] * pulse)
		turn(rig, "lowerarm_l", Vector3.RIGHT, [0.27, -0.53, -0.48][mode] * pulse)
		turn(rig, "lowerarm_r", Vector3.RIGHT, [-0.43, -0.61, -0.30][mode] * pulse)
		for name: String in rotations:
			motion.rotation_track_insert_key(rotations[name], phase * motion.length, rig.get_bone_pose_rotation(rig.find_bone(name)))
	return motion

func turn(rig: Skeleton3D, name: String, axis: Vector3, angle: float) -> void:
	var bone := rig.find_bone(name)
	assert(bone >= 0)
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion((rig.global_basis.inverse() * axis).normalized(), angle)) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()
