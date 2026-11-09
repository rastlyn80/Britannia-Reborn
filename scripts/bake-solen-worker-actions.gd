extends "res://../scripts/bake-zombie-actions.gd"

const WORKER_JOINTS := ["bip01 spine2", "bip01 neck", "bip01 head", "antenna l", "antenna r",
	"mandible l", "mandible r", "bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm"]

func run() -> void:
	for body: int in [781, 805]:
		var entry := Registry.entry(body).duplicate(true)
		entry.assets = {}
		for treatment: String in ["original", "rounded", "modern"]:
			entry.assets[treatment] = "res://local-art/creatures/%s-%s.gltf" % [entry.kind, treatment]
		Registry.entries[body] = entry
		bake_body(body, "solen-worker-%d" % body, {15: "WorkerBrace"}, ["bake-solen-worker-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var library := player.get_animation_library("")
	var original := library.get_animation("Idle")
	var seed := original.duplicate(true) as Animation
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	assert(rig.get_bone_count() == 42)
	for name: String in WORKER_JOINTS:
		var joint := rig.find_bone(name)
		assert(joint >= 0, name)
		var path := NodePath("%s:%s" % [rig_path, name])
		if seed.find_track(path, Animation.TYPE_ROTATION_3D) < 0:
			var track := seed.add_track(Animation.TYPE_ROTATION_3D)
			seed.track_set_path(track, path)
			seed.rotation_track_insert_key(track, 0.0, rig.get_bone_rest(joint).basis.get_rotation_quaternion())
	player.stop()
	library.remove_animation("Idle")
	assert(library.add_animation("Idle", seed) == OK)
	var motion := super.fit_troll(player, rig, skins, slot)
	player.stop()
	library.remove_animation("Idle")
	assert(library.add_animation("Idle", original) == OK)
	return motion

func pose_troll(rig: Skeleton3D, _slot: int, phase: float) -> void:
	var brace := smoothstep(0.06, 0.46, phase) * (1.0 - smoothstep(0.52, 0.96, phase))
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, -0.21 * brace)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -0.19 * brace)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.13 * brace)
	for side: String in ["l", "r"]:
		var handed := -1.0 if side == "l" else 1.0
		turn_world(rig, "antenna " + side, Vector3.RIGHT, 0.56 * brace)
		turn_world(rig, "antenna " + side, Vector3.FORWARD, handed * 0.23 * brace)
		turn_world(rig, "mandible " + side, Vector3.UP, handed * 0.21 * brace)
		turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.22 * brace)
		turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, -0.18 * brace)
