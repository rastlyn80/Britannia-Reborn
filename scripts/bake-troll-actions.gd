extends "res://../scripts/bake-skeleton-actions.gd"

const SLOTS := {2: "Death2", 4: "WideSwipe", 6: "RisingSweep", 15: "OverheadGuard", 16: "ShoulderGuard", 18: "KnuckleCheck"}
const MOTION_LENGTHS := {2: 0.78, 4: 0.64, 6: 0.64, 15: 0.48, 16: 0.48, 18: 0.80}
func run() -> void:
	var receipts := {}
	for body: int in [53, 54, 55]:
		var row := Registry.entry(body)
		assert(row.classic_action_categories["11"] == "KneelingSwing" and not row.has("classic_gesture_batch"))
		var treatments := {}
		for treatment: String in row.assets:
			var path := Registry.asset_path(row, treatment)
			var digest := FileAccess.get_sha256(path)
			assert(digest == row.asset_sha256[treatment])
			var output := "res://local-art/creatures/troll-actions-%d-%s.scn" % [body, treatment]
			bake_troll(path, output)
			treatments[treatment] = {"source": digest, "scene": FileAccess.get_sha256(output)}
		receipts[str(body)] = treatments
	var receipt := FileAccess.open("res://local-art/creatures/troll-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	var inputs := {}
	for path: String in [get_script().resource_path, "res://../scripts/bake-skeleton-actions.gd",
			"res://Presentation/WaterElementalFidgets.gd", "res://Presentation/SourceGroundLookup.gd"]:
		inputs[path.get_file()] = FileAccess.get_sha256(path)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": receipts}))
	receipt.close()
	quit()

func bake_troll(path: String, output: String) -> void:
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skins.append(Ground.skin_points(mesh, rig))
	for slot: int in SLOTS:
		assert(player.get_animation_library("").add_animation(SLOTS[slot], fit_troll(player, rig, skins, slot)) == OK)
	player.stop()
	var result := PackedScene.new()
	assert(result.pack(model) == OK and ResourceSaver.save(result, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = MOTION_LENGTHS[slot]
	clip.loop_mode = Animation.LOOP_NONE
	var rotations := {}
	var pelvis := rig.find_bone("bip01")
	var animation_root := player.get_node(player.root_node)
	var placement_path := NodePath(str(animation_root.get_path_to(rig)) + ":bip01")
	var placement := clip.find_track(placement_path, Animation.TYPE_POSITION_3D)
	for track in clip.get_track_count():
		var joint := rig.find_bone(str(clip.track_get_path(track).get_concatenated_subnames()))
		for key in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, key)
		if joint >= pelvis and clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			rotations[joint] = track
	if placement < 0:
		placement = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(placement, placement_path)
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := float(frame) / 80.0
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		pose_troll(rig, slot, phase)
		point_weapon(rig, slot, phase)
		var hip := rig.get_bone_global_pose(pelvis)
		var gap := INF
		for skin: Dictionary in skins:
			gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		hip.origin += rig.global_basis.inverse() * Vector3.UP * (0.004 - gap)
		rig.set_bone_global_pose(pelvis, hip)
		var time := phase * clip.length
		clip.position_track_insert_key(placement, time, rig.get_bone_pose_position(pelvis))
		for joint: int in rotations:
			clip.rotation_track_insert_key(rotations[joint], time, rig.get_bone_pose_rotation(joint))
	return clip

func point_weapon(rig: Skeleton3D, slot: int, phase: float) -> void:
	var weapon := rig.find_bone("troll weapon")
	if weapon < 0:
		return
	var shaft: Vector3 = {2: Vector3(0.18, 0.12, 0.98), 4: Vector3(-0.79, 0.26, 0.56),
		6: Vector3(-0.26, 0.96, -0.12), 15: Vector3(-0.42, 0.82, 0.39),
		16: Vector3(-0.91, 0.40, -0.14), 18: Vector3(-0.24, 0.37, 0.89)}[slot]
	var amount := smoothstep(0.04, 0.43, phase) * (1.0 - smoothstep(0.63, 1.0, phase))
	if slot == 2:
		amount = smoothstep(0.52, 0.98, phase)
	var hand := rig.find_bone("bip01 r hand")
	var current := rig.get_bone_global_pose(weapon).basis.y.normalized()
	var desired := (rig.global_basis.inverse() * shaft).normalized()
	var pose := rig.get_bone_global_pose(hand)
	pose.basis = Basis(Quaternion.IDENTITY.slerp(Quaternion(current, desired), amount)) * pose.basis
	rig.set_bone_global_pose(hand, pose)
	rig.force_update_all_bone_transforms()

func joint_world(rig: Skeleton3D, label: String) -> Vector3:
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(label)).origin)

func turn_world(rig: Skeleton3D, label: String, axis: Vector3, radians: float) -> void:
	var joint := rig.find_bone(label)
	assert(joint >= 0)
	var pose := rig.get_bone_global_pose(joint)
	pose.basis = Basis(Quaternion((rig.global_basis.inverse() * axis).normalized(), radians)) * pose.basis
	rig.set_bone_global_pose(joint, pose)
	rig.force_update_all_bone_transforms()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var strike := smoothstep(0.08, 0.40, phase) * (1.0 - smoothstep(0.58, 1.0, phase))
	var reset := 1.0 - smoothstep(0.78, 1.0, phase)
	var mid := joint_world(rig, "bip01")
	var right := joint_world(rig, "bip01 r hand")
	var left := joint_world(rig, "bip01 l hand")
	if slot == 2:
		var raise := smoothstep(0.03, 0.31, phase) * (1.0 - smoothstep(0.38, 0.77, phase))
		var settle := smoothstep(0.42, 1.0, phase)
		turn_world(rig, "bip01", Vector3.RIGHT, 0.26 * settle)
		turn_world(rig, "bip01", Vector3.FORWARD, -0.38 * settle)
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.39 * settle - 0.32 * raise)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.45 * settle - 0.23 * raise)
		for side: String in ["r", "l"]:
			turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, -0.62 * settle)
			turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, 1.28 * settle)
		fit_arm(rig, "r", right.lerp(mid + Vector3(-0.56, 1.41, 0.32), raise).lerp(mid + Vector3(-0.62, -0.48, 0.62), settle))
		fit_arm(rig, "l", left.lerp(mid + Vector3(0.68, -0.50, 0.42), settle))
		return
	if slot == 4 or slot == 6:
		var wind := smoothstep(0.00, 0.23, phase) * (1.0 - smoothstep(0.24, 0.49, phase))
		if slot == 6:
			wind = 1.0 - smoothstep(0.08, 0.43, phase)
		var finish := smoothstep(0.22, 0.62, phase) * reset
		turn_world(rig, "bip01 spine1", Vector3.UP, -0.64 * wind + 0.55 * finish)
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, 0.36 * finish if slot == 4 else -0.33 * finish + 0.72 * wind)
		var crouch := (0.16 * finish) if slot == 4 else (0.33 * wind)
		for side: String in ["r", "l"]:
			turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, -crouch)
			turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, crouch * 1.7)
			turn_world(rig, "bip01 " + side + " foot", Vector3.RIGHT, -crouch * 0.7)
		var backswing := Vector3(-1.11, 0.82, -0.40) if slot == 4 else Vector3(-0.69, -0.31, 0.81)
		var hit := Vector3(-0.56, 0.86, 0.97) if slot == 4 else Vector3(-0.69, 1.31, -0.19)
		fit_arm(rig, "r", right.lerp(mid + backswing, wind).lerp(mid + hit, finish))
		fit_arm(rig, "l", left.lerp(mid + Vector3(0.52, 0.08, 0.69), 0.47 * finish))
		return
	if slot == 15 or slot == 16:
		turn_world(rig, "bip01 spine1", Vector3.UP, (0.52 if slot == 15 else -0.66) * strike)
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, 0.33 * strike)
		var step := "l" if slot == 15 else "r"
		turn_world(rig, "bip01 " + step + " thigh", Vector3.RIGHT, 0.18 * strike)
		turn_world(rig, "bip01 " + step + " calf", Vector3.RIGHT, 0.30 * strike)
		turn_world(rig, "bip01 " + step + " foot", Vector3.RIGHT, -0.31 * strike)
		var guard := Vector3(-0.39, 1.31, 0.37) if slot == 15 else Vector3(-0.90, 0.98, -0.15)
		fit_arm(rig, "r", right.lerp(mid + guard, strike))
		fit_arm(rig, "l", left.lerp(mid + Vector3(0.25, 0.79, 0.60), strike))
		return
	turn_world(rig, "bip01 head", Vector3.RIGHT, 0.35 * strike)
	turn_world(rig, "bip01 spine2", Vector3.UP, -0.12 * strike)
	fit_arm(rig, "r", right.lerp(mid + Vector3(-0.65, -0.02, 0.95), strike))
