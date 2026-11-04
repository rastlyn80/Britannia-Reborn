extends "res://../scripts/bake-dog-bear-actions.gd"

const Exact := preload("res://../scripts/test-quadruped-actions.gd")

func run() -> void:
	var variants := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := Registry.asset_path(Registry.entry(213), treatment)
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		library.rename_animation("Attack", "RecoveredAttack")
		assert(library.add_animation("Attack", calibrated_attack(player, rig, skin)) == OK)
		var labels := {4: "MuzzleLift", 6: "PolarRearStrike", 10: "HindCrouch", 12: "Death2"}
		for slot: int in labels:
			assert(library.add_animation(labels[slot], build(213, slot, player, rig, skin)) == OK)
		Exact.check_earlier_keys(player, path)
		player.stop()
		var packed := PackedScene.new()
		var output := "res://local-art/creatures/polar-bear-distinct-actions-%s.scn" % treatment
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS) == OK)
		variants[treatment] = {"source": FileAccess.get_sha256(path), "scene": FileAccess.get_sha256(output)}
		model.free()
		print("POLAR BEAR ", treatment, ": 4 fitted motions with all earlier keys retained")
	var inputs := {}
	for path: String in [get_script().resource_path, "res://../scripts/bake-dog-bear-actions.gd",
		"res://../scripts/bake-quadruped-actions.gd", "res://Presentation/WaterElementalFidgets.gd",
		"res://Presentation/SourceGroundLookup.gd"]:
		inputs[path.get_file()] = FileAccess.get_sha256(path)
	var receipt := FileAccess.open("res://local-art/creatures/polar-bear-distinct-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": {"213": variants}}))
	receipt.close()
	quit()

func pose(rig: Skeleton3D, wolf: bool, slot: int, phase: float) -> float:
	if slot == 6:
		return super.pose(rig, wolf, slot, phase)
	var pulse := smoothstep(0.02, 0.34, phase) * (1.0 - smoothstep(0.42, 1.0, phase))
	if slot == 4:
		turn(rig, "spine1", Vector3.RIGHT, -0.12 * pulse)
		turn(rig, "neck", Vector3.RIGHT, -0.25 * pulse)
		turn(rig, "head", Vector3.UP, 0.17 * pulse)
		return 0.0
	if slot == 10:
		turn(rig, "pelvis", Vector3.RIGHT, 0.14 * pulse)
		turn(rig, "spine1", Vector3.RIGHT, -0.10 * pulse)
		turn(rig, "head", Vector3.RIGHT, 0.24 * pulse)
		for leg: String in ["l", "r"]:
			turn(rig, leg + " thigh", Vector3.RIGHT, -0.28 * pulse)
			turn(rig, leg + " calf", Vector3.RIGHT, 0.42 * pulse)
			turn(rig, leg + " upperarm", Vector3.RIGHT, 0.36 * pulse)
			turn(rig, leg + " forearm", Vector3.RIGHT, -0.38 * pulse)
		return 0.0
	var fall := smoothstep(0.10, 0.85, phase)
	var spread := smoothstep(0.28, 0.97, phase)
	turn(rig, "pelvis", Vector3.RIGHT, 0.02 * fall)
	turn(rig, "pelvis", Vector3.FORWARD, 0.07 * fall)
	turn(rig, "spine1", Vector3.RIGHT, 0.03 * fall)
	turn(rig, "neck", Vector3.RIGHT, 0.27 * fall)
	turn(rig, "head", Vector3.RIGHT, -0.22 * fall)
	for leg: String in ["l", "r"]:
		var sign := 1.0 if leg == "l" else -1.0
		turn(rig, leg + " upperarm", Vector3.RIGHT, -1.45 * spread)
		turn(rig, leg + " upperarm", Vector3.FORWARD, -0.12 * sign * spread)
		turn(rig, leg + " forearm", Vector3.RIGHT, 0.13 * spread)
		turn(rig, leg + " hand", Vector3.RIGHT, 0.08 * spread)
		turn(rig, leg + " thigh", Vector3.RIGHT, 1.29 * spread)
		turn(rig, leg + " calf", Vector3.RIGHT, -0.28 * spread)
		turn(rig, leg + " horselink", Vector3.RIGHT, -0.11 * spread)
	translate_hip(rig, Vector3(0.03 * fall, 0.0, 0.12 * fall))
	return 0.0
