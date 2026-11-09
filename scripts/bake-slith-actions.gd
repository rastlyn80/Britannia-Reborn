extends "res://../scripts/bake-troll-actions.gd"

const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const SLITH := 734
const CLIPS := {
	3: ["Death2", "Death", 0.80],
	5: ["Attack2", "Attack", 0.90],
	15: ["SlithSideRecoil", "Hit", 0.70],
	23: ["SlithScent", "Idle", 1.00],
	26: ["SlithThreatLow", "Idle", 1.10],
	27: ["SlithThreatRise", "Idle", 0.90],
	28: ["SlithSettle", "Idle", 0.70],
}
const JOINTS := ["bip01", "bip01 spine", "bip01 spine1", "bip01 neck", "bip01 neck1", "bip01 head",
	"bip01 tail", "bip01 tail1", "bip01 tail2"]

func run() -> void:
	var row := Registry.entry(SLITH)
	if row.get("classic_gesture_batch") == "slith_actions":
		push_error("Refusing to overwrite the active Slith action package")
		quit(1)
		return
	assert(row.classic_action_categories["11"] == "ReadyStance" and row.new_action_categories["14"] == "ReadyStance")
	var receipts := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(path) == row.asset_sha256[treatment])
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		assert(rig.get_bone_count() == 28)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		for group: int in CLIPS:
			var spec: Array = CLIPS[group]
			assert(library.add_animation(spec[0], build(player, rig, group, spec[1], spec[2])) == OK)
		Exact.check_earlier_keys(player, path)
		player.stop()
		var scene := PackedScene.new()
		var target := "res://local-art/creatures/slith-actions-%s.scn" % treatment
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, target, ResourceSaver.FLAG_COMPRESS) == OK)
		receipts[treatment] = {"source": FileAccess.get_sha256(path), "scene": FileAccess.get_sha256(target)}
		model.free()
		print("SLITH ", treatment, " retained all previous keys and 28 source joints; seven UOP-guided fits")
	write_receipt(receipts)
	quit()

func write_receipt(receipts: Dictionary) -> void:
	var inputs := {}
	for name: String in ["bake-slith-actions.gd", "bake-troll-actions.gd", "bake-skeleton-actions.gd", "test-quadruped-actions.gd"]:
		inputs[name] = FileAccess.get_sha256("res://../scripts/" + name)
	var receipt := FileAccess.open("res://local-art/creatures/slith-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": receipts}, "	"))
	receipt.close()

func build(player: AnimationPlayer, rig: Skeleton3D, group: int, seed: String, duration: float) -> Animation:
	var original := player.get_animation(seed)
	var motion := original.duplicate(true) as Animation
	motion.length = duration
	motion.loop_mode = Animation.LOOP_NONE
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	for name: String in JOINTS:
		var path := NodePath("%s:%s" % [rig_path, name])
		if motion.find_track(path, Animation.TYPE_ROTATION_3D) < 0:
			motion.track_set_path(motion.add_track(Animation.TYPE_ROTATION_3D), path)
	var bones: Array[int] = []
	for track in motion.get_track_count():
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		var bone := rig.find_bone(motion.track_get_path(track).get_concatenated_subnames())
		assert(bone >= 0 or track < original.get_track_count())
		bones.append(bone)
	player.stop()
	player.play(seed, 0.0)
	player.advance(0.0)
	for index in 121:
		var phase := index / 120.0
		rig.reset_bone_poses()
		var base_time := 0.0 if seed == "Idle" else original.length * phase
		player.seek(base_time, true)
		rig.force_update_all_bone_transforms()
		shape(rig, group, phase)
		var time := phase * duration
		for track in bones.size():
			var bone := bones[track]
			match motion.track_get_type(track):
				Animation.TYPE_POSITION_3D:
					var position := rig.get_bone_pose_position(bone) if bone >= 0 else original.position_track_interpolate(track, base_time)
					motion.position_track_insert_key(track, time, position)
				Animation.TYPE_ROTATION_3D:
					var rotation := rig.get_bone_pose_rotation(bone) if bone >= 0 else original.rotation_track_interpolate(track, base_time)
					motion.rotation_track_insert_key(track, time, rotation)
				Animation.TYPE_SCALE_3D:
					var scale := rig.get_bone_pose_scale(bone) if bone >= 0 else original.scale_track_interpolate(track, base_time)
					motion.scale_track_insert_key(track, time, scale)
				_:
					assert(false, "Unexpected track in the source Slith rig")
	return motion

func shape(rig: Skeleton3D, group: int, phase: float) -> void:
	var pulse := smoothstep(0.04, 0.38, phase) * (1.0 - smoothstep(0.58, 0.98, phase))
	var tail_pulse := smoothstep(0.10, 0.48, phase) * (1.0 - smoothstep(0.60, 1.0, phase))
	if group == 3:
		var settle := smoothstep(0.10, 0.87, phase)
		turn_world(rig, "bip01", Vector3.FORWARD, -0.12 * settle)
		turn_world(rig, "bip01 neck1", Vector3.RIGHT, 0.18 * settle)
		return
	var profile: Array = {
		5: [0.11, 0.33, -0.03, 0.48, 0.15, -0.28, -0.48, -0.26],
		15: [-0.06, -0.23, -0.17, -0.31, -0.20, 0.20, 0.24, 0.13],
		23: [-0.03, 0.02, -0.12, 0.15, -0.18, -0.12, 0.09, 0.10],
		26: [-0.10, -0.18, -0.09, -0.22, -0.09, 0.17, 0.25, -0.07],
		27: [-0.21, 0.12, -0.33, 0.04, -0.30, -0.19, -0.13, -0.17],
		28: [0.15, -0.03, 0.14, 0.16, 0.17, 0.12, 0.21, 0.15],
	}[group]
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, profile[0] * pulse)
	turn_world(rig, "bip01 spine1", Vector3.UP, profile[1] * pulse)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, profile[2] * pulse)
	turn_world(rig, "bip01 neck1", Vector3.UP, profile[3] * pulse)
	turn_world(rig, "bip01 head", Vector3.RIGHT, profile[4] * pulse)
	turn_world(rig, "bip01 tail", Vector3.UP, profile[5] * tail_pulse)
	turn_world(rig, "bip01 tail1", Vector3.UP, profile[6] * tail_pulse)
	turn_world(rig, "bip01 tail2", Vector3.RIGHT, profile[7] * tail_pulse)
