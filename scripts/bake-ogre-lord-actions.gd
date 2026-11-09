extends "res://../scripts/bake-serpent-ogre-actions.gd"

var fitting_face := false

func run() -> void:
	var lord := Registry.entry(83)
	if lord.get("classic_gesture_batch") == "bomber_ogre_rune_dopple_actions":
		push_error("Refusing to overwrite an active Ogre Lord action package")
		quit(1)
		return
	assert(lord.kind == "ogres_ogre_lord" and Registry.entry(84) == lord)
	body = 1
	var variants := {}
	for treatment: String in lord.asset_sha256:
		var source := Registry.asset_path(lord, treatment)
		assert(FileAccess.get_sha256(source) == lord.asset_sha256[treatment])
		var target := "res://local-art/creatures/ogre-lord-actions-%s.scn" % treatment
		bake_lord(source, target)
		variants[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}
	var inputs := {}
	for path: String in [get_script().resource_path, "res://../scripts/bake-serpent-ogre-actions.gd",
			"res://../scripts/bake-troll-actions.gd", "res://../scripts/bake-skeleton-actions.gd",
			"res://Presentation/WaterElementalFidgets.gd", "res://Presentation/SourceGroundLookup.gd"]:
		inputs[path.get_file()] = FileAccess.get_sha256(path)
	var receipt := FileAccess.open("res://local-art/creatures/ogre-lord-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": {"83": variants}}))
	receipt.close()
	quit()

func bake_lord(source: String, target: String) -> void:
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skins: Array[Dictionary] = [Ground.skin_points(mesh, rig)]
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	player.deterministic = true
	for slot: int in FITS[body]:
		assert(library.add_animation(FITS[body][slot], fit_troll(player, rig, skins, slot)) == OK)
	fitting_face = true
	assert(library.add_animation("FaceWipe", fit_troll(player, rig, skins, 18)) == OK)
	fitting_face = false
	Exact.check_earlier_keys(player, source)
	player.stop()
	var output := PackedScene.new()
	assert(output.pack(model) == OK and ResourceSaver.save(output, target, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("Prepared Ogre Lord ", target)

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	if not fitting_face:
		super.pose_troll(rig, slot, phase)
		return
	var amount := smoothstep(0.08, 0.39, phase) * (1.0 - smoothstep(0.59, 0.97, phase))
	var sweep := smoothstep(0.28, 0.70, phase)
	var palm := joint_world(rig, "bip01 r hand")
	var mouth := joint_world(rig, "bip01 head") + Vector3(-0.30 + sweep * 0.17, -0.16, 0.36)
	fit_arm(rig, "r", palm.lerp(mouth, amount))
