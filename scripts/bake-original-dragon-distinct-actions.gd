extends "res://../scripts/bake-zombie-actions.gd"
## Fit the recovered Dragon rigs to their separately stored gestures.
func run() -> void:
	for body: int in [12, 59]:
		bake_body(body, "original-dragon-distinct-%d" % body, {
			6: "WingRake", 15: "FoldedFlinch", 16: "LowWingGuard", 18: "WingLift"
		}, ["bake-original-dragon-distinct-actions.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.04, 0.38, phase) * (1.0 - smoothstep(0.58, 1.0, phase))
	var lower := slot in [6, 16]
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, (0.31 if lower else -0.17) * pulse)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, (0.38 if lower else -0.19) * pulse)
	turn_world(rig, "bip01 neck2", Vector3.RIGHT, (0.18 if slot == 6 else -0.10) * pulse)
	turn_world(rig, "bip01 head", Vector3.UP, (0.27 if slot == 18 else -0.15) * pulse)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, (-0.34 if lower else 0.22) * pulse)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		var amount: float = {6:0.61,15:0.23,16:0.39,18:-0.36}[slot]
		turn_world(rig, "bip01 " + side + " upperarm", Vector3.FORWARD, amount * sign * pulse)
		turn_world(rig, "bip01 " + side + " forearm", Vector3.UP, -0.18 * sign * pulse)
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
	library.rename_animation("Death", "RecoveredDeath")
	assert(library.add_animation("Death2", library.get_animation("RecoveredDeath").duplicate(true)) == OK)
	assert(library.add_animation("Death", fit_fall(player, rig, skins, false)) == OK)
	assert(library.add_animation("AirDeath", fit_fall(player, rig, skins, true)) == OK)

func fit_fall(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], air: bool) -> Animation:
	var landed: Array[Transform3D] = []
	if air:
		player.play("Death2", 0.0)
		player.advance(0.0)
		player.seek(player.current_animation_length, true)
		rig.force_update_all_bone_transforms()
		for joint in rig.get_bone_count():
			landed.append(rig.get_bone_pose(joint))
	var seed := "Fly" if air else "RecoveredDeath"
	var source := player.get_animation(seed)
	var clip := source.duplicate(true) as Animation
	clip.length = 1.36 if air else source.length
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
	player.play(seed, 0.0)
	player.advance(0.0)
	var flight_floor := 0.0
	for frame in 121:
		var phase := float(frame) / 120.0
		rig.reset_bone_poses()
		player.seek((minf(0.31, phase * 0.65) if air else phase) * source.length, true)
		rig.force_update_all_bone_transforms()
		var descent := smoothstep(0.19, 0.96, phase)
		var fold := smoothstep(0.52, 0.99, phase)
		if air:
			turn_world(rig, "bip01", Vector3.RIGHT, 0.21 * descent)
			turn_world(rig, "bip01 neck1", Vector3.RIGHT, 0.07 * fold)
			turn_world(rig, "bip01 tail1", Vector3.RIGHT, -0.22 * fold)
		else:
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.20 * phase)
			turn_world(rig, "bip01 tail1", Vector3.UP, -0.37 * phase)
			turn_world(rig, "bip01 neck2", Vector3.RIGHT, -0.19 * phase)
		for side: String in ["l", "r"]:
			var sign := 1.0 if side == "l" else -1.0
			var flex := fold if air else smoothstep(0.12, 0.92, phase)
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.FORWARD, sign * (-0.42 if air else -0.29) * flex)
			turn_world(rig, "bip01 " + side + " forearm", Vector3.UP, sign * (0.32 if air else 0.11) * flex)
		if air and fold > 0.0:
			for joint in landed.size():
				rig.set_bone_pose(joint, rig.get_bone_pose(joint).interpolate_with(landed[joint], fold))
			rig.force_update_all_bone_transforms()
		var gap := INF
		for skin in skins:
			gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		if frame == 0:
			flight_floor = gap
			assert(not air or flight_floor > 0.65)
		var height := lerpf(flight_floor, 0.004, descent) if air else 0.004
		var pose := rig.get_bone_global_pose(root_bone)
		pose.origin += rig.global_basis.inverse() * (Vector3.UP * (height - gap) + Vector3.BACK * (0.42 * descent if air else 0.0))
		rig.set_bone_global_pose(root_bone, pose)
		for track: int in target:
			var joint: int = target[track][0]
			var time := phase * clip.length
			if target[track][1] == Animation.TYPE_POSITION_3D:
				clip.position_track_insert_key(track, time, rig.get_bone_pose_position(joint))
			else:
				clip.rotation_track_insert_key(track, time, rig.get_bone_pose_rotation(joint))
	return clip
