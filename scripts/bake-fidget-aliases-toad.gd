extends "res://../scripts/bake-skeleton-axe-trial.gd"

const ART := "res://local-art/creatures/"
const OUTPUT_RECEIPT := "res://../work/creatures/mul-motion-review/fidget-aliases-toad-bake.json"
const FIDGET_FORMS := {67: "gargoyles_gargoyle_stone", 80: "frogs_frog_giant", 149: "succubi_succubus"}
const GULP_JOINTS := ["bip01 neck", "bip01 head", "bip01 ponytail1",
	"bip01 ponytail11", "bip01 ponytail12", "bip01 ponytail13"]

func run() -> void:
	var forms := {}
	for body: int in FIDGET_FORMS:
		var variants := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var source := ART + str(FIDGET_FORMS[body]) + "-" + treatment + ".gltf"
			var model := (load(source) as PackedScene).instantiate()
			root.add_child(model)
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			assert(player.has_animation("Fidget"))
			if body == 80:
				add_gulp(player, model.find_children("*", "Skeleton3D", true, false)[0])
			player.stop()
			var scene := PackedScene.new()
			assert(scene.pack(model) == OK)
			var output := ART + "fidget-toad-%d-%s.scn" % [body, treatment]
			assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
			variants[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
			model.free()
		forms[str(body)] = variants
	var receipt := FileAccess.open(OUTPUT_RECEIPT, FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({
		"recipe": FileAccess.get_sha256(get_script().resource_path),
		"arm": FileAccess.get_sha256("res://../scripts/bake-skeleton-axe-trial.gd"),
		"forms": forms,
	}))
	receipt.close()
	print("FIDGET ALIASES AND TOAD: nine saved scenes")
	quit()

func add_gulp(player: AnimationPlayer, rig: Skeleton3D) -> void:
	var motion := player.get_animation("Idle").duplicate(true) as Animation
	motion.length = 0.78
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		var start: Variant = motion.track_get_key_value(track, 0)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		motion.track_insert_key(track, 0.0, start)
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var axis := (rig.global_basis.inverse() * Vector3.RIGHT).normalized()
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var joints: Array[int] = []
	var tracks: Array[int] = []
	var start: Array[Quaternion] = []
	for name: String in GULP_JOINTS:
		var joint := rig.find_bone(name)
		assert(joint >= 0)
		var path := NodePath("%s:%s" % [rig_path, name])
		var track := motion.find_track(path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, path)
		joints.append(joint)
		tracks.append(track)
		start.append(rig.get_bone_pose_rotation(joint))
	for sample in 91:
		var phase := float(sample) / 90.0
		var gulp := smoothstep(0.06, 0.40, phase) * (1.0 - smoothstep(0.52, 0.88, phase))
		var swallow := smoothstep(0.39, 0.58, phase) * (1.0 - smoothstep(0.68, 0.98, phase))
		for i in joints.size():
			rig.set_bone_pose_rotation(joints[i], start[i])
		for i in joints.size():
			var angle: float = [-0.095, 0.17, -0.10, 0.06, -0.14, 0.09][i] * gulp
			angle += [0.03, -0.10, 0.10, -0.09, 0.06, -0.06][i] * swallow
			rotate_joint(rig, joints[i], Quaternion(axis, angle))
			motion.rotation_track_insert_key(tracks[i], phase * motion.length, rig.get_bone_pose_rotation(joints[i]))
	assert(player.get_animation_library("").add_animation("ToadGulp", motion) == OK)
