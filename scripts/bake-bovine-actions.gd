extends "res://../scripts/bake-troll-actions.gd"

const FORMS := ["bovine_cow_spotted", "bovine_cow_brown", "bovine_bull_brown", "bovine_bull_spotted"]
# The shared fitter uses its own motion templates for timing and sampling.
# Native cattle group numbers are assigned by BovineActionsVisual.
const POSES := {6: "Attack2", 16: "Fidget2", 2: "Death2"}
const OUTPUT := "res://local-art/animals/bovine-actions-bake.json"
var baked: Dictionary = {}

func run() -> void:
	for kind: String in FORMS:
		for treatment: String in ["original", "rounded", "modern"]:
			bake_bovine(kind, treatment)
	var files := [get_script().resource_path, "res://../scripts/bake-troll-actions.gd",
		"res://../scripts/bake-skeleton-actions.gd", "res://Presentation/WaterElementalFidgets.gd",
		"res://Presentation/SourceGroundLookup.gd"]
	var inputs := {}
	for path: String in files:
		inputs[path.get_file()] = FileAccess.get_sha256(path)
	var output := FileAccess.open(OUTPUT, FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify({"inputs": inputs, "scenes": baked}, "\t"))
	output.close()
	quit()

func bake_bovine(kind: String, treatment: String) -> void:
	var source := "res://local-art/animals/%s-%s.gltf" % [kind, treatment]
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skins: Array[Dictionary] = [Ground.skin_points(mesh, rig)]
	for slot: int in POSES:
		assert(player.get_animation_library("").add_animation(POSES[slot], fit_troll(player, rig, skins, slot)) == OK)
	player.stop()
	var output := PackedScene.new()
	var target := "res://local-art/animals/%s-%s-actions.scn" % [kind, treatment]
	assert(output.pack(model) == OK and ResourceSaver.save(output, target, ResourceSaver.FLAG_COMPRESS) == OK)
	baked[target.get_file()] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}
	model.free()
	print("Baked ", kind, " ", treatment)

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	if slot == 2:
		var down := smoothstep(0.07, 0.75, phase)
		var tuck := smoothstep(0.06, 0.53, phase)
		turn_world(rig, "bip01", Vector3.FORWARD, 1.48 * down)
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.14 * down)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, 0.32 * down)
		turn_world(rig, "bip01 neck2", Vector3.RIGHT, -0.36 * down)
		turn_world(rig, "bip01 tail1", Vector3.UP, 0.25 * down)
		for side: String in ["l", "r"]:
			turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, -0.57 * tuck)
			turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, 0.73 * tuck)
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.24 * tuck)
			turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, -0.55 * tuck)
		return
	var pulse := smoothstep(0.04, 0.44, phase) * (1.0 - smoothstep(0.55, 1.0, phase))
	if slot == 6:
		turn_world(rig, "bip01 neck", Vector3.RIGHT, 0.31 * pulse)
		turn_world(rig, "bip01 neck2", Vector3.RIGHT, -0.13 * pulse)
		turn_world(rig, "bip01 head", Vector3.UP, -0.22 * pulse)
		turn_world(rig, "bip01 tail1", Vector3.UP, -0.36 * pulse)
	else:
		turn_world(rig, "bip01 neck", Vector3.RIGHT, -0.21 * pulse)
		turn_world(rig, "bip01 head", Vector3.UP, 0.22 * pulse)
		turn_world(rig, "bip01 tail1", Vector3.UP, 0.29 * pulse)
