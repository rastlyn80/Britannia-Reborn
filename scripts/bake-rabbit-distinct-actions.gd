extends "res://../scripts/bake-cat-actions.gd"

const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const RABBIT_SOURCE := "res://Art/Creatures/Rabbit/rabbit.glb"
const FITS := {6: ["RabbitLunge", 0.55], 10: ["RabbitEarCheck", 0.44], 12: ["Death2", 0.8]}

func run() -> void:
	var model := (load(RABBIT_SOURCE) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var skins: Array[Dictionary] = []
	for name: String in ["Rabbit", "Fur"]:
		var mesh := model.find_child(name, true, false) as MeshInstance3D
		assert(mesh != null and mesh.skin != null)
		skins.append(Ground.skin_points(mesh, rig))
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	player.deterministic = true
	for slot: int in FITS:
		assert(library.add_animation(FITS[slot][0], build_rabbit(slot, player, rig, skins)) == OK)
	Exact.check_earlier_keys(player, RABBIT_SOURCE)
	player.stop()
	var output := PackedScene.new()
	assert(output.pack(model) == OK)
	assert(ResourceSaver.save(output, "res://local-art/creatures/rabbit-actions-candidate.scn", ResourceSaver.FLAG_COMPRESS) == OK)
	var additional := AnimationLibrary.new()
	for fit: Array in FITS.values():
		assert(additional.add_animation(fit[0], library.get_animation(fit[0]).duplicate(true)) == OK)
	var path := "res://local-art/creatures/rabbit-distinct-actions.res"
	assert(ResourceSaver.save(additional, path, ResourceSaver.FLAG_COMPRESS) == OK)
	var inputs := {}
	for file: String in [get_script().resource_path, "res://../scripts/bake-cat-actions.gd",
			"res://Presentation/SourceGroundLookup.gd"]:
		inputs[file.get_file()] = FileAccess.get_sha256(file)
	var receipt := FileAccess.open("res://local-art/creatures/rabbit-distinct-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"source": FileAccess.get_sha256(RABBIT_SOURCE),
		"scene": FileAccess.get_sha256("res://local-art/creatures/rabbit-actions-candidate.scn"),
		"library": FileAccess.get_sha256(path), "inputs": inputs}))
	receipt.close()
	model.free()
	print("RABBIT ACTION BAKE: separate lunge, ear check and collapse on the retained body and fur skins")
	quit()

func build_rabbit(slot: int, player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary]) -> Animation:
	var motion := player.get_animation("Idle").duplicate(true) as Animation
	motion.length = FITS[slot][1]
	motion.loop_mode = Animation.LOOP_NONE
	var hip := rig.find_bone("Hips")
	var path := player.get_node(player.root_node).get_path_to(rig)
	var rotation_tracks := {}
	for track in motion.get_track_count():
		var label := str(motion.track_get_path(track).get_concatenated_subnames())
		var joint := rig.find_bone(label)
		for key in range(motion.track_get_key_count(track) - 1, 0, -1):
			motion.track_remove_key(track, key)
		if joint >= 0 and motion.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			rotation_tracks[joint] = track
	var hips := NodePath(str(path) + ":Hips")
	var placement := motion.find_track(hips, Animation.TYPE_POSITION_3D)
	assert(placement >= 0)
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := frame / 80.0
		rig.reset_bone_poses()
		player.seek(0.0, true)
		var lift := pose_rabbit(rig, slot, phase)
		var gap := INF
		for skin: Dictionary in skins:
			gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		var pose := rig.get_bone_global_pose(hip)
		pose.origin += rig.global_basis.inverse() * Vector3.UP * (0.0025 + lift - gap)
		rig.set_bone_global_pose(hip, pose)
		var time := phase * motion.length
		motion.position_track_insert_key(placement, time, rig.get_bone_pose_position(hip))
		for joint: int in rotation_tracks:
			motion.rotation_track_insert_key(rotation_tracks[joint], time, rig.get_bone_pose_rotation(joint))
	return motion

func pose_rabbit(rig: Skeleton3D, slot: int, phase: float) -> float:
	var pulse := smoothstep(0.04, 0.40, phase) * (1.0 - smoothstep(0.56, 1.0, phase))
	if slot == 10:
		turn(rig, "Head", Vector3.UP, 0.33 * pulse)
		turn(rig, "Ear_L", Vector3.FORWARD, -0.41 * pulse)
		turn(rig, "Ear_R", Vector3.RIGHT, -0.27 * pulse)
		turn(rig, "Ear_R.001", Vector3.FORWARD, 0.18 * pulse)
		return 0.0
	if slot == 6:
		turn(rig, "Hips", Vector3.RIGHT, -0.31 * pulse)
		turn(rig, "Spine", Vector3.RIGHT, 0.18 * pulse)
		turn(rig, "Neck", Vector3.RIGHT, 0.19 * pulse)
		turn(rig, "Head", Vector3.RIGHT, 0.25 * pulse)
		for side: String in ["L", "R"]:
			turn(rig, "FrontUpLeg_" + side, Vector3.RIGHT, -0.57 * pulse)
			turn(rig, "FrontLeg_" + side, Vector3.RIGHT, 0.33 * pulse)
			turn(rig, "Ear_" + side, Vector3.RIGHT, 0.46 * pulse)
		var root_bone := rig.find_bone("Hips")
		var pose := rig.get_bone_global_pose(root_bone)
		pose.origin += rig.global_basis.inverse() * Vector3.BACK * (0.10 * pulse)
		rig.set_bone_global_pose(root_bone, pose)
		rig.force_update_all_bone_transforms()
		return 0.035 * pulse
	var fold := smoothstep(0.06, 0.57, phase)
	var roll := smoothstep(0.24, 0.88, phase)
	turn(rig, "Hips", Vector3.FORWARD, -1.51 * roll)
	turn(rig, "Spine", Vector3.RIGHT, 0.28 * fold)
	turn(rig, "Head", Vector3.RIGHT, -0.26 * fold)
	for side: String in ["L", "R"]:
		turn(rig, "FrontUpLeg_" + side, Vector3.RIGHT, -0.52 * fold)
		turn(rig, "FrontLeg_" + side, Vector3.RIGHT, 0.58 * fold)
		turn(rig, "BackUpLeg_" + side, Vector3.RIGHT, 0.39 * fold)
		turn(rig, "BackLeg_" + side, Vector3.RIGHT, -0.43 * fold)
		turn(rig, "Ear_" + side, Vector3.RIGHT, 0.58 * roll)
	return 0.0
