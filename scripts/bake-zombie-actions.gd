extends "res://../scripts/bake-troll-actions.gd"

const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const CLIPS := {2: "Death2", 4: "BackhandReach", 6: "OverheadClaw", 15: "DoubleOver",
	16: "StaggerBack", 18: "LookUp"}

func run() -> void:
	bake_body(3, "zombie", CLIPS, ["bake-zombie-actions.gd"])
	quit()

func bake_body(body: int, name: String, clips: Dictionary, inputs: Array[String]) -> void:
	var row := Registry.entry(body)
	var treatments := {}
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		add_retained_actions(player, rig, row, treatment)
		var skins: Array[Dictionary] = []
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin != null:
				skins.append(Ground.skin_points(mesh, rig))
		assert(not skins.is_empty())
		for slot: int in clips:
			assert(library.add_animation(clips[slot], fit_troll(player, rig, skins, slot)) == OK)
		Exact.check_earlier_keys(player, source)
		player.stop()
		var output := PackedScene.new()
		var target := "res://local-art/creatures/%s-actions-%s.scn" % [name, treatment]
		assert(output.pack(model) == OK and ResourceSaver.save(output, target, ResourceSaver.FLAG_COMPRESS) == OK)
		treatments[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}
		model.free()
		print(name.to_upper(), ": ", treatment, ", retained keys and ", clips.size(), " fitted clips")
	write_receipt(name + "-actions", body, treatments, inputs)

func add_retained_actions(_player: AnimationPlayer, _rig: Skeleton3D, _row: Dictionary, _treatment: String) -> void:
	pass

func write_receipt(name: String, body: int, scenes: Dictionary, inputs: Array[String]) -> void:
	var files := {}
	for file: String in inputs + ["bake-troll-actions.gd", "bake-skeleton-actions.gd"]:
		files[file] = FileAccess.get_sha256("res://../scripts/" + file)
	for file: String in ["WaterElementalFidgets.gd", "SourceGroundLookup.gd"]:
		files[file] = FileAccess.get_sha256("res://Presentation/" + file)
	var receipt := FileAccess.open("res://local-art/creatures/%s-bake.json" % name, FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"inputs": files, "scenes": {str(body): scenes}}))
	receipt.close()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var lift := smoothstep(0.0, 0.23, phase) * (1.0 - smoothstep(0.30, 0.56, phase))
	var release := smoothstep(0.25, 0.57, phase) * (1.0 - smoothstep(0.66, 1.0, phase))
	if slot == 2:
		var fall := smoothstep(0.08, 0.88, phase)
		var lift_arms := smoothstep(0.0, 0.31, phase) * (1.0 - smoothstep(0.54, 0.97, phase))
		turn_world(rig, "bip01", Vector3.RIGHT, -1.49 * fall)
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.22 * lift_arms)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.27 * fall)
		for side: String in ["l", "r"]:
			var sign := -1.0 if side == "l" else 1.0
			var leg := (0.22 + sign * 0.10) * fall
			turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, leg)
			turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, -0.34 * fall)
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -1.17 * lift_arms)
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.FORWARD, sign * 0.46 * fall)
		return
	if slot == 18:
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.20 * release)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.31 * release)
		return
	if slot == 15:
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.46 * release)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.22 * release)
		for side: String in ["l", "r"]:
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.37 * release)
		return
	var hip := joint_world(rig, "bip01 pelvis")
	var side := "l" if slot == 16 else "r"
	var hand := joint_world(rig, "bip01 " + side + " hand")
	var scale := hip.distance_to(joint_world(rig, "bip01 head"))
	var wind := Vector3(-0.45, 1.04, -0.28) if slot == 4 else Vector3(-0.34, 1.51, 0.26)
	var contact := {4: Vector3(-0.36, 0.56, 1.09), 6: Vector3(-0.25, 0.18, 0.98),
		16: Vector3(0.60, 0.97, 0.48)}[slot] as Vector3
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, (0.45 if slot == 6 else -0.17) * release)
	turn_world(rig, "bip01 spine1", Vector3.UP, (0.38 if slot == 16 else -0.31) * release)
	if slot == 16:
		turn_world(rig, "bip01 l thigh", Vector3.RIGHT, 0.32 * release)
		turn_world(rig, "bip01 l calf", Vector3.RIGHT, -0.24 * release)
		lift = 0.0
	fit_arm(rig, side, hand.lerp(hip + wind * scale, lift).lerp(hip + contact * scale, release))
