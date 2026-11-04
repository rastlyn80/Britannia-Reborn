extends "res://../scripts/bake-skeleton-axe-trial.gd"

const CREATURES := {
	"occurrence_next/skittering_hopper": "HopperCheck",
	"horde_rune/horde_demon": "HordeJawCheck",
}

func run() -> void:
	var forms := {}
	for source: String in CREATURES:
		var treatments := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var path := "res://local-art/creatures/%s-%s.gltf" % [source, treatment]
			var model := (load(path) as PackedScene).instantiate()
			root.add_child(model)
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var label: String = CREATURES[source]
			var motion: Animation
			if label == "HopperCheck":
				motion = retime_hopper(player.get_animation("Fidget"))
			else:
				motion = open_jaw(player, model.find_children("*", "Skeleton3D", true, false)[0])
			assert(player.get_animation_library("").add_animation(label, motion) == OK)
			player.stop()
			var scene := PackedScene.new()
			assert(scene.pack(model) == OK)
			var output := "res://local-art/creatures/%s-slot11-%s.scn" % [source, treatment]
			assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
			treatments[treatment] = {"source": FileAccess.get_sha256(path), "scene": FileAccess.get_sha256(output)}
			model.free()
		forms[source.get_file()] = treatments
	var receipt := FileAccess.open("res://../work/creatures/mul-motion-review/hopper-horde-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({
		"recipe": FileAccess.get_sha256(get_script().resource_path),
		"solver": FileAccess.get_sha256("res://../scripts/bake-skeleton-axe-trial.gd"),
		"forms": forms,
	}))
	receipt.close()
	print("HOPPER AND HORDE: six source scenes with distinct Classic 11 actions")
	quit()

func retime_hopper(donor: Animation) -> Animation:
	var motion := donor.duplicate(true) as Animation
	motion.length = 0.78
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		clear_keys(motion, track)
		for sample in 115:
			var phase := float(sample) / 114.0
			var mapped := 0.44 * smoothstep(0.0, 0.48, phase) + 0.56 * smoothstep(0.38, 1.0, phase)
			var source := donor.length * mapped
			var target := motion.length * phase
			match donor.track_get_type(track):
				Animation.TYPE_POSITION_3D:
					motion.position_track_insert_key(track, target, donor.position_track_interpolate(track, source))
				Animation.TYPE_ROTATION_3D:
					motion.rotation_track_insert_key(track, target, donor.rotation_track_interpolate(track, source))
				Animation.TYPE_SCALE_3D:
					motion.scale_track_insert_key(track, target, donor.scale_track_interpolate(track, source))
				_:
					assert(false, "Unexpected Hopper source track type")
	return motion

func open_jaw(player: AnimationPlayer, rig: Skeleton3D) -> Animation:
	var motion := player.get_animation("Idle").duplicate(true) as Animation
	var donor := player.get_animation("Fidget")
	motion.length = 0.72
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		var first: Variant = motion.track_get_key_value(track, 0)
		clear_keys(motion, track)
		motion.track_insert_key(track, 0.0, first)
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var joints: Array[int] = []
	var tracks: Array[int] = []
	var neutral: Array[Quaternion] = []
	for name: String in ["bip01 neck", "bip01 head", "bone_jaw"]:
		var joint := rig.find_bone(name)
		var track := motion.find_track(NodePath("%s:%s" % [rig_path, name]), Animation.TYPE_ROTATION_3D)
		assert(joint >= 0 and track >= 0)
		clear_keys(motion, track)
		joints.append(joint)
		tracks.append(track)
		neutral.append(rig.get_bone_pose_rotation(joint))
	var donor_track := donor.find_track(NodePath("%s:bone_jaw" % rig_path), Animation.TYPE_ROTATION_3D)
	assert(donor_track >= 0)
	var open := donor.rotation_track_interpolate(donor_track, 0.194879)
	var axis := (rig.global_basis.inverse() * Vector3.RIGHT).normalized()
	for sample in 91:
		var phase := float(sample) / 90.0
		var peak := smoothstep(0.05, 0.25, phase) * (1.0 - smoothstep(0.33, 0.67, phase))
		var settle := smoothstep(0.29, 0.52, phase) * (1.0 - smoothstep(0.60, 0.92, phase))
		for i in joints.size():
			rig.set_bone_pose_rotation(joints[i], neutral[i])
		rotate_joint(rig, joints[0], Quaternion(axis, 0.04 * peak - 0.03 * settle))
		rotate_joint(rig, joints[1], Quaternion(axis, 0.09 * peak - 0.035 * settle))
		rig.set_bone_pose_rotation(joints[2], neutral[2].slerp(open, 0.63 * peak))
		for i in joints.size():
			motion.rotation_track_insert_key(tracks[i], phase * motion.length, rig.get_bone_pose_rotation(joints[i]))
	return motion

func clear_keys(motion: Animation, track: int) -> void:
	for key in range(motion.track_get_key_count(track) - 1, -1, -1):
		motion.track_remove_key(track, key)
