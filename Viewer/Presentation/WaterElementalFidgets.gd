extends RefCounted

static func add(player: AnimationPlayer, rig: Skeleton3D, library: AnimationLibrary) -> void:
	for label: String in ["WaterArmSettle", "Fidget2"]:
		assert(library.add_animation(label, motion(player, rig, label == "Fidget2")) == OK)
	player.stop()

static func motion(player: AnimationPlayer, rig: Skeleton3D, reach: bool) -> Animation:
	var source := player.get_animation("Fidget")
	var clip := source.duplicate(true) as Animation
	clip.length = 0.88 if reach else 1.04
	clip.loop_mode = Animation.LOOP_NONE
	var tracks := {}
	for track in clip.get_track_count():
		var name := str(clip.track_get_path(track).get_concatenated_subnames())
		var value: Variant = source.track_get_key_value(track, 0)
		for key in range(clip.track_get_key_count(track) - 1, -1, -1):
			clip.track_remove_key(track, key)
		clip.track_insert_key(track, 0.0, value)
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and (name.begins_with("upperarm_") or name.begins_with("lowerarm_")):
			tracks[rig.find_bone(name)] = track
	assert(tracks.size() == 4 and not tracks.has(-1))
	for frame in 49:
		var phase := float(frame) / 48.0
		var amount := smoothstep(0.05, 0.46, phase) * (1.0 - smoothstep(0.59, 1.0, phase))
		player.play("Fidget", 0.0)
		player.advance(0.0)
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		if amount > 0.0:
			var left := Vector3(0.04, 0.015, 0.12) if reach else Vector3(0.028, -0.16, -0.085)
			var right := Vector3(-0.03, 0.025, 0.14) if reach else Vector3(-0.025, -0.025, -0.035)
			move_hand(rig, "l", left * amount)
			move_hand(rig, "r", right * amount)
		for bone: int in tracks:
			clip.rotation_track_insert_key(tracks[bone], phase * clip.length, rig.get_bone_pose_rotation(bone))
	return clip

static func move_hand(rig: Skeleton3D, side: String, displacement: Vector3) -> void:
	var shoulder := rig.find_bone("upperarm_" + side)
	var elbow := rig.find_bone("lowerarm_" + side)
	var hand := rig.find_bone("hand_" + side)
	var a := rig.get_bone_global_pose(shoulder).origin
	var b := rig.get_bone_global_pose(elbow).origin
	var c := rig.get_bone_global_pose(hand).origin
	var target := c + rig.global_basis.inverse() * displacement
	var direction := (target - a).normalized()
	var upper := a.distance_to(b)
	var lower := b.distance_to(c)
	var distance := clampf(a.distance_to(target), absf(upper - lower) + 0.001, upper + lower - 0.001)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var pole := (b - a).slide(direction).normalized()
	var bend := a + direction * along + pole * sqrt(maxf(0.0, upper * upper - along * along))
	aim(rig, shoulder, elbow, bend)
	aim(rig, elbow, hand, target)

static func aim(rig: Skeleton3D, bone: int, child: int, target: Vector3) -> void:
	var pose := rig.get_bone_global_pose(bone)
	var current := (rig.get_bone_global_pose(child).origin - pose.origin).normalized()
	pose.basis = Basis(Quaternion(current, (target - pose.origin).normalized())) * pose.basis
	rig.set_bone_global_pose(bone, pose)
