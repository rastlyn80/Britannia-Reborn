extends "res://../scripts/bake-bone-knight-cyclops.gd"

const Earlier := preload("res://../scripts/test-quadruped-actions.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const NEXT := {3:"Death2", 4:"MalletSideSweep", 6:"MalletLunge", 15:"MalletHighBrace",
	16:"MalletRearBrace", 18:"MalletCheck"}
const SEED := {3:"Death", 4:"Idle", 6:"Attack", 15:"Idle", 16:"Idle", 18:"Fidget"}
const LENGTH := {3:1.14, 4:0.84, 6:0.84, 15:0.56, 16:0.56, 18:0.90}
const POSES := 96

func run() -> void:
	var row := preload("res://Presentation/CreatureRegistry.gd").entry(75)
	assert(row.kind == "cyclops_cyclops" and row.classic_action_categories["11"] == "MalletDip")
	var variants := ["modern"] if "--modern" in OS.get_cmdline_user_args() else ["original", "rounded", "modern"]
	var evidence := {}
	for treatment: String in variants:
		var source: String = row.assets[treatment]
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var body := model.find_child("Body", true, false) as MeshInstance3D
		var mallet := model.find_child("CyclopsMallet", true, false) as MeshInstance3D
		var body_skin := Ground.skin_points(body, rig)
		var prop_skin := Ground.skin_points(mallet, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var points := PackedVector3Array()
		for surface in mallet.mesh.get_surface_count():
			points.append_array(mallet.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
		var props: Array[Dictionary] = [{"label":"CyclopsMallet", "bone":rig.find_bone("cyclopsmallet"),
			"grip":rig.find_bone("cp_grasp_rhand"), "points":points}]
		var clearance := BladeClearance.new(body, rig)
		for group: int in NEXT:
			var clip: String = NEXT[group]
			assert(library.add_animation(clip, fit_body(group, player, rig, body_skin)) == OK)
			fit_clip(player, rig, clip, props, clearance)
			if group in [3, 6]:
				clear_mallet_floor(player, rig, clip, body_skin, prop_skin)
			var metrics := measure(player, rig, clip, body_skin, prop_skin, props[0], clearance)
			print(treatment, " ", clip, " body floor / mallet floor / grip / intersections ", metrics)
			assert(metrics[0] >= 0.0015 and metrics[1] >= 0.0015 and metrics[2] < 0.000001 and metrics[3] == 0)
		Earlier.check_earlier_keys(player, source)
		player.stop()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		var output := "res://local-art/creatures/cyclops-actions-%s.scn" % treatment
		assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
		evidence[treatment] = {"source":FileAccess.get_sha256(source), "scene":FileAccess.get_sha256(output)}
		model.free()
	if variants.size() == 3:
		var recipe := "res://../scripts/bake-cyclops-actions.gd"
		var inputs := {}
		for path: String in [recipe, "res://../scripts/bake-bone-knight-cyclops.gd",
			"res://../scripts/bone-knight-cyclops-clearance.gd", "res://../scripts/test-quadruped-actions.gd",
			"res://Presentation/SourceGroundLookup.gd"]:
			inputs[path.get_file()] = FileAccess.get_sha256(path)
		var proof := FileAccess.open("res://local-art/creatures/cyclops-actions-bake.json", FileAccess.WRITE)
		proof.store_string(JSON.stringify({"scenes":evidence, "inputs":inputs}, "\t") + "\n")
	print("CYCLOPS ACTIONS: ", variants.size(), " treatments, six fitted motions on the recovered armed rig")
	quit()

func fit_body(group: int, player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary) -> Animation:
	var seed: String = SEED[group]
	var source := player.get_animation(seed)
	var clip := source.duplicate(true) as Animation
	clip.length = float(LENGTH[group])
	clip.loop_mode = Animation.LOOP_NONE
	var origin := rig.find_bone("bip01")
	var path := player.get_node(player.root_node).get_path_to(rig)
	var positions := {}
	var rotations := {}
	var scales := {}
	var animated_nodes := {}
	for track in range(clip.get_track_count() - 1, -1, -1):
		var label := str(clip.track_get_path(track).get_concatenated_subnames())
		if label == "cyclopsmallet":
			clip.remove_track(track)
	for track in clip.get_track_count():
		var label := str(clip.track_get_path(track).get_concatenated_subnames())
		var joint := rig.find_bone(label)
		if joint < 0:
			var node_path := clip.track_get_path(track)
			var kind := clip.track_get_type(track)
			if kind in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				animated_nodes[track] = {"source":source.find_track(node_path, kind), "type":kind,
					"node":player.get_node(player.root_node).get_node(NodePath(node_path.get_concatenated_names()))}
			continue
		match clip.track_get_type(track):
			Animation.TYPE_POSITION_3D: positions[joint] = track
			Animation.TYPE_ROTATION_3D: rotations[joint] = track
			Animation.TYPE_SCALE_3D: scales[joint] = track
	for name: String in BONES + ["bip01 spine2"]:
		var joint := rig.find_bone(name)
		if not rotations.has(joint):
			rotations[joint] = channel(clip, NodePath("%s:%s" % [path, name]), Animation.TYPE_ROTATION_3D)
	if not positions.has(origin):
		positions[origin] = channel(clip, NodePath("%s:bip01" % path), Animation.TYPE_POSITION_3D)
	for track: int in positions.values() + rotations.values() + scales.values() + animated_nodes.keys():
		for key in range(clip.track_get_key_count(track) - 1, -1, -1):
			clip.track_remove_key(track, key)
	var loop := source.loop_mode
	source.loop_mode = Animation.LOOP_NONE
	player.play(seed, 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	var start: Array[Transform3D] = []
	for bone in rig.get_bone_count():
		start.append(rig.get_bone_pose(bone))
	for frame in POSES + 1:
		var u := float(frame) / POSES
		var phase := lerpf(0.57, 1.0, u) if group == 3 else u
		var source_time := source.length * phase
		var time := u * clip.length
		var weight := smoothstep(0.0, 0.46, u) if group == 3 else 1.0
		rig.reset_bone_poses()
		player.seek(source_time, true)
		for track: int in animated_nodes:
			var row: Dictionary = animated_nodes[track]
			var node: Node3D = row.node
			var index: int = row.source
			match row.type:
				Animation.TYPE_POSITION_3D:
					node.position = source.position_track_interpolate(index, 0.0).lerp(source.position_track_interpolate(index, source_time), weight)
					clip.position_track_insert_key(track, time, node.position)
				Animation.TYPE_ROTATION_3D:
					node.quaternion = source.rotation_track_interpolate(index, 0.0).slerp(source.rotation_track_interpolate(index, source_time), weight)
					clip.rotation_track_insert_key(track, time, node.quaternion)
				Animation.TYPE_SCALE_3D:
					node.scale = source.scale_track_interpolate(index, 0.0).lerp(source.scale_track_interpolate(index, source_time), weight)
					clip.scale_track_insert_key(track, time, node.scale)
		rig.force_update_all_bone_transforms()
		if group == 3:
			for bone in rig.get_bone_count():
				rig.set_bone_pose(bone, start[bone].interpolate_with(rig.get_bone_pose(bone), weight))
		pose(group, u, rig)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var root_pose := rig.get_bone_global_pose(origin)
		root_pose.origin += rig.global_basis.inverse() * Vector3.UP * (0.004 - gap)
		rig.set_bone_global_pose(origin, root_pose)
		for joint: int in positions:
			clip.position_track_insert_key(positions[joint], time, rig.get_bone_pose_position(joint))
		for joint: int in rotations:
			clip.rotation_track_insert_key(rotations[joint], time, rig.get_bone_pose_rotation(joint))
		for joint: int in scales:
			clip.scale_track_insert_key(scales[joint], time, rig.get_bone_pose_scale(joint))
	source.loop_mode = loop
	return clip

func pose(group: int, u: float, rig: Skeleton3D) -> void:
	var wind := smoothstep(0.01, 0.26, u) * (1.0 - smoothstep(0.31, 0.62, u))
	var drive := smoothstep(0.26, 0.57, u) * (1.0 - smoothstep(0.67, 0.98, u))
	match group:
		3:
			var guard := smoothstep(0.30, 0.52, u) * (1.0 - smoothstep(0.76, 0.91, u))
			turn(rig, "bip01 r upperarm", Vector3.RIGHT, -0.27 * wind)
			turn(rig, "bip01 r forearm", Vector3.RIGHT, -0.31 * wind)
			turn(rig, "bip01 r upperarm", Vector3.FORWARD, 0.16 * guard)
			turn(rig, "bip01 r forearm", Vector3.FORWARD, 0.12 * guard)
		4:
			turn(rig, "bip01 spine2", Vector3.UP, -0.43 * wind + 0.65 * drive)
			turn(rig, "bip01 r upperarm", Vector3.RIGHT, -1.08 * drive)
			turn(rig, "bip01 r forearm", Vector3.UP, -0.28 * wind + 0.55 * drive)
			turn(rig, "bip01 l upperarm", Vector3.RIGHT, -0.44 * wind)
		6:
			var recover := smoothstep(0.66, 0.75, u) * (1.0 - smoothstep(0.84, 0.97, u))
			turn(rig, "bip01 spine1", Vector3.RIGHT, 0.26 * drive)
			turn(rig, "bip01 r upperarm", Vector3.RIGHT, 0.35 * drive - 0.45 * recover)
			turn(rig, "bip01 r upperarm", Vector3.FORWARD, 0.22 * recover)
			turn(rig, "bip01 head", Vector3.RIGHT, -0.18 * drive)
		15, 16:
			var over := group == 15
			turn(rig, "bip01 spine1", Vector3.RIGHT, (0.21 if over else -0.23) * drive)
			turn(rig, "bip01 spine2", Vector3.UP, (-0.29 if over else 0.46) * drive)
			turn(rig, "bip01 r upperarm", Vector3.RIGHT, (-1.79 if over else -1.24) * drive)
			turn(rig, "bip01 r forearm", Vector3.RIGHT, -0.55 * drive)
			turn(rig, "bip01 l upperarm", Vector3.RIGHT, (-0.56 if over else -1.13) * drive)
		18:
			turn(rig, "bip01 head", Vector3.UP, 0.42 * drive)
			turn(rig, "bip01 spine2", Vector3.RIGHT, 0.20 * wind)
			turn(rig, "bip01 l forearm", Vector3.RIGHT, -0.49 * drive)

func turn(rig: Skeleton3D, name: String, axis: Vector3, angle: float) -> void:
	rotate_joint(rig, rig.find_bone(name), Quaternion((rig.global_basis.inverse() * axis).normalized(), angle))

func orientation(label: String, clip: String, phase: float) -> Basis:
	var shaft := Vector3(-0.55, 0.52, 0.72).normalized()
	var peak := smoothstep(0.06, 0.45, phase) * (1.0 - smoothstep(0.62, 0.98, phase))
	match clip:
		"Death2":
			shaft = shaft.slerp(Vector3(-0.82, 0.28, 0.48).normalized(), smoothstep(0.10, 0.67, phase))
			var guard := smoothstep(0.36, 0.55, phase) * (1.0 - smoothstep(0.76, 0.91, phase))
			shaft = shaft.slerp(Vector3(-0.85, 0.48, -0.10).normalized(), guard)
		"MalletSideSweep": shaft = shaft.slerp(Vector3(-0.66, 0.10, 0.74).normalized(), peak)
		"MalletLunge":
			shaft = shaft.slerp(Vector3(-0.34, -0.16, 0.93).normalized(), peak)
			var recover := smoothstep(0.66, 0.75, phase) * (1.0 - smoothstep(0.84, 0.97, phase))
			shaft = shaft.slerp(Vector3(-0.65, 0.38, 0.67).normalized(), recover)
		"MalletHighBrace": shaft = shaft.slerp(Vector3(-0.28, 0.91, 0.28).normalized(), peak)
		"MalletRearBrace": shaft = shaft.slerp(Vector3(-0.53, 0.63, -0.57).normalized(), peak)
		"MalletCheck": shaft = shaft.slerp(Vector3(-0.63, 0.21, 0.75).normalized(), peak)
		_: return super.orientation(label, clip, phase)
	return Basis(Quaternion(Vector3.UP, shaft))

func clear_mallet_floor(player: AnimationPlayer, rig: Skeleton3D, clip: String, skin: Dictionary, prop_skin: Dictionary) -> void:
	var motion := player.get_animation(clip)
	var base := rig.find_bone("bip01")
	var path := player.get_node(player.root_node).get_path_to(rig)
	var track := motion.find_track(NodePath("%s:bip01" % path), Animation.TYPE_POSITION_3D)
	assert(track >= 0)
	var offsets := PackedVector3Array()
	player.play(clip, 0.0)
	player.advance(0.0)
	for frame in 721:
		player.seek(motion.length * frame / 720.0, true)
		rig.force_update_all_bone_transforms()
		var body_floor := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var mallet_floor := Ground.minimum_plane_gap(prop_skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var pose := rig.get_bone_global_pose(base)
		pose.origin += rig.global_basis.inverse() * Vector3.UP * maxf(0.0, 0.006 - minf(body_floor, mallet_floor))
		rig.set_bone_global_pose(base, pose)
		offsets.append(rig.get_bone_pose_position(base))
	for key in range(motion.track_get_key_count(track) - 1, -1, -1):
		motion.track_remove_key(track, key)
	for frame in offsets.size():
		motion.position_track_insert_key(track, motion.length * frame / 720.0, offsets[frame])

func measure(player: AnimationPlayer, rig: Skeleton3D, clip: String, skin: Dictionary, prop_skin: Dictionary,
		prop: Dictionary, clearance: RefCounted) -> Array:
	var body_floor := INF
	var prop_floor := INF
	var grip := 0.0
	var crossed := 0
	player.play(clip, 0.0)
	player.advance(0.0)
	for frame in 361:
		player.seek(player.current_animation_length * frame / 360.0, true)
		rig.force_update_all_bone_transforms()
		body_floor = minf(body_floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		prop_floor = minf(prop_floor, Ground.minimum_plane_gap(prop_skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		grip = maxf(grip, rig.get_bone_global_pose(prop.bone).origin.distance_to(rig.get_bone_global_pose(prop.grip).origin))
		clearance.update_pose()
		if clearance.crosses_prop(rig.global_transform * rig.get_bone_global_pose(prop.bone), prop.label):
			crossed += 1
			print(clip, " mallet contact at phase ", frame / 360.0)
	return [body_floor, prop_floor, grip, crossed]
