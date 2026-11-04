extends SceneTree

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const SOURCE := "res://Art/Creatures/Cat/cat.glb"
const OUTPUT := "res://local-art/creatures/cat-actions.scn"
const ROUTES := {8: "Death2", 9: "CatStretch", 10: "Fidget2"}
const DURATIONS := {8: 0.96, 9: 0.80, 10: 0.48}

func _initialize() -> void:
	create_timer(18.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var model := (load(SOURCE) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	for slot: int in ROUTES:
		assert(player.get_animation_library("").add_animation(ROUTES[slot], build(slot, player, rig, skin)) == OK)
	player.stop()
	var output := PackedScene.new()
	assert(output.pack(model) == OK)
	assert(ResourceSaver.save(output, OUTPUT, ResourceSaver.FLAG_COMPRESS) == OK)
	var receipt := FileAccess.open("res://local-art/creatures/cat-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"source": FileAccess.get_sha256(SOURCE), "scene": FileAccess.get_sha256(OUTPUT),
		"recipe": FileAccess.get_sha256(get_script().resource_path),
		"skin_solver": FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd")}))
	receipt.close()
	model.free()
	quit()

func build(slot: int, player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = DURATIONS[slot]
	clip.loop_mode = Animation.LOOP_NONE
	var rotations := {}
	for track in clip.get_track_count():
		var label := str(clip.track_get_path(track).get_concatenated_subnames())
		for key in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, key)
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and (label.begins_with("bip01") or label.begins_with("tail")):
			rotations[label] = track
	var hip := rig.find_bone("bip01")
	var hip_path := clip.track_get_path(rotations["bip01"])
	var placement := clip.find_track(hip_path, Animation.TYPE_POSITION_3D)
	if placement < 0:
		placement = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(placement, hip_path)
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 65:
		var phase := float(frame) / 64.0
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		pose(rig, slot, phase)
		var pelvis := rig.get_bone_global_pose(hip)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		pelvis.origin += rig.global_basis.inverse() * Vector3.UP * (0.0025 - gap)
		rig.set_bone_global_pose(hip, pelvis)
		rig.force_update_all_bone_transforms()
		var time := phase * clip.length
		clip.position_track_insert_key(placement, time, rig.get_bone_pose_position(hip))
		for label: String in rotations:
			clip.rotation_track_insert_key(rotations[label], time, rig.get_bone_pose_rotation(rig.find_bone(label)))
	return clip

func pose(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.05, 0.44, phase) * (1.0 - smoothstep(0.59, 1.0, phase))
	if slot == 10:
		turn(rig, "bip01 neck", Vector3.RIGHT, -0.25 * pulse)
		turn(rig, "bip01 head", Vector3.RIGHT, -0.22 * pulse)
		turn(rig, "tail2", Vector3.UP, -0.38 * pulse)
		return
	if slot == 9:
		turn(rig, "bip01 spine", Vector3.RIGHT, 0.48 * pulse)
		turn(rig, "bip01 neck", Vector3.RIGHT, 0.24 * pulse)
		turn(rig, "bip01 head", Vector3.RIGHT, -0.42 * pulse)
		turn(rig, "tail1", Vector3.RIGHT, -0.43 * pulse)
		for side: String in ["l", "r"]:
			turn(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.64 * pulse)
			turn(rig, "bip01 " + side + " forearm", Vector3.RIGHT, -0.24 * pulse)
		return
	var rear := smoothstep(0.03, 0.38, phase) * (1.0 - smoothstep(0.39, 0.70, phase))
	var fall := smoothstep(0.37, 0.89, phase)
	turn(rig, "bip01", Vector3.RIGHT, -0.70 * rear + 0.20 * fall)
	turn(rig, "bip01", Vector3.FORWARD, 1.33 * fall)
	turn(rig, "bip01 neck", Vector3.RIGHT, -0.29 * rear + 0.32 * fall)
	turn(rig, "bip01 head", Vector3.FORWARD, -0.29 * fall)
	turn(rig, "tail1", Vector3.UP, 0.71 * fall)
	turn(rig, "tail2", Vector3.UP, 0.46 * fall)
	turn(rig, "tail3", Vector3.RIGHT, -0.43 * fall)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		turn(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.42 * rear - 0.63 * fall)
		turn(rig, "bip01 " + side + " forearm", Vector3.RIGHT, (0.31 + sign * 0.16) * fall)
		turn(rig, "bip01 " + side + " thigh", Vector3.RIGHT, (0.61 - sign * 0.11) * fall)
		turn(rig, "bip01 " + side + " calf", Vector3.RIGHT, -0.80 * fall)

func turn(rig: Skeleton3D, label: String, axis: Vector3, amount: float) -> void:
	var bone := rig.find_bone(label)
	assert(bone >= 0)
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion((rig.global_basis.inverse() * axis).normalized(), amount)) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()
