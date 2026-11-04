extends "res://../scripts/bake-harpy-actions.gd"

const GROUND_CLIPS := {2: "Death2", 4: "RaisedWingRake", 6: "ForwardWingPunch", 15: "CrouchRecoil",
	16: "OpenWingGuard", 18: "WingDip"}
var kneeling_stagger := false

func run() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var input := "res://local-art/creatures/gargoyle-air-death-donor.gltf"
	assert(document.append_from_file(ProjectSettings.globalize_path(input), state) == OK)
	var donor := document.generate_scene(state)
	root.add_child(donor)
	var row := Registry.entry(4)
	var scenes := {}
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		var target := "res://local-art/creatures/gargoyle-actions-%s.scn" % treatment
		bake_gargoyle(source, treatment, donor, target)
		scenes[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}
	var inputs := {"gargoyle-air-death-donor.gltf": FileAccess.get_sha256(input)}
	for file: String in ["bake-gargoyle-actions.gd", "bake-harpy-actions.gd", "bake-mongbat-actions.gd",
			"bake-troll-actions.gd", "bake-skeleton-actions.gd"]:
		inputs[file] = FileAccess.get_sha256("res://../scripts/" + file)
	for file: String in ["WaterElementalFidgets.gd", "SourceGroundLookup.gd"]:
		inputs[file] = FileAccess.get_sha256("res://Presentation/" + file)
	var receipt := FileAccess.open("res://local-art/creatures/gargoyle-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": {"4": scenes}}))
	receipt.close()
	donor.free()
	quit()

func bake_gargoyle(source: String, treatment: String, donor: Node3D, target: String) -> void:
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var donor_rig := donor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	assert(rig.get_bone_count() == 55 and rig.get_bone_count() == donor_rig.get_bone_count())
	for bone in rig.get_bone_count():
		assert(rig.get_bone_name(bone) == donor_rig.get_bone_name(bone))
		assert(rig.get_bone_parent(bone) == donor_rig.get_bone_parent(bone))
		assert(rig.get_bone_rest(bone).is_equal_approx(donor_rig.get_bone_rest(bone)))
	var skin := Ground.skin_points(mesh, rig)
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	player.deterministic = true
	add_air_death(player, rig, skin, donor)
	refine_air_clearance(player, rig, skin)
	var skins: Array[Dictionary] = [skin]
	for slot: int in GROUND_CLIPS:
		assert(library.add_animation(GROUND_CLIPS[slot], fit_troll(player, rig, skins, slot)) == OK)
	kneeling_stagger = true
	assert(library.add_animation("KneelingStagger", fit_troll(player, rig, skins, 15)) == OK)
	kneeling_stagger = false
	Exact.check_earlier_keys(player, source)
	player.play("AirDeath", 0.0)
	player.advance(0.0)
	var initial := clearance(skin, rig)
	var minimum := initial
	for frame in 481:
		player.seek(player.current_animation_length * frame / 480.0, true)
		minimum = minf(minimum, clearance(skin, rig))
	var final := clearance(skin, rig)
	assert(minimum > 0.0 and absf(final - 0.004) < 0.001)
	print("GARGOYLE AIR: ", treatment, " first/minimum/final clearance ", [initial, minimum, final])
	player.stop()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var lift := smoothstep(0.0, 0.28, phase) * (1.0 - smoothstep(0.33, 0.59, phase))
	var pulse := smoothstep(0.24, 0.56, phase) * (1.0 - smoothstep(0.64, 1.0, phase))
	if slot == 2:
		var tuck := smoothstep(0.06, 0.53, phase)
		var fall := smoothstep(0.27, 0.95, phase)
		turn_world(rig, "bip01", Vector3.RIGHT, 1.37 * fall)
		turn_world(rig, "bip01 spine1", Vector3.FORWARD, -0.23 * fall)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.24 * fall)
		fold_legs(rig, tuck * (0.44 - 0.22 * fall))
		set_wings(rig, 0.62 * lift - 0.68 * fall, 0.54 * fall)
		for side: String in ["l", "r"]:
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.56 * fall)
		return
	if kneeling_stagger:
		var kneel := smoothstep(0.17, 0.61, phase) * (1.0 - smoothstep(0.79, 1.0, phase))
		turn_world(rig, "bip01 spine1", Vector3.UP, 0.38 * lift - 0.44 * kneel)
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, 0.36 * kneel)
		turn_world(rig, "bip01 l thigh", Vector3.RIGHT, -0.70 * kneel)
		turn_world(rig, "bip01 l calf", Vector3.RIGHT, 1.06 * kneel)
		turn_world(rig, "bip01 r thigh", Vector3.RIGHT, -0.36 * kneel)
		turn_world(rig, "bip01 r calf", Vector3.RIGHT, 0.87 * kneel)
		set_wings(rig, 0.53 * lift - 0.56 * kneel, -0.26 * kneel)
		return
	if slot == 18:
		set_wings(rig, -0.24 * pulse, 0.16 * pulse)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.22 * pulse)
		fold_legs(rig, 0.06 * pulse)
		return
	if slot in [15, 16]:
		var crouch := slot == 15
		set_wings(rig, (-0.48 if crouch else 0.71) * pulse, (0.35 if crouch else -0.35) * pulse)
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, (0.41 if crouch else -0.28) * pulse)
		turn_world(rig, "bip01 spine2", Vector3.UP, (0.36 if crouch else -0.38) * pulse)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.86 * pulse)
		fold_legs(rig, (0.19 if crouch else 0.09) * pulse)
		return
	var right := slot == 6
	var side := "r" if right else "l"
	var hip := joint_world(rig, "bip01 pelvis")
	var hand := joint_world(rig, "bip01 " + side + " hand")
	var stride := Vector3(-0.33, 0.32, 0.98) if right else Vector3(0.54, 0.74, 0.47)
	turn_world(rig, "bip01 spine1", Vector3.UP, (0.48 if right else -0.52) * pulse)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, (0.27 if right else -0.14) * pulse)
	set_wings(rig, (-0.33 if right else 0.76) * pulse, 0.29 * pulse)
	fit_arm(rig, side, hand.lerp(hip + stride, pulse))

func set_wings(rig: Skeleton3D, lift: float, spread: float) -> void:
	for side: String in ["l", "r"]:
		var sign := -1.0 if side == "l" else 1.0
		turn_world(rig, "gargoyle " + side + " mainwing1", Vector3.FORWARD, sign * lift)
		turn_world(rig, "gargoyle " + side + " mainwing1", Vector3.UP, sign * spread)
		turn_world(rig, "gargoyle " + side + " mainwing2", Vector3.UP, sign * spread * 0.45)

func fold_legs(rig: Skeleton3D, amount: float) -> void:
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, -amount)
		turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, 1.7 * amount)
