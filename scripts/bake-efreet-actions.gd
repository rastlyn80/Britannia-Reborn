extends "res://../scripts/bake-troll-actions.gd"

const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const EFREET := 131
const MOTIONS := {
	3: ["Death2", "Death", 0.52],
	5: ["EfreetPalmSweep", "Attack", 0.64],
	6: ["EfreetReverseStrike", "Attack", 0.64],
	7: ["EfreetOverhead", "Idle", 0.48],
	8: ["EfreetHeldReach", "Idle", 0.80],
	11: ["EfreetGuardBend", "Idle", 0.68],
	12: ["Cast", "Idle", 1.55],
	15: ["EfreetSideRecoil", "Hit", 0.44],
	16: ["EfreetChestBrace", "Hit", 0.44],
	18: ["EfreetOpenArms", "Fidget", 0.82],
}
const DRIVEN := ["bip01", "bip01 spine1", "bip01 spine2", "bip01 head",
	"bip01 r upperarm", "bip01 r forearm", "bip01 l upperarm", "bip01 l forearm"]

func run() -> void:
	var row := Registry.entry(EFREET)
	var base_assets: Dictionary = row.get("classic_gesture_base_assets", {})
	var receipts := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source: String = base_assets.get(treatment, Registry.asset_path(row, treatment))
		var actor := (load(source) as PackedScene).instantiate()
		root.add_child(actor)
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		assert(rig.get_bone_count() == 30)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		for slot: int in MOTIONS:
			var spec: Array = MOTIONS[slot]
			assert(library.add_animation(spec[0], fit(player, rig, slot, spec[1], spec[2])) == OK)
		Exact.check_earlier_keys(player, source)
		player.stop()
		var result := PackedScene.new()
		assert(result.pack(actor) == OK)
		var output := "res://local-art/creatures/efreet-actions-%s.scn" % treatment
		assert(ResourceSaver.save(result, output,
			ResourceSaver.FLAG_COMPRESS) == OK)
		receipts[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
		actor.free()
		print("EFREET ", treatment, ": retained original 30 joints and source keys, 10 fitted actions")
	write_receipt(receipts)
	quit()

func fit(player: AnimationPlayer, rig: Skeleton3D, slot: int, seed: String, duration: float) -> Animation:
	var original := player.get_animation(seed)
	var clip := original.duplicate(true) as Animation
	clip.length = duration
	clip.loop_mode = Animation.LOOP_NONE
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	for name: String in DRIVEN:
		assert(rig.find_bone(name) >= 0)
		var path := NodePath("%s:%s" % [rig_path, name])
		if clip.find_track(path, Animation.TYPE_ROTATION_3D) < 0:
			clip.track_set_path(clip.add_track(Animation.TYPE_ROTATION_3D), path)
	var joints: Array[int] = []
	for track in clip.get_track_count():
		for key in range(clip.track_get_key_count(track) - 1, -1, -1):
			clip.track_remove_key(track, key)
		joints.append(rig.find_bone(str(clip.track_get_path(track).get_concatenated_subnames())))
	player.stop()
	player.play(seed, 0.0)
	player.advance(0.0)
	for frame in 121:
		var phase := float(frame) / 120.0
		var source_time := 0.0 if seed == "Idle" else original.length * phase
		rig.reset_bone_poses()
		player.seek(source_time, true)
		rig.force_update_all_bone_transforms()
		shape_motion(rig, slot, phase)
		for track in joints.size():
			var joint := joints[track]
			var t := phase * duration
			match clip.track_get_type(track):
				Animation.TYPE_POSITION_3D:
					var position := rig.get_bone_pose_position(joint) if joint >= 0 else original.position_track_interpolate(track, source_time)
					clip.position_track_insert_key(track, t, position)
				Animation.TYPE_ROTATION_3D:
					var rotation := rig.get_bone_pose_rotation(joint) if joint >= 0 else original.rotation_track_interpolate(track, source_time)
					clip.rotation_track_insert_key(track, t, rotation)
				Animation.TYPE_SCALE_3D:
					var scale := rig.get_bone_pose_scale(joint) if joint >= 0 else original.scale_track_interpolate(track, source_time)
					clip.scale_track_insert_key(track, t, scale)
				_:
					assert(false, "Unsupported original Efreet animation track")
	return clip

func shape_motion(rig: Skeleton3D, slot: int, phase: float) -> void:
	var lift := smoothstep(0.06, 0.42, phase) * (1.0 - smoothstep(0.62, 0.98, phase))
	var settle := smoothstep(0.06, 0.86, phase)
	if slot == 3:
		turn_world(rig, "bip01 spine2", Vector3.FORWARD, 0.36 * settle)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, 0.40 * settle)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, 0.26 * settle)
		return
	if slot == 12:
		turn_world(rig, "bip01", Vector3.UP, TAU * smoothstep(0.0, 1.0, phase))
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, 0.43 * lift)
		turn_world(rig, "bip01 r forearm", Vector3.UP, 0.78 * lift)
		turn_world(rig, "bip01 l forearm", Vector3.UP, -0.78 * lift)
		return
	var profile: Array = {
		5: [0.12, -0.36, -0.28, -0.15, -0.74, -0.25],
		6: [-0.14, 0.29, -1.22, -0.21, -0.34, -0.11],
		7: [-0.28, 0.16, -1.84, -0.42, -0.16, -0.11],
		8: [0.09, -0.17, -0.77, -0.34, -0.63, -0.26],
		11: [0.33, -0.20, -0.44, -0.62, -0.18, -0.37],
		15: [0.12, 0.36, -0.24, -0.42, -0.30, -0.12],
		16: [0.30, -0.18, -0.12, -0.69, -0.45, -0.35],
		18: [-0.15, 0.08, -0.63, 0.24, -0.32, 0.26],
	}[slot]
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, profile[0] * lift)
	turn_world(rig, "bip01 spine2", Vector3.UP, profile[1] * lift)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, profile[2] * lift)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, profile[3] * lift)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, profile[4] * lift)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, profile[5] * lift)

func write_receipt(scenes: Dictionary) -> void:
	var inputs := {}
	for path: String in [get_script().resource_path, "res://../scripts/bake-troll-actions.gd",
			"res://../scripts/bake-skeleton-actions.gd", "res://../scripts/test-quadruped-actions.gd"]:
		inputs[path.get_file()] = FileAccess.get_sha256(path)
	var file := FileAccess.open("res://local-art/creatures/efreet-actions-bake.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"inputs": inputs, "scenes": {str(EFREET): scenes}}, "\t") + "\n")
