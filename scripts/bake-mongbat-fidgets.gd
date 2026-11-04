extends "res://../scripts/bake-classic-gesture-trials.gd"

const ART := "res://local-art/creatures/"

func run() -> void:
	var scenes := {}
	for treatment: String in ["original", "rounded", "modern"]:
		scenes[treatment] = bake_treatment(treatment)
	var receipt := FileAccess.open(ART + "mongbat-fidgets-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path),
		"aim_solver": FileAccess.get_sha256("res://../scripts/bake-classic-gesture-trials.gd"), "scenes": scenes}))
	receipt.close()
	print("MONGBAT: two separate fidgets on the three existing WingSettle scenes")
	quit()

func bake_treatment(treatment: String) -> Dictionary:
	var source := ART + "mul-gesture-39-%s.scn" % treatment
	var output := ART + "mongbat-fidgets-%s.scn" % treatment
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for label: String in ["MongbatArmLift", "Fidget2"]:
		var overhead := label == "Fidget2"
		var clip := player.get_animation("WingSettle").duplicate(true) as Animation
		var shoulder := rig.find_bone("bip01 l upperarm")
		var elbow := rig.find_bone("bip01 l forearm")
		var hand := rig.find_bone("bip01 l hand")
		assert(shoulder >= 0 and elbow >= 0 and hand >= 0)
		var path := player.get_node(player.root_node).get_path_to(rig)
		var tracks := {}
		for track in clip.get_track_count():
			for key in range(clip.track_get_key_count(track) - 1, 0, -1):
				clip.track_remove_key(track, key)
		for bone: int in [shoulder, elbow]:
			var track_path := NodePath("%s:%s" % [path, rig.get_bone_name(bone)])
			var track := clip.find_track(track_path, Animation.TYPE_ROTATION_3D)
			if track == -1:
				track = clip.add_track(Animation.TYPE_ROTATION_3D)
				clip.track_set_path(track, track_path)
			tracks[bone] = track
		for frame in 53:
			var phase := float(frame) / 52.0
			var rise := smoothstep(0.01, 0.29 if overhead else 0.24, phase)
			var fall := smoothstep(0.62 if overhead else 0.44, 0.99, phase)
			var amount := rise * (1.0 - fall)
			player.play("WingSettle", 0.0)
			player.advance(0.0)
			player.seek(0.0, true)
			rig.force_update_all_bone_transforms()
			if amount > 0.0:
				pose_arm(rig, shoulder, elbow, hand, overhead, amount)
			for bone: int in tracks:
				clip.rotation_track_insert_key(tracks[bone], phase * clip.length, rig.get_bone_pose_rotation(bone))
		assert(player.get_animation_library("").add_animation(label, clip) == OK)
	player.stop()
	var saved := PackedScene.new()
	assert(saved.pack(model) == OK)
	assert(ResourceSaver.save(saved, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	return {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}

func pose_arm(rig: Skeleton3D, shoulder: int, elbow: int, hand: int, overhead: bool, amount: float) -> void:
	var a := rig.get_bone_global_pose(shoulder).origin
	var b := rig.get_bone_global_pose(elbow).origin
	var c := rig.get_bone_global_pose(hand).origin
	var goal := Vector3(0.30, 1.93, 0.34) if overhead else Vector3(0.32, 1.13, 0.46)
	var target := c.lerp(rig.to_local(goal), amount)
	var direction := (target - a).normalized()
	var upper := a.distance_to(b)
	var lower := b.distance_to(c)
	var distance := clampf(a.distance_to(target), absf(upper - lower) + 0.001, upper + lower - 0.001)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var outside := (rig.global_basis.inverse() * Vector3(0.87, -0.33, 0.18)).normalized()
	var pole := outside.slide(direction).normalized()
	var bend := a + direction * along + pole * sqrt(maxf(0.0, upper * upper - along * along))
	aim(rig, shoulder, elbow, bend)
	aim(rig, elbow, hand, target)
