extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Earlier := preload("res://../scripts/test-quadruped-actions.gd")
const CLIPS := {3: "Death2", 6: "DoubleWhip", 18: "CurlAndRise"}
const BRANCHES := [["box02", "box04", "box06"], ["box38", "box40", "box42"],
	["box13", "box09", "box11"], ["box14", "box16", "box18"], ["box20", "box22", "box24"],
	["box26", "box28", "box30"], ["box32", "box34", "box36"]]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var row := Registry.entry(66)
	var source_assets: Dictionary = row.get("classic_gesture_base_assets", {})
	var evidence := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source: String = source_assets.get(treatment, Registry.asset_path(row, treatment))
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var skin := Ground.skin_points(mesh, rig)
		for group: int in CLIPS:
			var clip: String = CLIPS[group]
			var animation := fit(group, player, rig, skin)
			assert(library.add_animation(clip, animation) == OK)
			assert(check_floor(clip, player, rig, skin))
		Earlier.check_earlier_keys(player, source)
		player.stop()
		var candidate := PackedScene.new()
		var target := "res://local-art/creatures/swamp-tentacle-actions-%s.scn" % treatment
		assert(candidate.pack(model) == OK)
		assert(ResourceSaver.save(candidate, target, ResourceSaver.FLAG_COMPRESS) == OK)
		evidence[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}
		model.free()
	var receipt := FileAccess.open("res://local-art/creatures/swamp-tentacle-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	var inputs := {}
	for path: String in ["res://../scripts/bake-swamp-tentacle-actions.gd", "res://../scripts/test-quadruped-actions.gd",
		"res://Presentation/SourceGroundLookup.gd"]:
		inputs[path.get_file()] = FileAccess.get_sha256(path)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": evidence}))
	receipt.close()
	print("SWAMP TENTACLE: three motions, 1089 complete skin poses, earlier keys retained")
	quit()

func fit(group: int, player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary) -> Animation:
	var seed := {3:"Death", 6:"Attack2", 18:"Fidget"}[group] as String
	var source := player.get_animation(seed)
	var clip := source.duplicate(true) as Animation
	clip.loop_mode = Animation.LOOP_NONE
	var source_loop := source.loop_mode
	source.loop_mode = Animation.LOOP_NONE
	var path := player.get_node(player.root_node).get_path_to(rig)
	var tracks := {}
	for branch: Array in BRANCHES:
		for label: String in branch:
			var joint := rig.find_bone(label)
			assert(joint >= 0)
			tracks[joint] = empty_track(clip, NodePath("%s:%s" % [path, label]), Animation.TYPE_ROTATION_3D)
	var base := rig.find_bone("box01")
	var location := empty_track(clip, NodePath("%s:box01" % path), Animation.TYPE_POSITION_3D)
	player.play(seed, 0.0)
	player.advance(0.0)
	for sample in 121:
		var phase := sample / 120.0
		rig.reset_bone_poses()
		player.seek(phase * source.length, true)
		rig.force_update_all_bone_transforms()
		pose(group, phase, rig)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var root_pose := rig.get_bone_global_pose(base)
		root_pose.origin += rig.global_basis.inverse() * Vector3.UP * (0.003 - gap)
		rig.set_bone_global_pose(base, root_pose)
		var time := phase * clip.length
		clip.position_track_insert_key(location, time, rig.get_bone_pose_position(base))
		for joint: int in tracks:
			clip.rotation_track_insert_key(tracks[joint], time, rig.get_bone_pose_rotation(joint))
	source.loop_mode = source_loop
	return clip

func pose(group: int, phase: float, rig: Skeleton3D) -> void:
	for index in BRANCHES.size():
		var branch: Array = BRANCHES[index]
		var bearing := TAU * index / BRANCHES.size()
		var radial := Vector3(cos(bearing), 0.0, sin(bearing))
		var side := Vector3.UP.cross(radial)
		var offset := 0.025 * index
		var wave := smoothstep(0.08 + offset, 0.46 + offset, phase) * (1.0 - smoothstep(0.57 + offset, 0.98, phase))
		match group:
			3:
				var close := smoothstep(0.15 + offset, 0.91, phase)
				turn(rig, branch[0], side, (0.36 if index % 2 == 0 else -0.30) * close)
				turn(rig, branch[1], side, 0.47 * close)
				turn(rig, branch[2], Vector3.UP, -0.42 * close)
			6:
				turn(rig, branch[0], Vector3.RIGHT, (0.38 if index in [0, 2, 3] else 0.14) * wave)
				turn(rig, branch[1], Vector3.RIGHT, 0.43 * wave)
				turn(rig, branch[2], Vector3.RIGHT, -0.80 * wave)
			18:
				var main := 0.54 if index in [0, 3] else 0.23
				turn(rig, branch[0], side, -main * wave)
				turn(rig, branch[1], side, 0.70 * wave)
				turn(rig, branch[2], side, 0.44 * wave)

func turn(rig: Skeleton3D, label: String, axis: Vector3, angle: float) -> void:
	var joint := rig.find_bone(label)
	var joint_pose := rig.get_bone_global_pose(joint)
	joint_pose.basis = Basis(Quaternion((rig.global_basis.inverse() * axis).normalized(), angle)) * joint_pose.basis
	rig.set_bone_global_pose(joint, joint_pose)
	rig.force_update_all_bone_transforms()

func empty_track(clip: Animation, path: NodePath, kind: Animation.TrackType) -> int:
	var track := clip.find_track(path, kind)
	if track < 0:
		track = clip.add_track(kind)
		clip.track_set_path(track, path)
	for key in range(clip.track_get_key_count(track) - 1, -1, -1):
		clip.track_remove_key(track, key)
	return track

func check_floor(clip: String, player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary) -> bool:
	player.play(clip, 0.0)
	player.advance(0.0)
	var lowest := INF
	var highest := -INF
	for sample in 121:
		player.seek(player.current_animation_length * sample / 120.0, true)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		lowest = minf(lowest, gap)
		highest = maxf(highest, gap)
	print(clip, ": ", lowest, "..", highest, " m gap")
	return lowest >= 0.0025 and highest <= 0.0035
