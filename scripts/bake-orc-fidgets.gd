extends "res://../scripts/bake-classic-gesture-trials.gd"

const ARM := ["r clavicle", "r upperarm", "r forearm", "r hand", "head"]
const STEM := "res://local-art/creatures/orcs_orc"

func run() -> void:
	var scenes := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source := "%s-%s.gltf" % [STEM, treatment]
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for label: String in ["OrcHighGesture", "Fidget2"]:
			assert(player.get_animation_library("").add_animation(label,
				build_gesture(player, rig, label == "OrcHighGesture")) == OK)
		player.stop()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		var asset := "%s-fidgets-%s.scn" % [STEM, treatment]
		assert(ResourceSaver.save(scene, asset, ResourceSaver.FLAG_COMPRESS) == OK)
		scenes[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(asset)}
		model.free()
	var receipt := FileAccess.open("res://../work/creatures/mul-motion-review/orc-fidgets-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path),
		"aim_solver": FileAccess.get_sha256("res://../scripts/bake-classic-gesture-trials.gd"),
		"scenes": scenes}))
	receipt.close()
	print("ORC: three source scenes with separate high and waist fidgets")
	quit()

func build_gesture(player: AnimationPlayer, rig: Skeleton3D, high: bool) -> Animation:
	var idle := player.get_animation("Idle")
	var attack := player.get_animation("Attack2")
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var clip := idle.duplicate(true) as Animation
	clip.length = 0.86 if high else 0.68
	clip.loop_mode = Animation.LOOP_NONE
	for track in clip.get_track_count():
		var first: Variant = idle.track_get_key_value(track, 0)
		for key in range(clip.track_get_key_count(track) - 1, -1, -1):
			clip.track_remove_key(track, key)
		clip.track_insert_key(track, 0.0, first)
	var joints: Array[Dictionary] = []
	for name: String in ARM:
		var bone := rig.find_bone("bip01 " + name)
		assert(bone >= 0)
		var path := NodePath("%s:%s" % [rig_path, rig.get_bone_name(bone)])
		var track := clip.find_track(path, Animation.TYPE_ROTATION_3D)
		var donor := attack.find_track(path, Animation.TYPE_ROTATION_3D)
		assert(track >= 0 and donor >= 0)
		joints.append({"bone": bone, "track": track, "donor": donor,
			"start": attack.rotation_track_interpolate(donor, 0.0).inverse()})
	for sample in 91:
		var phase := float(sample) / 90.0
		var amount := smoothstep(0.04, 0.29, phase) * (1.0 - smoothstep(0.59, 0.99, phase))
		player.play("Idle", 0.0)
		player.advance(0.0)
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		if not high and amount > 0.0:
			waist_gesture(rig, amount)
		for joint: Dictionary in joints:
			var rotation := rig.get_bone_pose_rotation(joint.bone)
			if high:
				# Use the wind-up arm pose and return along the same path.
				var lift := attack.rotation_track_interpolate(joint.donor, attack.length * 0.28 * amount)
				rotation = (rotation * joint.start * lift).normalized()
			clip.rotation_track_insert_key(joint.track, phase * clip.length, rotation)
	return clip

func waist_gesture(rig: Skeleton3D, amount: float) -> void:
	var shoulder := rig.find_bone("bip01 r upperarm")
	var elbow := rig.find_bone("bip01 r forearm")
	var hand := rig.find_bone("bip01 r hand")
	var spine := rig.find_bone("bip01 spine1")
	var upper_joint := rig.get_bone_global_pose(shoulder).origin
	var lower_joint := rig.get_bone_global_pose(elbow).origin
	var wrist := rig.get_bone_global_pose(hand).origin
	var waist := rig.to_global(rig.get_bone_global_pose(spine).origin)
	var target := wrist.lerp(rig.to_local(waist + Vector3(-0.05, -0.20, 0.39)), amount)
	var direction := (target - upper_joint).normalized()
	var upper := upper_joint.distance_to(lower_joint)
	var lower := lower_joint.distance_to(wrist)
	var distance := clampf(upper_joint.distance_to(target), absf(upper - lower) + 0.0001, upper + lower - 0.0001)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var outside := (rig.global_basis.inverse() * Vector3(-0.75, -0.44, -0.10)).normalized()
	var pole := (outside - direction * direction.dot(outside)).normalized()
	var bend := upper_joint + direction * along + pole * sqrt(maxf(0.0, upper * upper - along * along))
	aim(rig, shoulder, elbow, bend)
	aim(rig, elbow, hand, target)
