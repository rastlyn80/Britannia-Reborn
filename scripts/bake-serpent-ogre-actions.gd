extends "res://../scripts/bake-troll-actions.gd"

const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const FITS := {
	21: {2: "Death2", 4: "CoilSnap", 6: "LongStrike", 15: "NeckDrawback",
		16: "LowNeckRecoil", 18: "TailRipple"},
	1: {2: "Death2", 4: "OverheadHammer", 6: "HighUppercut", 15: "ShoulderTurn",
		16: "ChestBrace", 18: "ShoulderScratch"},
}
var body := 0

func run() -> void:
	var scenes := {}
	for identity: int in [21, 1]:
		body = identity
		var row := Registry.entry(body)
		var variants := {}
		for treatment: String in row.assets:
			var source := Registry.asset_path(row, treatment)
			var target := "res://local-art/creatures/serpent-ogre-actions-%d-%s.scn" % [body, treatment]
			bake_creature(source, target)
			variants[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}
		scenes[str(body)] = variants
	var inputs := {}
	for file: String in [get_script().resource_path, "res://../scripts/bake-troll-actions.gd",
			"res://../scripts/bake-skeleton-actions.gd", "res://Presentation/WaterElementalFidgets.gd",
			"res://Presentation/SourceGroundLookup.gd"]:
		inputs[file.get_file()] = FileAccess.get_sha256(file)
	var receipt := FileAccess.open("res://local-art/creatures/serpent-ogre-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": scenes}))
	receipt.close()
	quit()

func bake_creature(source: String, target: String) -> void:
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
	Exact.check_earlier_keys(player, source)
	player.stop()
	var output := PackedScene.new()
	assert(output.pack(model) == OK and ResourceSaver.save(output, target, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("Prepared ", target)

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.03, 0.44, phase) * (1.0 - smoothstep(0.58, 1.0, phase))
	if body == 21:
		pose_serpent(rig, slot, phase, pulse)
	else:
		pose_ogre(rig, slot, phase, pulse)

func pose_serpent(rig: Skeleton3D, slot: int, phase: float, pulse: float) -> void:
	if slot == 2:
		var rise := smoothstep(0.04, 0.31, phase) * (1.0 - smoothstep(0.34, 0.67, phase))
		var fall := smoothstep(0.33, 0.94, phase)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, -0.32 * rise + 0.67 * fall)
		turn_world(rig, "bip01 neck1", Vector3.FORWARD, -0.90 * fall)
		turn_world(rig, "bip01 neck2", Vector3.FORWARD, 0.25 * fall)
		turn_world(rig, "bip01 neck3", Vector3.UP, -0.46 * fall)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.40 * fall)
		turn_world(rig, "bip01 tail3", Vector3.UP, 0.35 * fall)
		return
	if slot == 18:
		turn_world(rig, "bip01 neck1", Vector3.UP, -0.24 * pulse)
		turn_world(rig, "bip01 neck3", Vector3.RIGHT, 0.20 * pulse)
		turn_world(rig, "bip01 tail2", Vector3.UP, -0.41 * pulse)
		turn_world(rig, "bip01 tail4", Vector3.UP, 0.60 * pulse)
		return
	if slot == 6:
		var aim := joint_world(rig, "bip01 head") - joint_world(rig, "bip01 neck")
		aim.y = 0.16
		aim = aim.normalized()
		var chain := ["neck", "neck1", "neck2", "neck3", "neck4", "head"]
		for i in chain.size() - 1:
			var upper := rig.find_bone("bip01 " + chain[i])
			var lower := rig.find_bone("bip01 " + chain[i + 1])
			var root := rig.get_bone_global_pose(upper).origin
			var end := rig.get_bone_global_pose(lower).origin
			var target := root + rig.global_basis.inverse() * aim * root.distance_to(end)
			Arms.aim(rig, upper, lower, end.lerp(target, 0.87 * pulse))
			rig.force_update_all_bone_transforms()
		turn_world(rig, "bip01 tail1", Vector3.UP, -0.38 * pulse)
		turn_world(rig, "bip01 tail3", Vector3.UP, -0.27 * pulse)
		return
	var bend: float = {4: 0.43, 15: -0.55, 16: 0.31}[slot]
	var yaw: float = {4: -0.48, 15: 0.34, 16: -0.27}[slot]
	turn_world(rig, "bip01 neck", Vector3.RIGHT, bend * pulse)
	turn_world(rig, "bip01 neck2", Vector3.UP, yaw * pulse)
	turn_world(rig, "bip01 neck3", Vector3.RIGHT, -bend * 0.50 * pulse)
	turn_world(rig, "bip01 head", Vector3.UP, yaw * 0.55 * pulse)
	turn_world(rig, "bip01 tail1", Vector3.UP, -yaw * 0.49 * pulse)
	turn_world(rig, "bip01 tail3", Vector3.UP, yaw * 0.51 * pulse)

func pose_ogre(rig: Skeleton3D, slot: int, phase: float, pulse: float) -> void:
	if slot == 2:
		var buckle := smoothstep(0.06, 0.53, phase)
		var fall := smoothstep(0.16, 0.88, phase)
		turn_world(rig, "bip01", Vector3.RIGHT, -1.37 * fall)
		turn_world(rig, "bip01 spine1", Vector3.FORWARD, 0.32 * fall)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.12 * fall)
		for side: String in ["l", "r"]:
			turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, 0.56 * buckle)
			turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, -0.87 * buckle)
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.FORWARD, (0.43 if side == "l" else -0.43) * fall)
		return
	var hip := joint_world(rig, "bip01 pelvis")
	var side := "l" if slot in [4, 15] else "r"
	var sign := 1.0 if side == "l" else -1.0
	var hand := joint_world(rig, "bip01 " + side + " hand")
	if slot in [4, 6]:
		var wind := smoothstep(0.0, 0.28, phase) * (1.0 - smoothstep(0.30, 0.56, phase))
		var strike := smoothstep(0.30, 0.61, phase) * (1.0 - smoothstep(0.66, 0.99, phase))
		var start := Vector3(0.60, 1.58, 0.04) if slot == 4 else Vector3(-0.43, 0.19, 0.56)
		var end := Vector3(0.45, 0.44, 1.08) if slot == 4 else Vector3(-0.39, 1.36, 0.71)
		turn_world(rig, "bip01 spine1", Vector3.UP, sign * (0.30 * wind - 0.28 * strike))
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, (0.37 if slot == 4 else -0.20) * strike)
		fit_arm(rig, side, hand.lerp(hip + start, wind).lerp(hip + end, strike))
		return
	var target: Vector3 = {
		15: Vector3(sign * 0.72, 0.87, 0.39),
		16: Vector3(sign * 0.25, 0.97, 0.48),
		18: Vector3(sign * 0.34, 1.35, 0.25),
	}[slot]
	turn_world(rig, "bip01 spine1", Vector3.UP, sign * 0.20 * pulse)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, (0.16 if slot != 18 else -0.22) * pulse)
	fit_arm(rig, side, hand.lerp(hip + target, pulse))
