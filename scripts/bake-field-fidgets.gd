extends SceneTree

const OUTPUT := "res://local-art/creatures/"
const DEER := {237: "deer_doe", 234: "deer_stag"}
const HIND_ARM := ["bip01 l upperarm", "bip01 l forearm", "bip01 l hand"]

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var scenes := {}
	for body: int in DEER:
		var treatments := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var label := "%s-%s" % [DEER[body], treatment]
			treatments[treatment] = bake(OUTPUT + label + ".gltf", "%s-fidgets-%s" % [DEER[body], treatment], body)
		scenes[str(body)] = treatments
	scenes["238"] = {"modern": bake("res://Art/Creatures/Rat/rat.glb", "rat-fidgets", 238)}
	var receipt := FileAccess.open(OUTPUT + "field-fidgets-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe_sha256": FileAccess.get_sha256(get_script().resource_path), "scenes": scenes}))
	receipt.close()
	quit()

func bake(source: String, label: String, body: int) -> Dictionary:
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rat := body == 238
	var head := "head" if rat else "bip01 head"
	var recipes := {
		"RatRear": ["Idle", 0.80, ["spine", "neck", "head", "base.001_L", "base.001_R"]],
		"Fidget2": ["Idle", 0.48, ["neck", "head", "tailbone"]],
	} if rat else {
		"DeerGroundCheck": ["Eat", 0.48, ["bip01 neck1", "bip01 head"]],
		"Fidget2": ["Idle", 0.48, ["bip01 neck", "bip01 neck1", "bip01 head"]],
	}
	var foreleg := {}
	if body == 237:
		recipes["DeerPaw"] = ["Idle", 0.8, HIND_ARM]
		player.play("Fidget", 0.0)
		player.advance(0.0)
		player.seek(player.current_animation_length * 0.40, true)
		for name: String in HIND_ARM:
			foreleg[name] = rig.get_bone_pose_rotation(rig.find_bone(name))
	for clip: String in recipes:
		var source_pose: String = recipes[clip][0]
		var source_time := player.get_animation(source_pose).length * 0.45 if clip == "DeerGroundCheck" else 0.0
		var motion := player.get_animation(source_pose).duplicate(true) as Animation
		motion.length = recipes[clip][1]
		motion.loop_mode = Animation.LOOP_NONE
		var tracks := {}
		for track in motion.get_track_count():
			var key := motion.track_find_key(track, source_time, Animation.FIND_MODE_NEAREST)
			var value: Variant = motion.track_get_key_value(track, key)
			for i in range(motion.track_get_key_count(track) - 1, -1, -1):
				motion.track_remove_key(track, i)
			motion.track_insert_key(track, 0.0, value)
			var bone := str(motion.track_get_path(track).get_concatenated_subnames())
			if motion.track_get_type(track) == Animation.TYPE_ROTATION_3D and bone in recipes[clip][2]:
				tracks[bone] = track
		assert(tracks.size() == recipes[clip][2].size())
		var extremes := Vector2(INF, -INF)
		for frame in 49:
			var phase := float(frame) / 48.0
			var pulse := sin(PI * phase) ** 2
			player.play(source_pose, 0.0)
			player.advance(0.0)
			player.seek(source_time, true)
			rig.force_update_all_bone_transforms()
			if clip == "RatRear":
				turn(rig, "spine", Vector3.RIGHT, -1.18 * pulse)
				turn(rig, "neck", Vector3.RIGHT, 0.24 * pulse)
				turn(rig, "head", Vector3.RIGHT, 0.24 * pulse)
				for arm: String in ["base.001_L", "base.001_R"]:
					turn(rig, arm, Vector3.RIGHT, 0.42 * pulse)
			elif rat:
				turn(rig, "neck", Vector3.RIGHT, 0.28 * pulse)
				turn(rig, "head", Vector3.UP, 0.24 * sin(TAU * phase) * pulse)
				turn(rig, "tailbone", Vector3.UP, 0.13 * pulse)
			elif clip == "DeerGroundCheck":
				turn(rig, "bip01 neck1", Vector3.UP, 0.30 * pulse)
				turn(rig, "bip01 head", Vector3.RIGHT, 0.13 * pulse)
			elif clip == "DeerPaw":
				for name: String in HIND_ARM:
					var bone := rig.find_bone(name)
					rig.set_bone_pose_rotation(bone, rig.get_bone_pose_rotation(bone).slerp(foreleg[name], pulse))
				rig.force_update_all_bone_transforms()
			else:
				turn(rig, "bip01 neck", Vector3.RIGHT, 0.24 * pulse)
				turn(rig, "bip01 neck1", Vector3.UP, 0.18 * sin(TAU * phase))
				turn(rig, "bip01 head", Vector3.RIGHT, 0.16 * pulse)
			for bone: String in tracks:
				motion.rotation_track_insert_key(tracks[bone], phase * motion.length, rig.get_bone_pose_rotation(rig.find_bone(bone)))
			var height := rig.to_global(rig.get_bone_global_pose(rig.find_bone(head)).origin).y
			extremes = Vector2(minf(extremes.x, height), maxf(extremes.y, height))
		assert(player.get_animation_library("").add_animation(clip, motion) == OK)
		print(label, " ", clip, " head range ", extremes)
	player.stop()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	var path := OUTPUT + label + ".scn"
	assert(ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	return {"source_sha256": FileAccess.get_sha256(source), "asset_sha256": FileAccess.get_sha256(path)}

func turn(rig: Skeleton3D, name: String, axis: Vector3, amount: float) -> void:
	var bone := rig.find_bone(name)
	var pose := rig.get_bone_global_pose(bone)
	var local_axis := (rig.global_basis.inverse() * axis).normalized()
	pose.basis = Basis(Quaternion(local_axis, amount)) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()
