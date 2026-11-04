extends "res://../scripts/bake-dog-bear-actions.gd"

const Exact := preload("res://../scripts/test-quadruped-actions.gd")
var active_body := 0
var active_group := 0

func run() -> void:
	var scenes := {}
	for body: int in [209, 212, 290]:
		active_body = body
		var variants := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var source := Registry.asset_path(Registry.entry(body), treatment)
			var target := "res://local-art/creatures/grazers-grizzly-actions-%d-%s.scn" % [body, treatment]
			bake(body, source, target)
			variants[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}
		scenes[str(body)] = variants
	save_receipt("res://local-art/creatures/grazers-grizzly-actions-bake.json", scenes)
	quit()

func bake(body: int, path: String, output: String) -> void:
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
	library.rename_animation("Death", "RecoveredDeath")
	library.rename_animation("Attack", "RecoveredAttack")
	active_group = 5
	var attack := build(body, 6, player, rig, skin) if body == 212 else calibrated_attack(player, rig, skin)
	assert(library.add_animation("Attack", attack) == OK)
	for slot: int in ROUTES:
		active_group = slot
		assert(library.add_animation(ROUTES[slot], build(body, slot, player, rig, skin)) == OK)
	Exact.check_earlier_keys(player, path)
	player.stop()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK and ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("Prepared ", output)

func pose(rig: Skeleton3D, _wolf: bool, slot: int, phase: float) -> float:
	if active_body == 212 and active_group in [5, 8, 12]:
		return super.pose(rig, false, slot, phase)
	var pulse := smoothstep(0.04, 0.42, phase) * (1.0 - smoothstep(0.56, 0.99, phase))
	if slot == 4:
		turn(rig, "neck", Vector3.UP, (-0.53 if active_body == 212 else -0.34) * pulse)
		if active_body != 212:
			turn(rig, "neck1", Vector3.UP, -0.24 * pulse)
		turn(rig, "head", Vector3.UP, -0.24 * pulse)
		turn(rig, "head", Vector3.RIGHT, -0.17 * pulse)
		return 0.0
	if slot == 10:
		turn(rig, "neck", Vector3.RIGHT, 0.24 * pulse)
		turn(rig, "head", Vector3.RIGHT, 0.22 * pulse)
		turn(rig, "head", Vector3.UP, 0.19 * pulse)
		return 0.0
	if slot == 6:
		var grizzly := active_body == 212
		turn(rig, "pelvis", Vector3.RIGHT, (-0.31 if grizzly else -0.12) * pulse)
		turn(rig, "neck", Vector3.RIGHT, 0.34 * pulse)
		turn(rig, "head", Vector3.RIGHT, (-0.12 if grizzly else 0.24) * pulse)
		turn(rig, "l upperarm", Vector3.RIGHT, -0.45 * pulse)
		turn(rig, "l forearm", Vector3.RIGHT, 0.42 * pulse)
		turn(rig, "r upperarm", Vector3.RIGHT, -0.18 * pulse)
		translate_hip(rig, Vector3(0.0, 0.0, (0.14 if grizzly else 0.21) * pulse))
		return 0.025 * pulse
	var fall := smoothstep(0.08, 0.83, phase)
	var tuck := smoothstep(0.06, 0.59, phase)
	var roll := (1.32 if active_body == 209 else 0.15) if slot == 8 else -1.48
	turn(rig, "pelvis", Vector3.FORWARD, roll * fall)
	var boar_belly := active_body == 290 and slot == 8
	var pitch := -0.12 if boar_belly else (0.20 if slot == 8 else -0.10)
	turn(rig, "pelvis", Vector3.RIGHT, pitch * fall)
	turn(rig, "neck", Vector3.RIGHT, (0.13 if boar_belly else 0.27) * fall)
	turn(rig, "head", Vector3.RIGHT, (-0.15 if boar_belly else -0.22) * fall)
	for side: String in ["l", "r"]:
		turn(rig, side + " thigh", Vector3.RIGHT, -0.65 * tuck)
		turn(rig, side + " calf", Vector3.RIGHT, 0.81 * tuck)
		turn(rig, side + " upperarm", Vector3.RIGHT, -0.50 * tuck)
		turn(rig, side + " forearm", Vector3.RIGHT, 0.71 * tuck)
		if boar_belly:
			var lateral := 0.06 if side == "l" else -0.06
			var settle := smoothstep(0.36, 0.92, phase)
			settle_chain(rig, side + " upperarm", side + " forearm", side + " hand",
				Vector3(lateral, -0.065, -0.17), settle)
			settle_chain(rig, side + " thigh", side + " calf", side + " horselink",
				Vector3(lateral, -0.055, 0.14), settle)
			turn(rig, side + " foot", Vector3.RIGHT, -0.75 * settle)
	translate_hip(rig, Vector3(signf(roll) * 0.14 * fall, 0.0, 0.15 * fall))
	return 0.0

func save_receipt(path: String, scenes: Dictionary) -> void:
	var inputs := {}
	for file: String in [get_script().resource_path, "res://../scripts/bake-dog-bear-actions.gd",
		"res://../scripts/bake-quadruped-actions.gd",
		"res://Presentation/WaterElementalFidgets.gd",
		"res://Presentation/SourceGroundLookup.gd"]:
		inputs[file.get_file()] = FileAccess.get_sha256(file)
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify({"inputs": inputs, "scenes": scenes}, "\t"))
	output.close()
