extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const LEGS := [
	["bone20", "bone21"], ["bone16", "bone17"], ["bone24", "bone25"], ["bone12", "bone13"],
	["bone28", "bone29"], ["bone08", "bone09"], ["bone32", "bone33"], ["bone04", "bone05"],
]
const ACTIONS := {3: ["Death2", 0.78], 5: ["FrontClasp", 0.64], 6: ["ForwardStab", 0.64],
	15: ["LegFlick", 0.48], 16: ["SpiderBrace", 0.48], 18: ["AbdomenRock", 0.8]}

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var row := Registry.entry(28)
	assert(row.classic_action_categories["11"] == "AbdomenShift")
	var scenes := {}
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var output := "res://local-art/creatures/giant-spider-actions-%s.scn" % treatment
		bake(source, output)
		scenes[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
	var receipt := FileAccess.open("res://local-art/creatures/giant-spider-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	var inputs := {get_script().resource_path.get_file(): FileAccess.get_sha256(get_script().resource_path),
		"SourceGroundLookup.gd": FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd")}
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": scenes}))
	receipt.close()
	quit()

func bake(source: String, output: String) -> void:
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var surface := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(surface, rig)
	var library := player.get_animation_library("")
	player.deterministic = true
	for slot: int in ACTIONS:
		var item: Array = ACTIONS[slot]
		var clip := fit_death(player, rig, skin) if slot == 3 else fit(player, rig, skin, slot, item[1])
		assert(library.add_animation(item[0], clip) == OK)
	player.stop()
	var result := PackedScene.new()
	assert(result.pack(model) == OK and ResourceSaver.save(result, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()

func fit(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, slot: int, duration: float) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = duration
	clip.loop_mode = Animation.LOOP_NONE
	var joint_root := rig.find_bone("bone01")
	var path := player.get_node(player.root_node).get_path_to(rig)
	var placement_path := NodePath(str(path) + ":bone01")
	var placement := clip.find_track(placement_path, Animation.TYPE_POSITION_3D)
	var rotations := {}
	for track in clip.get_track_count():
		var joint := rig.find_bone(str(clip.track_get_path(track).get_concatenated_subnames()))
		for key in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, key)
		if joint >= joint_root and clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			rotations[joint] = track
	for joint in range(joint_root, rig.get_bone_count()):
		if not rotations.has(joint):
			var track := clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track, NodePath(str(path) + ":" + rig.get_bone_name(joint)))
			rotations[joint] = track
	if placement < 0:
		placement = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(placement, placement_path)
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 97:
		var phase := float(frame) / 96.0
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		pose(rig, slot, phase)
		var hip := rig.get_bone_global_pose(joint_root)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		hip.origin += rig.global_basis.inverse() * Vector3.UP * (0.004 - gap)
		rig.set_bone_global_pose(joint_root, hip)
		var time := phase * duration
		clip.position_track_insert_key(placement, time, rig.get_bone_pose_position(joint_root))
		for joint: int in rotations:
			clip.rotation_track_insert_key(rotations[joint], time, rig.get_bone_pose_rotation(joint))
	return clip

func turn(rig: Skeleton3D, label: String, axis: Vector3, radians: float) -> void:
	var bone := rig.find_bone(label)
	assert(bone >= 0)
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion((rig.global_basis.inverse() * axis).normalized(), radians)) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()

func fit_death(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary) -> Animation:
	var clip := player.get_animation("Death").duplicate(true) as Animation
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var labels := ["bone02", "bone20", "bone21", "bone16", "bone17", "bone24", "bone25"]
	var tracks := {}
	for label: String in labels:
		var path := NodePath(str(rig_path) + ":" + label)
		var track := clip.find_track(path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track, path)
		for key in range(clip.track_get_key_count(track) - 1, -1, -1):
			clip.track_remove_key(track, key)
		tracks[label] = track
	var trunk := rig.find_bone("bone01")
	var path := NodePath(str(rig_path) + ":bone01")
	var placement := clip.find_track(path, Animation.TYPE_POSITION_3D)
	if placement < 0:
		placement = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(placement, path)
	for key in range(clip.track_get_key_count(placement) - 1, -1, -1):
		clip.track_remove_key(placement, key)
	player.play("Death", 0.0)
	player.advance(0.0)
	rig.force_update_all_bone_transforms()
	var origin := rig.to_global(rig.get_bone_global_pose(trunk).origin)
	for frame in 161:
		var phase := float(frame) / 160.0
		var time := phase * clip.length
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		var flick := smoothstep(0.02, 0.28, phase) * (1.0 - smoothstep(0.42, 0.85, phase))
		var fold := smoothstep(0.33, 0.97, phase)
		turn(rig, "bone02", Vector3.FORWARD, 0.21 * fold)
		turn(rig, "bone20", Vector3.RIGHT, -0.77 * flick)
		turn(rig, "bone21", Vector3.UP, -0.25 * fold)
		turn(rig, "bone16", Vector3.RIGHT, -0.33 * flick)
		turn(rig, "bone17", Vector3.UP, 0.30 * fold)
		turn(rig, "bone24", Vector3.RIGHT, 0.22 * fold)
		turn(rig, "bone25", Vector3.FORWARD, 0.24 * fold)
		var pose := rig.get_bone_global_pose(trunk)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var drift := rig.to_global(pose.origin) - origin
		var correction := Vector3(-0.72 * drift.x, 0.004 - gap, -0.72 * drift.z)
		pose.origin += rig.global_basis.inverse() * correction
		rig.set_bone_global_pose(trunk, pose)
		clip.position_track_insert_key(placement, time, rig.get_bone_pose_position(trunk))
		for label: String in labels:
			clip.rotation_track_insert_key(tracks[label], time, rig.get_bone_pose_rotation(rig.find_bone(label)))
	return clip

func pose(rig: Skeleton3D, slot: int, phase: float) -> void:
	var peak := smoothstep(0.02, 0.40, phase) * (1.0 - smoothstep(0.57, 1.0, phase))
	if slot in [5, 6]:
		turn(rig, "bone01", Vector3.RIGHT, (-0.14 if slot == 5 else 0.26) * peak)
		turn(rig, "bone02", Vector3.RIGHT, 0.30 * peak)
		for leg in [0, 1, 2, 3]:
			var side := 1.0 if leg % 2 == 0 else -1.0
			var pair: Array = LEGS[leg]
			var strength := peak if slot == 5 or leg == 1 else 0.24 * peak
			turn(rig, pair[0], Vector3.RIGHT, -0.79 * strength)
			turn(rig, pair[0], Vector3.UP, -side * 0.61 * strength)
			turn(rig, pair[1], Vector3.RIGHT, (-0.24 if slot == 6 else 0.36) * strength)
		return
	if slot in [15, 16]:
		turn(rig, "bone01", Vector3.RIGHT, (-0.19 if slot == 15 else 0.28) * peak)
		turn(rig, "bone02", Vector3.RIGHT, (0.24 if slot == 15 else -0.37) * peak)
		for leg in [0, 1, 2, 3]:
			var side := 1.0 if leg % 2 == 0 else -1.0
			var pair: Array = LEGS[leg]
			turn(rig, pair[0], Vector3.FORWARD, side * (0.52 if slot == 15 else -0.15) * peak)
			turn(rig, pair[1], Vector3.RIGHT, (0.14 if slot == 15 else -0.60) * peak)
		return
	turn(rig, "bone02", Vector3.RIGHT, -0.28 * peak)
	turn(rig, "bone02", Vector3.UP, 0.23 * peak)
	turn(rig, "bone20", Vector3.RIGHT, -0.16 * peak)
