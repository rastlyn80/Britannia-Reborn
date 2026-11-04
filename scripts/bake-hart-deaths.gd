extends "res://../scripts/bake-quadruped-actions.gd"
## Fit the two stag collapses while keeping its accepted deer gestures.

func run() -> void:
	var row := Registry.entry(234)
	assert(row.kind == "deer_stag" and not row.has("classic_gesture_batch"))
	var scenes := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source: String = row.assets[treatment]
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var target := "res://local-art/creatures/hart-death-%s.scn" % treatment
		bake(234, source, target)
		scenes[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}
	var receipt := FileAccess.open("res://local-art/creatures/hart-death-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path),
		"baker": FileAccess.get_sha256("res://../scripts/bake-quadruped-actions.gd"),
		"arm_solver": FileAccess.get_sha256("res://Presentation/WaterElementalFidgets.gd"),
		"skin_solver": FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd"), "scenes": scenes}))
	receipt.close()
	quit()

func bake(body: int, path: String, output: String) -> void:
	assert(body == 234)
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var library := player.get_animation_library("")
	library.rename_animation("Death", "RecoveredDeath")
	player.deterministic = true
	for slot: int in [8, 12]:
		assert(library.add_animation(ROUTES[slot], build(body, slot, player, rig, skin)) == OK)
	player.stop()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK and ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()

func pose(rig: Skeleton3D, _wolf: bool, slot: int, phase: float) -> float:
	var rear := slot == 8
	var anticipation := smoothstep(0.01, 0.35, phase) * (1.0 - smoothstep(0.37, 0.70, phase))
	var roll := smoothstep(0.34 if rear else 0.48, 0.86, phase)
	var settle := smoothstep(0.58, 0.97, phase)
	var side := 1.0 if rear else -1.0
	turn(rig, "pelvis", Vector3.RIGHT, -0.82 * anticipation + 0.13 * roll if rear else 0.52 * anticipation + 0.24 * roll)
	turn(rig, "pelvis", Vector3.FORWARD, side * 1.31 * roll)
	turn(rig, "spine1", Vector3.RIGHT, 0.10 * roll)
	turn(rig, "neck", Vector3.RIGHT, (-0.21 if rear else 0.48) * anticipation + 0.31 * roll)
	turn(rig, "neck1", Vector3.UP, side * 0.35 * roll)
	turn(rig, "head", Vector3.FORWARD, -side * 0.44 * settle)
	for leg: String in ["l", "r"]:
		var sign := 1.0 if leg == "l" else -1.0
		turn(rig, leg + " upperarm", Vector3.RIGHT, (0.25 if rear else -0.28) * anticipation)
		turn(rig, leg + " forearm", Vector3.RIGHT, -0.67 * anticipation)
		turn(rig, leg + " thigh", Vector3.RIGHT, (0.35 + sign * 0.14) * roll)
		turn(rig, leg + " calf", Vector3.RIGHT, -0.41 * roll)
		var lateral := side * 0.24 + sign * 0.04
		settle_chain(rig, leg + " upperarm", leg + " forearm", leg + " hand",
			Vector3(lateral, -0.19, 0.10 + sign * 0.06), settle)
		settle_chain(rig, leg + " thigh", leg + " calf", leg + " horselink",
			Vector3(lateral, -0.18, 0.03 + sign * 0.10), settle)
		turn(rig, leg + " horselink", Vector3.RIGHT, -0.44 * settle)
	translate_hip(rig, Vector3(side * 0.13 * roll, 0.0, (0.12 if not rear else -0.06) * roll))
	return 0.0
