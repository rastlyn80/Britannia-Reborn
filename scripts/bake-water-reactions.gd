extends SceneTree

const SOURCE := "res://Art/Creatures/Water/water-elemental.scn"
const OUTPUT := "res://local-art/creatures/water-reactions.scn"
const Arms := preload("res://Presentation/WaterElementalFidgets.gd")
const NAMES := {10: "Hit", 15: "WaterRightRecoil", 16: "WaterLeftRecoil"}

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	assert(FileAccess.get_sha256(SOURCE) == "afcbae91b71e0ae2a03473f2afcce861c590a9f075e54bcee36cc4590e21be63")
	assert(not FileAccess.file_exists("res://Art/Creatures/Water/water-reactions.scn"))
	var model := (load(SOURCE) as PackedScene).instantiate()
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	player.deterministic = true
	var library := player.get_animation_library("")
	library.rename_animation("Hit", "LegacyHit")
	for slot: int in NAMES:
		var clip := make_recoil(player, rig, slot)
		assert(library.add_animation(NAMES[slot], clip) == OK)
	player.stop()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK and ResourceSaver.save(packed, OUTPUT, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	var receipt := FileAccess.open("res://local-art/creatures/water-reactions.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path),
		"solver": FileAccess.get_sha256("res://Presentation/WaterElementalFidgets.gd"),
		"source": FileAccess.get_sha256(SOURCE), "scene": FileAccess.get_sha256(OUTPUT)}))
	receipt.close()
	print("WATER RECOILS: three distinct Classic reactions on the retained public rig")
	quit()

func make_recoil(player: AnimationPlayer, rig: Skeleton3D, slot: int) -> Animation:
	var source := player.get_animation("Idle")
	var clip := source.duplicate(true) as Animation
	clip.length = 0.64 if slot == 10 else 0.48
	clip.loop_mode = Animation.LOOP_NONE
	var tracks := {}
	var spine_names := ["spine_02", "spine_03"]
	for track in clip.get_track_count():
		var joint := str(clip.track_get_path(track).get_concatenated_subnames())
		for key in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, key)
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and (joint in spine_names
				or joint.begins_with("upperarm_") or joint.begins_with("lowerarm_")):
			tracks[joint] = track
	assert(tracks.size() >= 4)
	var active_side := -1.0 if slot == 15 else 1.0
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 49:
		var phase := float(frame) / 48.0
		var pulse := 1.0 - smoothstep(0.08, 0.92, phase) if slot == 10 else (
			smoothstep(-0.09, 0.44, phase) * (1.0 - smoothstep(0.45, 0.97, phase)))
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		for joint: String in spine_names:
			if not tracks.has(joint):
				continue
			var index := rig.find_bone(joint)
			var pose := rig.get_bone_global_pose(index)
			var axis := (rig.global_basis.inverse() * Vector3.UP).normalized()
			pose.basis = Basis(axis, active_side * (0.07 if slot == 10 else 0.26) * pulse) * pose.basis
			rig.set_bone_global_pose(index, pose)
		var left := Vector3(0.28, 0.33, 0.05) if slot == 10 else (
			Vector3(0.16, 0.21, 0.44) if slot == 16 else Vector3(-0.14, -0.02, 0.11))
		var right := Vector3(-0.30, 0.62, 0.15) if slot == 10 else (
			Vector3(-0.16, 0.19, 0.46) if slot == 15 else Vector3(0.14, -0.01, 0.12))
		Arms.move_hand(rig, "l", left * pulse)
		Arms.move_hand(rig, "r", right * pulse)
		for joint: String in tracks:
			clip.rotation_track_insert_key(tracks[joint], phase * clip.length, rig.get_bone_pose_rotation(rig.find_bone(joint)))
	return clip
