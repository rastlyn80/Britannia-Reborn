extends SceneTree

const STEM := "res://local-art/creatures/sea_serpents_sea_serpent"
const LABELS := ["Fidget2", "Attack2"]
const FRONT := ["bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 neck1", "bip01 neck2", "bip01 neck3", "bip01 neck4"]
const TAIL := ["bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3"]
const NECK_PITCH := [0.30, 0.36, 0.33, 0.28, 0.23, 0.14, 0.04]
const BODY_JOINT := "bip01"
const JAW := "serpent jaw"

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var scenes := {}
	for treatment: String in ["original", "rounded", "modern"]:
		scenes[treatment] = bake_treatment(treatment)
	var receipt := FileAccess.open(STEM + "-classic-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path), "scenes": scenes}))
	receipt.close()
	print("SEA SERPENT: curling turn and rising strike on three source skins")
	quit()

func bake_treatment(treatment: String) -> Dictionary:
	var source := STEM + "-" + treatment + ".gltf"
	var output := STEM + "-classic-" + treatment + ".scn"
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("")
	for label: String in LABELS:
		var spin := label == "Fidget2"
		var motion := player.get_animation("Idle").duplicate(true) as Animation
		motion.length = 1.46 if spin else 1.23
		motion.loop_mode = Animation.LOOP_NONE
		var names := FRONT + (TAIL + [BODY_JOINT] if spin else [JAW])
		var tracks := {}
		for track in motion.get_track_count():
			for key in range(motion.track_get_key_count(track) - 1, 0, -1):
				motion.track_remove_key(track, key)
			if motion.track_get_type(track) != Animation.TYPE_ROTATION_3D:
				continue
			var name := str(motion.track_get_path(track).get_concatenated_subnames())
			if name in names:
				tracks[name] = track
		var rig_path := player.get_node(player.root_node).get_path_to(rig)
		for name: String in names:
			if tracks.has(name):
				continue
			var track := motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, NodePath("%s:%s" % [rig_path, name]))
			tracks[name] = track
		for frame in 89:
			var phase := float(frame) / 88.0
			if not spin:
				rig.reset_bone_pose(rig.find_bone(JAW))
			player.play("Idle", 0.0)
			player.advance(0.0)
			player.seek(0.0, true)
			rig.force_update_all_bone_transforms()
			if spin:
				var curl := smoothstep(0.06, 0.40, phase) * (1.0 - smoothstep(0.63, 0.98, phase))
				for name: String in FRONT:
					rotate_joint(rig, name, Vector3.UP, 0.15 * curl)
				for name: String in TAIL:
					rotate_joint(rig, name, Vector3.UP, -0.28 * curl)
				rotate_joint(rig, BODY_JOINT, Vector3.BACK, 0.20 * sin(phase * TAU))
				rotate_joint(rig, BODY_JOINT, Vector3.UP, -TAU * smoothstep(0.04, 0.98, phase))
			else:
				var dip := smoothstep(0.00, 0.22, phase) * (1.0 - smoothstep(0.22, 0.38, phase))
				var rise := smoothstep(0.22, 0.49, phase) * (1.0 - smoothstep(0.62, 0.98, phase))
				var open := smoothstep(0.29, 0.46, phase) * (1.0 - smoothstep(0.58, 0.79, phase))
				for i in FRONT.size():
					rotate_joint(rig, FRONT[i], Vector3.RIGHT, NECK_PITCH[i] * (0.32 * dip - rise))
				rotate_joint(rig, JAW, Vector3.RIGHT, 0.59 * open)
			for name: String in tracks:
				motion.rotation_track_insert_key(tracks[name], phase * motion.length, rig.get_bone_pose_rotation(rig.find_bone(name)))
		assert(library.add_animation(label, motion) == OK)
	player.stop()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	return {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}

func rotate_joint(rig: Skeleton3D, name: String, world_axis: Vector3, radians: float) -> void:
	var bone := rig.find_bone(name)
	assert(bone >= 0)
	var axis := (rig.global_basis.inverse() * world_axis).normalized()
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion(axis, radians)) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()
