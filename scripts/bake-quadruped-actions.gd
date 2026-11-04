extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Arms := preload("res://Presentation/WaterElementalFidgets.gd")
const ROUTES := {4: "LookSide", 6: "Attack2", 8: "Death", 10: "Fidget2", 12: "Death2"}
const DURATIONS := {4: 0.48, 6: 0.8, 8: 0.96, 10: 0.48, 12: 0.96}
const BONES := ["pelvis", "spine", "spine1", "neck", "neck1", "head", "tail",
	"l clavicle", "r clavicle", "l upperarm", "r upperarm", "l forearm", "r forearm",
	"l hand", "r hand", "l thigh", "r thigh", "l calf", "r calf", "l horselink",
	"r horselink", "l foot", "r foot"]

func _initialize() -> void:
	create_timer(28.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var scenes := {}
	for body: int in [225, 207, 223]:
		var row := Registry.entry(body)
		assert(not row.has("classic_gesture_batch"))
		var treatments := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var source := Registry.asset_path(row, treatment)
			assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
			var output := "res://local-art/creatures/quadruped-actions-%d-%s.scn" % [body, treatment]
			bake(body, source, output)
			treatments[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
		scenes[str(body)] = treatments
	var receipt := FileAccess.open("res://local-art/creatures/quadruped-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path),
		"arm_solver": FileAccess.get_sha256("res://Presentation/WaterElementalFidgets.gd"),
		"skin_solver": FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd"), "scenes": scenes}))
	receipt.close()
	quit()

func bake(body: int, path: String, output: String) -> void:
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var library := player.get_animation_library("")
	library.rename_animation("Death", "RecoveredDeath")
	player.deterministic = true
	for slot: int in ROUTES:
		if slot == 4 and body == 225:
			continue
		assert(library.add_animation(ROUTES[slot], build(body, slot, player, rig, skin)) == OK)
	player.stop()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()

func build(body: int, slot: int, player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = DURATIONS[slot]
	clip.loop_mode = Animation.LOOP_NONE
	var rotations := {}
	for track in clip.get_track_count():
		var label := str(clip.track_get_path(track).get_concatenated_subnames()).trim_prefix("bip01 ")
		for key in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, key)
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and label in BONES:
			rotations[label] = track
	var pelvis := rig.find_bone("bip01 pelvis")
	var pelvis_path := clip.track_get_path(rotations.pelvis)
	var placement := clip.find_track(pelvis_path, Animation.TYPE_POSITION_3D)
	if placement < 0:
		placement = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(placement, pelvis_path)
	player.play("Idle", 0.0)
	player.advance(0.0)
	for sample in 65:
		var phase := float(sample) / 64.0
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		var lift := pose(rig, body == 225, slot, phase)
		var hip := rig.get_bone_global_pose(pelvis)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		hip.origin += rig.global_basis.inverse() * Vector3.UP * (lift + 0.004 - gap)
		rig.set_bone_global_pose(pelvis, hip)
		rig.force_update_all_bone_transforms()
		var time := phase * clip.length
		clip.position_track_insert_key(placement, time, rig.get_bone_pose_position(pelvis))
		for label: String in rotations:
			clip.rotation_track_insert_key(rotations[label], time, rig.get_bone_pose_rotation(rig.find_bone("bip01 " + label)))
	return clip

func pose(rig: Skeleton3D, wolf: bool, slot: int, phase: float) -> float:
	var pulse := smoothstep(0.0, 0.46, phase) * (1.0 - smoothstep(0.54, 1.0, phase))
	if slot in [8, 12]:
		return collapse(rig, wolf, slot, phase)
	if slot == 4:
		turn(rig, "neck", Vector3.UP, -0.35 * pulse)
		turn(rig, "neck1", Vector3.UP, -0.46 * pulse)
		turn(rig, "head", Vector3.UP, -0.24 * pulse)
		return 0.0
	if slot == 10:
		turn(rig, "neck", Vector3.RIGHT, (-0.17 if wolf else -0.13) * pulse)
		turn(rig, "neck1", Vector3.RIGHT, -0.24 * pulse)
		turn(rig, "head", Vector3.RIGHT, -0.29 * pulse)
		turn(rig, "l forearm", Vector3.RIGHT, -0.22 * pulse if wolf else 0.0)
		return 0.0
	var strike := smoothstep(0.07, 0.48, phase) * (1.0 - smoothstep(0.49, 0.99, phase))
	turn(rig, "pelvis", Vector3.RIGHT, (-0.56 if wolf else 0.09) * strike)
	turn(rig, "spine1", Vector3.RIGHT, (0.19 if wolf else 0.16) * strike)
	turn(rig, "neck", Vector3.RIGHT, (0.11 if wolf else 0.34) * strike)
	turn(rig, "head", Vector3.RIGHT, (-0.07 if wolf else -0.35) * strike)
	turn(rig, "tail", Vector3.RIGHT, -0.27 * strike if wolf else 0.0)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		turn(rig, side + " upperarm", Vector3.RIGHT, (-0.19 if wolf else 0.36 + sign * 0.12) * strike)
		turn(rig, side + " forearm", Vector3.RIGHT, (0.68 if wolf else 0.20) * strike)
		turn(rig, side + " thigh", Vector3.RIGHT, (-0.27 if wolf else 0.09) * strike)
		turn(rig, side + " calf", Vector3.RIGHT, (0.12 if wolf else -0.21) * strike)
	translate_hip(rig, Vector3(0.0, 0.0, (0.17 if wolf else 0.095) * strike))
	return 0.09 * strike * strike if wolf else 0.0

func collapse(rig: Skeleton3D, wolf: bool, slot: int, phase: float) -> float:
	var fall := smoothstep(0.06, 0.83, phase)
	var stagger := smoothstep(0.02, 0.27, phase) * (1.0 - smoothstep(0.28, 0.66, phase))
	var roll := (0.12 if slot == 8 else -1.43) if wolf else (1.12 if slot == 8 else -1.29)
	var pitch := (0.16 if slot == 8 else 0.31) if wolf else (0.26 if slot == 8 else -0.25)
	turn(rig, "pelvis", Vector3.RIGHT, pitch * fall - (0.48 if slot == 12 and not wolf else 0.13) * stagger)
	turn(rig, "pelvis", Vector3.FORWARD, roll * fall)
	turn(rig, "spine1", Vector3.RIGHT, 0.16 * fall)
	turn(rig, "neck", Vector3.RIGHT, 0.38 * fall)
	turn(rig, "neck1", Vector3.RIGHT, 0.17 * fall)
	turn(rig, "tail", Vector3.UP, 0.42 * fall * signf(roll))
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		turn(rig, side + " upperarm", Vector3.RIGHT, (-0.78 + sign * 0.11) * fall)
		turn(rig, side + " forearm", Vector3.RIGHT, (0.58 + sign * 0.16) * fall)
		turn(rig, side + " thigh", Vector3.RIGHT, (0.64 - sign * 0.17) * fall)
		turn(rig, side + " calf", Vector3.RIGHT, (-0.88 + sign * 0.13) * fall)
		turn(rig, side + " horselink", Vector3.RIGHT, 0.25 * fall)
		var settle := smoothstep(0.45, 0.94, phase)
		var lateral := signf(roll) * (0.10 if wolf else 0.14)
		var fore := Vector3(lateral + sign * 0.03, -0.10, 0.29 if wolf and slot == 8 else 0.11)
		var hind := Vector3(lateral + sign * 0.04, -0.10 if wolf else -0.11, 0.06)
		settle_chain(rig, side + " upperarm", side + " forearm", side + " hand", fore, settle)
		settle_chain(rig, side + " thigh", side + " calf", side + " horselink", hind, settle)
		turn(rig, side + " horselink", Vector3.RIGHT, -0.42 * settle)
	translate_hip(rig, Vector3(roll * 0.06 * fall, 0.0, 0.06 * fall))
	return 0.0

func settle_chain(rig: Skeleton3D, proximal: String, middle: String, distal: String, target: Vector3, amount: float) -> void:
	if amount <= 0.0:
		return
	var upper := rig.find_bone("bip01 " + proximal)
	var joint := rig.find_bone("bip01 " + middle)
	var end := rig.find_bone("bip01 " + distal)
	var a := rig.get_bone_global_pose(upper).origin
	var b := rig.get_bone_global_pose(joint).origin
	var c := rig.get_bone_global_pose(end).origin
	var goal := c.lerp(a + rig.global_basis.inverse() * target, amount)
	var direction := (goal - a).normalized()
	var first := a.distance_to(b)
	var second := b.distance_to(c)
	var distance := clampf(a.distance_to(goal), absf(first - second) + 0.001, first + second - 0.001)
	var along := (first * first - second * second + distance * distance) / (2.0 * distance)
	var pole := (b - a).slide(direction).normalized()
	if pole.is_zero_approx():
		pole = Vector3.UP.slide(direction).normalized()
	Arms.aim(rig, upper, joint, a + direction * along + pole * sqrt(maxf(0.0, first * first - along * along)))
	rig.force_update_all_bone_transforms()
	Arms.aim(rig, joint, end, a + direction * distance)
	rig.force_update_all_bone_transforms()

func turn(rig: Skeleton3D, label: String, axis: Vector3, amount: float) -> void:
	var bone := rig.find_bone("bip01 " + label)
	assert(bone >= 0)
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion((rig.global_basis.inverse() * axis).normalized(), amount)) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()

func translate_hip(rig: Skeleton3D, offset: Vector3) -> void:
	var bone := rig.find_bone("bip01 pelvis")
	var pose := rig.get_bone_global_pose(bone)
	pose.origin += rig.global_basis.inverse() * offset
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()
