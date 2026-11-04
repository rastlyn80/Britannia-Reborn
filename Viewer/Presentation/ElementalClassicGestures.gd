extends RefCounted
## One authored pair on the independent humanoid carrier shared by air and fire.

const ARMS := ["upperarm_l", "lowerarm_l", "upperarm_r", "lowerarm_r"]
const WRISTS := ["hand_l", "hand_r"]
const SNAP := "ElementalOverhead"
const HOLD := "ElementalHeldReach"
const SNAP_TIME := 0.54
const HOLD_TIME := 0.92
static var cached: Dictionary = {}

static func install(player: AnimationPlayer, rig: Skeleton3D, scene_path: String, entry: Dictionary) -> void:
	var routes: Dictionary = entry.get("classic_action_categories", {})
	if routes.get("7") != SNAP or routes.get("8") != HOLD:
		return
	if not cached.has(scene_path):
		player.play("Idle", 0.0)
		player.advance(0.0)
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		var joints: Array[int] = []
		for name in ARMS + WRISTS:
			var joint := rig.find_bone(name)
			assert(joint >= 0)
			joints.append(joint)
		var idle: Array[Quaternion] = []
		for joint in joints:
			idle.append(rig.get_bone_pose_rotation(joint))
		var path := player.get_node(player.root_node).get_path_to(rig)
		var idle_clip := player.get_animation("Idle")
		cached[scene_path] = {
			SNAP: build(rig, joints, idle, path, idle_clip, true),
			HOLD: build(rig, joints, idle, path, idle_clip, false),
		}
		restore(rig, joints, idle)
		player.seek(0.0, true)
	var library := player.get_animation_library("")
	for label: String in cached[scene_path]:
		assert(library.add_animation(label, cached[scene_path][label]) == OK)

static func build(rig: Skeleton3D, joints: Array[int], idle: Array[Quaternion], path: NodePath, idle_clip: Animation, overhead: bool) -> Animation:
	var motion := idle_clip.duplicate(true) as Animation
	motion.length = SNAP_TIME if overhead else HOLD_TIME
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		var value: Variant = motion.track_get_key_value(track, 0)
		for index in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, index)
		motion.track_insert_key(track, 0.0, value)
	var names := ARMS + WRISTS
	var tracks: Array[int] = []
	for name: String in names:
		var joint_path := NodePath("%s:%s" % [path, name])
		var track := motion.find_track(joint_path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, joint_path)
		tracks.append(track)
	var intervals := ceili(motion.length * 120.0)
	for sample in intervals + 1:
		var phase := float(sample) / intervals
		restore(rig, joints, idle)
		var lift := smoothstep(0.05, 0.44, phase) * (1.0 - smoothstep(0.49, 0.91, phase))
		var reach := smoothstep(0.03, 0.19, phase) * (1.0 - smoothstep(0.74, 1.0, phase))
		if overhead:
			aim(rig, joints[0], joints[1], Vector3(0.85, -0.14, 0.44), reach)
			aim(rig, joints[1], joints[4], Vector3(0.77, -0.12, 0.59), reach)
			aim(rig, joints[2], joints[3], Vector3(-0.47, 0.86, 0.22), lift)
			aim(rig, joints[3], joints[5], Vector3(-0.14, 0.98, 0.12), lift)
		else:
			aim(rig, joints[0], joints[1], Vector3(0.49, -0.54, 0.66), reach)
			aim(rig, joints[1], joints[4], Vector3(0.36, -0.58, 0.73), reach)
			aim(rig, joints[2], joints[3], Vector3(-0.48, -0.04, 0.87), reach)
			aim(rig, joints[3], joints[5], Vector3(-0.21, -0.32, 0.92), reach)
		for i in joints.size():
			motion.rotation_track_insert_key(tracks[i], phase * motion.length, rig.get_bone_pose_rotation(joints[i]))
	return motion

static func restore(rig: Skeleton3D, joints: Array[int], idle: Array[Quaternion]) -> void:
	for i in joints.size():
		rig.set_bone_pose_rotation(joints[i], idle[i])
	rig.force_update_all_bone_transforms()

static func aim(rig: Skeleton3D, joint: int, child: int, direction: Vector3, amount: float) -> void:
	var pose := rig.get_bone_global_pose(joint)
	var current := (rig.get_bone_global_pose(child).origin - pose.origin).normalized()
	var turn := Quaternion(current, direction.normalized())
	pose.basis = Basis(Quaternion.IDENTITY.slerp(turn, amount)) * pose.basis
	rig.set_bone_global_pose(joint, pose)
	rig.force_update_all_bone_transforms()
