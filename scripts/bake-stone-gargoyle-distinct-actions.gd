extends "res://../scripts/bake-gargoyle-actions.gd"

const STONE := {15:"StoneWingRecoil", 18:"StoneArmCheck", 21:"StoneSettle"}
var stone_group := 0

func run() -> void:
	var row := Registry.entry(67)
	var scenes := {}
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	var input := "res://local-art/creatures/gargoyle-air-death-donor.gltf"
	assert(document.append_from_file(ProjectSettings.globalize_path(input), state) == OK)
	var donor := document.generate_scene(state)
	root.add_child(donor)
	var donor_rig := donor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for treatment: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		assert(rig.get_bone_count() == 55 and donor_rig.get_bone_count() == 55)
		for bone in rig.get_bone_count():
			assert(rig.get_bone_name(bone) == donor_rig.get_bone_name(bone))
			assert(rig.get_bone_parent(bone) == donor_rig.get_bone_parent(bone))
			assert(rig.get_bone_rest(bone).is_equal_approx(donor_rig.get_bone_rest(bone)))
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		var skins: Array[Dictionary] = [skin]
		for group: int in STONE:
			stone_group = group
			assert(library.add_animation(STONE[group], fit_troll(player, rig, skins, 18 if group == 21 else group)) == OK)
		add_air_death(player, rig, skin, donor)
		refine_air_clearance(player, rig, skin)
		Exact.check_earlier_keys(player, source)
		player.stop()
		var target := "res://local-art/creatures/stone-gargoyle-distinct-actions-%s.scn" % treatment
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
		scenes[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}
		model.free()
		print(treatment, " Stone Gargoyle, 55 exact rest joints, three Classic fits and recovered air death")
	donor.free()
	var receipt := FileAccess.open("res://local-art/creatures/stone-gargoyle-distinct-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	var inputs := {input.get_file(): FileAccess.get_sha256(input)}
	for path: String in ["bake-stone-gargoyle-distinct-actions.gd", "bake-gargoyle-actions.gd",
			"bake-harpy-actions.gd", "bake-mongbat-actions.gd", "bake-troll-actions.gd", "bake-skeleton-actions.gd"]:
		inputs[path] = FileAccess.get_sha256("res://../scripts/" + path)
	for path: String in ["SourceGroundLookup.gd", "WaterElementalFidgets.gd"]:
		inputs[path] = FileAccess.get_sha256("res://Presentation/" + path)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": scenes}))
	receipt.close()
	quit()

func pose_troll(rig: Skeleton3D, _slot: int, phase: float) -> void:
	var pulse := smoothstep(0.05, 0.40, phase) * (1.0 - smoothstep(0.57, 0.99, phase))
	if stone_group == 15:
		set_wings(rig, 0.76 * pulse, -0.32 * pulse)
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.16 * pulse)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.28 * pulse)
		fold_legs(rig, 0.12 * pulse)
	elif stone_group == 18:
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.59 * pulse)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.31 * pulse)
		turn_world(rig, "bip01 l forearm", Vector3.RIGHT, 0.20 * pulse)
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.13 * pulse)
		set_wings(rig, 0.05 * pulse, 0.08 * pulse)
	else:
		var tremor := sin(TAU * phase) * pulse
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.05 * tremor)
		turn_world(rig, "bip01 spine2", Vector3.FORWARD, 0.055 * pulse)
		set_wings(rig, 0.022 * tremor, 0.035 * pulse)
