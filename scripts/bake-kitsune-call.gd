extends "res://../scripts/bake-quadruped-actions.gd"

const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const SOURCE := 246

func run() -> void:
	var entry := Registry.entry(SOURCE)
	var scenes := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(entry, treatment)
		assert(FileAccess.get_sha256(source) == entry.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		assert(rig.get_bone_count() == 37)
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		var original := library.get_animation("Idle")
		var seed := original.duplicate(true) as Animation
		var rig_path := player.get_node(player.root_node).get_path_to(rig)
		for label: String in ["pelvis", "spine1", "neck", "head", "tail", "l upperarm", "l forearm", "r upperarm", "r forearm"]:
			var name := "bip01 " + label
			var joint := rig.find_bone(name)
			assert(joint >= 0)
			var path := NodePath("%s:%s" % [rig_path, name])
			if seed.find_track(path, Animation.TYPE_ROTATION_3D) < 0:
				var track := seed.add_track(Animation.TYPE_ROTATION_3D)
				seed.track_set_path(track, path)
				seed.rotation_track_insert_key(track, 0.0, rig.get_bone_rest(joint).basis.get_rotation_quaternion())
		library.remove_animation("Idle")
		assert(library.add_animation("Idle", seed) == OK)
		var call := build(SOURCE, 10, player, rig, skin)
		player.stop()
		library.remove_animation("Idle")
		assert(library.add_animation("Idle", original) == OK)
		assert(library.add_animation("KitsuneCall", call) == OK)
		Exact.check_earlier_keys(player, source)
		player.stop()
		var target := "res://local-art/creatures/bake-kitsune-call-%s.scn" % treatment
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
		scenes[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}
		model.free()
		print("Bake Kitsune group 10 ", treatment, ": 37 joints, exact earlier tracks")
	var receipt := FileAccess.open("res://local-art/creatures/bake-kitsune-call-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	var inputs := {}
	for path: String in ["res://../scripts/bake-kitsune-call.gd", "res://../scripts/bake-quadruped-actions.gd",
			"res://Presentation/SourceGroundLookup.gd", "res://Presentation/WaterElementalFidgets.gd"]:
		inputs[path.get_file()] = FileAccess.get_sha256(path)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": scenes}))
	receipt.close()
	quit()

func pose(rig: Skeleton3D, _wolf: bool, _slot: int, phase: float) -> float:
	var call := smoothstep(0.04, 0.46, phase) * (1.0 - smoothstep(0.67, 0.99, phase))
	turn(rig, "pelvis", Vector3.RIGHT, -0.31 * call)
	turn(rig, "spine1", Vector3.RIGHT, -0.20 * call)
	turn(rig, "neck", Vector3.RIGHT, -0.55 * call)
	turn(rig, "head", Vector3.RIGHT, -0.26 * call)
	turn(rig, "tail", Vector3.RIGHT, 0.39 * call)
	turn(rig, "l upperarm", Vector3.RIGHT, -0.32 * call)
	turn(rig, "l forearm", Vector3.RIGHT, 0.50 * call)
	turn(rig, "r upperarm", Vector3.RIGHT, -0.18 * call)
	turn(rig, "r forearm", Vector3.RIGHT, 0.29 * call)
	return 0.0
