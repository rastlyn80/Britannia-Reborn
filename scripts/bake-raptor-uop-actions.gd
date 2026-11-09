extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const RAPTOR_CLIPS := {3: "Death2", 15: "RaptorDuck", 22: "RaptorPeaceWalk", 23: "RaptorLookBehind",
	26: "RaptorLookUp", 27: "RaptorLowerHead", 28: "RaptorSettle"}
const RAPTOR_LENGTHS := {3: 0.82, 15: 0.66, 23: 0.96, 26: 1.12, 27: 0.88, 28: 0.88}
const RAPTOR_JOINTS := ["Body", "Hips", "Torso", "Shoulders", "Neck", "Head", "Tail1", "Tail2",
	"Tail3", "BackUpLeg.L", "BackUpLeg.R", "FrontUpLeg.L", "FrontUpLeg.R"]

func run() -> void:
	var row := Registry.entry(730)
	if row.get("classic_gesture_batch") == "golem_raptor_juka_solen_actions":
		push_error("Refusing to overwrite an active creature action package")
		quit(1)
		return
	assert(row.kind == "raptor" and row.classic_action_categories["11"] == "ReadyStance")
	for treatment: String in row.assets:
		assert(FileAccess.get_sha256(row.assets[treatment]) == row.asset_sha256[treatment])
	bake_body(730, "raptor-uop", RAPTOR_CLIPS, ["bake-raptor-uop-actions.gd",
		"bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	if slot == 22:
		return peaceful_walk(player, rig)
	return fit_grounded(player, rig, skins, RAPTOR_LENGTHS[slot], "Body", RAPTOR_JOINTS, pose_raptor.bind(slot))

func peaceful_walk(player: AnimationPlayer, rig: Skeleton3D) -> Animation:
	return reframe_walk(player, rig, ["Torso", "Neck", "Head", "Tail1", "Tail2", "Tail3"], shape_raptor_walk)

func reframe_walk(player: AnimationPlayer, rig: Skeleton3D, joints: Array[String], shape: Callable) -> Animation:
	var source := player.get_animation("Walk")
	var clip := source.duplicate(true) as Animation
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var tracks := {}
	for joint_name: String in joints:
		var bone := rig.find_bone(joint_name)
		assert(bone >= 0)
		var path := NodePath("%s:%s" % [rig_path, joint_name])
		var track := clip.find_track(path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track, path)
		else:
			for key in range(clip.track_get_key_count(track) - 1, -1, -1):
				clip.track_remove_key(track, key)
		tracks[bone] = track
	player.play("Walk", 0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := float(frame) / 80.0
		var time := phase * source.length
		rig.reset_bone_poses()
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		shape.call(rig, phase)
		for bone: int in tracks:
			clip.rotation_track_insert_key(tracks[bone], time, rig.get_bone_pose_rotation(bone))
	return clip

func shape_raptor_walk(rig: Skeleton3D, phase: float) -> void:
	var sway := sin(phase * TAU)
	turn_world(rig, "Torso", Vector3.RIGHT, -0.08)
	turn_world(rig, "Neck", Vector3.RIGHT, -0.16 + 0.035 * sway)
	turn_world(rig, "Head", Vector3.UP, 0.08 * sway)
	turn_world(rig, "Tail1", Vector3.RIGHT, -0.09)
	turn_world(rig, "Tail2", Vector3.UP, -0.14 * sway)
	turn_world(rig, "Tail3", Vector3.UP, -0.08 * sway)

func pose_raptor(rig: Skeleton3D, phase: float, slot: int) -> void:
	var pulse := smoothstep(0.06, 0.43, phase) * (1.0 - smoothstep(0.57, 0.99, phase))
	if slot == 3:
		var slump := smoothstep(0.12, 0.85, phase)
		var buck := smoothstep(0.05, 0.31, phase) * (1.0 - smoothstep(0.40, 0.72, phase))
		turn_world(rig, "Body", Vector3.FORWARD, -1.40 * slump)
		turn_world(rig, "Torso", Vector3.RIGHT, -0.29 * buck + 0.25 * slump)
		turn_world(rig, "Neck", Vector3.RIGHT, -0.32 * buck + 0.19 * slump)
		turn_world(rig, "BackUpLeg.L", Vector3.RIGHT, 0.31 * slump)
		turn_world(rig, "BackUpLeg.R", Vector3.RIGHT, -0.27 * slump)
		turn_world(rig, "FrontUpLeg.L", Vector3.RIGHT, -0.59 * buck + 0.23 * slump)
		turn_world(rig, "Tail2", Vector3.UP, 0.36 * slump)
		return
	var yaw := 0.0
	var neck := 0.0
	var body_tilt := 0.0
	var tail := 0.0
	match slot:
		15:
			neck = 0.42
			body_tilt = 0.20
			tail = -0.18
		23:
			yaw = -0.63
			neck = -0.12
			tail = -0.20
		26:
			neck = -0.58
			body_tilt = -0.17
			tail = 0.19
		27:
			neck = 0.54
			body_tilt = 0.19
			tail = -0.24
		28:
			neck = 0.18
			body_tilt = 0.12
			yaw = 0.15
			tail = -0.11
	turn_world(rig, "Torso", Vector3.RIGHT, body_tilt * pulse)
	turn_world(rig, "Shoulders", Vector3.UP, yaw * pulse * 0.23)
	turn_world(rig, "Neck", Vector3.RIGHT, neck * pulse)
	turn_world(rig, "Head", Vector3.UP, yaw * pulse)
	turn_world(rig, "Tail1", Vector3.RIGHT, tail * pulse)
	turn_world(rig, "Tail3", Vector3.UP, -yaw * pulse * 0.42)
