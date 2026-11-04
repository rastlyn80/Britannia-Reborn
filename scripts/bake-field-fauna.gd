extends "res://../scripts/bake-troll-actions.gd"

const RATMAN_SLOTS := {2: "Death2", 5: "RatmanSwipe", 6: "RatmanLunge",
	15: "RatmanFlinch", 16: "RatmanBrace", 18: "RatmanSniff"}
const FELINE_SLOTS := {8: "Death2", 6: "FelineRearSwipe", 9: "FelineStretch", 10: "FelineSniff"}
const FIT_SLOTS := {5: 4, 8: 2, 9: 18, 10: 16}
var feline := false

func run() -> void:
	var scenes := {}
	for body: int in [42, 214, 63]:
		var row := Registry.entry(body)
		assert(not row.has("classic_gesture_batch"))
		var treatments := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var source := Registry.asset_path(row, treatment)
			var digest := FileAccess.get_sha256(source)
			assert(digest == row.asset_sha256[treatment])
			var output := "res://local-art/creatures/field-fauna-%d-%s.scn" % [body, treatment]
			bake_fauna(body, source, output)
			treatments[treatment] = {"source": digest, "scene": FileAccess.get_sha256(output)}
		scenes[str(body)] = treatments
	var receipt := FileAccess.open("res://local-art/creatures/field-fauna-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	var inputs := {}
	for path: String in [get_script().resource_path, "res://../scripts/bake-troll-actions.gd",
			"res://../scripts/bake-skeleton-actions.gd", "res://Presentation/WaterElementalFidgets.gd",
			"res://Presentation/SourceGroundLookup.gd"]:
		inputs[path.get_file()] = FileAccess.get_sha256(path)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": scenes}))
	receipt.close()
	quit()

func bake_fauna(body: int, path: String, output: String) -> void:
	feline = body != 42
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skins: Array[Dictionary] = [Ground.skin_points(mesh, rig)]
	var slots := FELINE_SLOTS if feline else RATMAN_SLOTS
	for slot: int in slots:
		var template_slot: int = FIT_SLOTS.get(slot, slot)
		var clip := fit_troll(player, rig, skins, template_slot)
		assert(player.get_animation_library("").add_animation(slots[slot], clip) == OK)
	player.stop()
	var result := PackedScene.new()
	assert(result.pack(model) == OK and ResourceSaver.save(result, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	if feline:
		pose_feline(rig, slot, phase)
	else:
		pose_ratman(rig, slot, phase)

func pose_ratman(rig: Skeleton3D, slot: int, phase: float) -> void:
	var centre := joint_world(rig, "bip01 pelvis")
	var right := joint_world(rig, "bip01 r hand")
	var left := joint_world(rig, "bip01 l hand")
	if slot == 2:
		var tip := smoothstep(0.04, 0.87, phase)
		var catch := smoothstep(0.04, 0.33, phase) * (1.0 - smoothstep(0.43, 0.94, phase))
		turn_world(rig, "bip01", Vector3.RIGHT, -2.72 * tip)
		turn_world(rig, "bip01", Vector3.FORWARD, 0.24 * tip)
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.27 * tip)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.29 * catch + 0.14 * tip)
		for side: String in ["r", "l"]:
			turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, 2.03 * tip)
			turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, -1.52 * tip)
		turn_world(rig, "bip01 tail", Vector3.UP, 0.72 * tip)
		turn_world(rig, "bip01 tail1", Vector3.RIGHT, -0.48 * tip)
		turn_world(rig, "bip01 tail2", Vector3.UP, 0.42 * tip)
		var new_hip := joint_world(rig, "bip01 pelvis")
		fit_arm(rig, "r", right.lerp(new_hip + Vector3(-0.28, 0.26, 0.51), catch).lerp(new_hip + Vector3(-0.38, 0.12, 0.19), tip))
		fit_arm(rig, "l", left.lerp(new_hip + Vector3(0.41, 0.22, 0.25), tip))
		return
	var peak := smoothstep(0.04, 0.37, phase) * (1.0 - smoothstep(0.56, 1.0, phase))
	if slot in [4, 6]:
		var sweep := smoothstep(0.18, 0.66, phase) * (1.0 - smoothstep(0.73, 1.0, phase))
		if slot == 4:
			turn_world(rig, "bip01 spine1", Vector3.UP, 0.50 * peak)
			fit_arm(rig, "r", right.lerp(centre + Vector3(-0.27, 0.22, 0.87), peak).lerp(
				centre + Vector3(-0.67, 0.10, 0.30), sweep))
			fit_arm(rig, "l", left.lerp(centre + Vector3(0.43, 0.21, 0.31), 0.58 * peak))
		else:
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.48 * peak)
			turn_world(rig, "bip01 spine2", Vector3.UP, -0.22 * peak)
			fit_arm(rig, "l", left.lerp(centre + Vector3(0.25, 0.21, 0.94), peak))
			fit_arm(rig, "r", right.lerp(centre + Vector3(-0.52, -0.13, 0.74), 0.7 * sweep))
		turn_world(rig, "bip01 tail", Vector3.UP, (-0.25 if slot == 4 else 0.24) * peak)
		return
	if slot in [15, 16]:
		var flinch := (0.37 if slot == 16 else -0.22) * peak
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, flinch)
		turn_world(rig, "bip01 neck", Vector3.UP, (-0.17 if slot == 15 else 0.27) * peak)
		turn_world(rig, "bip01 tail1", Vector3.RIGHT, 0.35 * peak)
		if slot == 15:
			fit_arm(rig, "r", right.lerp(centre + Vector3(-0.29, 0.07, 0.65), peak))
		else:
			fit_arm(rig, "l", left.lerp(centre + Vector3(0.23, 0.40, 0.73), peak))
		return
	turn_world(rig, "bip01 head", Vector3.UP, 0.26 * peak)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, 0.13 * peak)
	turn_world(rig, "bip01 tail", Vector3.UP, -0.24 * peak)
	turn_world(rig, "bip01 tail2", Vector3.UP, 0.31 * peak)

func pose_feline(rig: Skeleton3D, slot: int, phase: float) -> void:
	var peak := smoothstep(0.03, 0.38, phase) * (1.0 - smoothstep(0.49, 1.0, phase))
	if slot == 16:
		turn_world(rig, "bip01 neck", Vector3.RIGHT, -0.34 * peak)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.29 * peak)
		turn_world(rig, "bip01 tail2", Vector3.UP, 0.32 * peak)
		return
	if slot == 18:
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.24 * peak)
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, 0.28 * peak)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.34 * peak)
		turn_world(rig, "bip01 tail", Vector3.RIGHT, -0.42 * peak)
		for side: String in ["l", "r"]:
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.57 * peak)
			turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, -0.22 * peak)
		return
	if slot == 6:
		turn_world(rig, "bip01", Vector3.RIGHT, -1.0 * peak)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, 0.24 * peak)
		turn_world(rig, "bip01 tail1", Vector3.RIGHT, 0.60 * peak)
		for side: String in ["l", "r"]:
			turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, 0.83 * peak)
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.41 * peak)
			turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, -0.40 * peak)
		return
	var tuck := smoothstep(0.06, 0.43, phase) * (1.0 - smoothstep(0.56, 0.84, phase))
	var roll := smoothstep(0.37, 0.98, phase)
	turn_world(rig, "bip01", Vector3.RIGHT, -0.70 * tuck + 0.21 * roll)
	turn_world(rig, "bip01", Vector3.FORWARD, 1.46 * roll)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, 0.24 * roll)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.22 * roll)
	turn_world(rig, "bip01 tail1", Vector3.UP, 0.54 * roll)
	turn_world(rig, "bip01 tail2", Vector3.RIGHT, 0.44 * roll)
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, 0.50 * roll)
		turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, -0.67 * roll)
		turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.46 * roll)
		turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, -0.34 * roll)
