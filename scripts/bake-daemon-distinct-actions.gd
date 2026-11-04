extends "res://../scripts/bake-zombie-actions.gd"
## Fit distinct ground reactions and an airborne fall to the original Daemon rig.
func run() -> void:
	bake_body(9, "daemon-distinct", {
		4: "WingShoulderStagger", 6: "LowRake",
		15: "ChestGuard", 16: "LowForearmGuard", 18: "TailPause"
	}, ["bake-daemon-distinct-actions.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var gather := smoothstep(0.02, 0.24, phase) * (1.0 - smoothstep(0.30, 0.62, phase))
	var pulse := smoothstep(0.18, 0.50, phase) * (1.0 - smoothstep(0.55, 1.0, phase))
	if slot == 18:
		turn_world(rig, "bip01 head", Vector3.UP, 0.28 * pulse)
		turn_world(rig, "bip01 tail", Vector3.UP, -0.40 * pulse)
		turn_world(rig, "bip01 tail1", Vector3.UP, -0.42 * pulse)
		turn_world(rig, "daemon l mainwing02", Vector3.RIGHT, -0.10 * gather)
		return
	if slot == 4:
		turn_world(rig, "bip01 spine1", Vector3.FORWARD, -0.24 * pulse)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.28 * pulse)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.46 * pulse)
		turn_world(rig, "daemon r mainwing01", Vector3.UP, -0.35 * pulse)
		return
	if slot == 6:
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.37 * pulse)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, 0.44 * gather - 0.85 * pulse)
		turn_world(rig, "bip01 l forearm", Vector3.RIGHT, 0.21 * pulse)
		turn_world(rig, "bip01 l thigh", Vector3.RIGHT, -0.37 * pulse)
		turn_world(rig, "bip01 l calf", Vector3.RIGHT, 0.39 * pulse)
		return
	var raised := slot == 15
	var side := "r" if raised else "l"
	turn_world(rig, "bip01 spine2", Vector3.UP, (0.23 if raised else -0.19) * pulse)
	turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, (-0.63 if raised else -0.36) * pulse)
	turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, (-0.72 if raised else -0.16) * pulse)
	turn_world(rig, "bip01 tail1", Vector3.UP, (-0.22 if raised else 0.24) * pulse)


func add_retained_actions(player: AnimationPlayer, rig: Skeleton3D, _row: Dictionary, _treatment: String) -> void:
	var skins: Array[Dictionary] = []
	var model: Node = rig
	while model.get_parent() != root:
		model = model.get_parent()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skins.append(Ground.skin_points(mesh, rig))
	assert(not skins.is_empty())
	var library := player.get_animation_library("")
	assert(library.add_animation("Death2", fit_ground_fall(player, rig, skins)) == OK)
	var source := player.get_animation("Fly")
	var clip := source.duplicate(true) as Animation
	clip.length = 1.18
	clip.loop_mode = Animation.LOOP_NONE
	var target := {}
	for track in clip.get_track_count():
		var joint := rig.find_bone(str(clip.track_get_path(track).get_concatenated_subnames()))
		if joint < 0:
			continue
		var type := clip.track_get_type(track)
		if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D]:
			continue
		target[track] = [joint, type]
		for key in range(clip.track_get_key_count(track) - 1, -1, -1):
			clip.track_remove_key(track, key)
	var root_bone := rig.find_bone("bip01")
	var root_path := NodePath(str(player.get_node(player.root_node).get_path_to(rig)) + ":bip01")
	var root_track := clip.find_track(root_path, Animation.TYPE_POSITION_3D)
	assert(root_bone >= 0 and root_track >= 0)
	player.play("Fly", 0.0)
	player.advance(0.0)
	var flight_floor := 0.0
	for frame in 121:
		var phase := float(frame) / 120.0
		rig.reset_bone_poses()
		player.seek(minf(0.38, phase * 0.85) * source.length, true)
		rig.force_update_all_bone_transforms()
		var roll := smoothstep(0.16, 0.84, phase)
		var fold := smoothstep(0.40, 0.98, phase)
		turn_world(rig, "bip01", Vector3.RIGHT, 1.36 * roll)
		turn_world(rig, "bip01 spine1", Vector3.FORWARD, 0.16 * roll)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.27 * fold)
		for side: String in ["l", "r"]:
			var sign := 1.0 if side == "l" else -1.0
			turn_world(rig, "daemon " + side + " mainwing01", Vector3.FORWARD, sign * -0.35 * fold)
			turn_world(rig, "daemon " + side + " mainwing02", Vector3.UP, sign * 0.57 * fold)
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.63 * roll)
			turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, 0.40 * fold)
		var gap := INF
		for skin in skins:
			gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		if frame == 0:
			flight_floor = gap
			assert(flight_floor > 0.80)
		var height := lerpf(flight_floor, 0.004, smoothstep(0.10, 0.91, phase))
		var pose := rig.get_bone_global_pose(root_bone)
		pose.origin += rig.global_basis.inverse() * (Vector3.UP * (height - gap) + Vector3.BACK * 0.46 * roll)
		rig.set_bone_global_pose(root_bone, pose)
		for track: int in target:
			var joint: int = target[track][0]
			var time := phase * clip.length
			if target[track][1] == Animation.TYPE_POSITION_3D:
				clip.position_track_insert_key(track, time, rig.get_bone_pose_position(joint))
			else:
				clip.rotation_track_insert_key(track, time, rig.get_bone_pose_rotation(joint))
	assert(player.get_animation_library("").add_animation("AirDeath", clip) == OK)

func fit_ground_fall(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary]) -> Animation:
	var source := player.get_animation("Death")
	var clip := source.duplicate(true) as Animation
	var placement := {}
	var skeleton_path := str(player.get_node(player.root_node).get_path_to(rig))
	for joint: String in ["daemon l mainwing01", "daemon r mainwing01", "bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm", "bip01 tail1"]:
		var index := clip.find_track(NodePath(skeleton_path + ":" + joint), Animation.TYPE_ROTATION_3D)
		assert(index >= 0)
		placement[joint] = index
		for key in range(clip.track_get_key_count(index) - 1, -1, -1):
			clip.track_remove_key(index, key)
	var root_path := NodePath(skeleton_path + ":bip01")
	var root_track := clip.find_track(root_path, Animation.TYPE_POSITION_3D)
	assert(root_track >= 0)
	for key in range(clip.track_get_key_count(root_track) - 1, -1, -1):
		clip.track_remove_key(root_track, key)
	var pivot := rig.find_bone("bip01")
	player.play("Death", 0.0)
	player.advance(0.0)
	for frame in 121:
		var phase := float(frame) / 120.0
		var time := phase * source.length
		rig.reset_bone_poses()
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		var throw_up := smoothstep(0.10, 0.42, phase) * (1.0 - smoothstep(0.48, 0.82, phase))
		var spread := smoothstep(0.44, 0.94, phase)
		turn_world(rig, "daemon l mainwing01", Vector3.UP, 0.20 * spread)
		turn_world(rig, "daemon r mainwing01", Vector3.UP, -0.17 * spread)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.43 * throw_up)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.62 * throw_up)
		turn_world(rig, "bip01 l forearm", Vector3.UP, 0.21 * spread)
		turn_world(rig, "bip01 r forearm", Vector3.UP, -0.27 * spread)
		turn_world(rig, "bip01 tail1", Vector3.UP, 0.17 * spread)
		var gap := INF
		for skin in skins:
			gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		var pose := rig.get_bone_global_pose(pivot)
		pose.origin += rig.global_basis.inverse() * Vector3.UP * (0.004 - gap)
		rig.set_bone_global_pose(pivot, pose)
		clip.position_track_insert_key(root_track, time, rig.get_bone_pose_position(pivot))
		for joint: String in placement:
			clip.rotation_track_insert_key(placement[joint], time, rig.get_bone_pose_rotation(rig.find_bone(joint)))
	return clip
