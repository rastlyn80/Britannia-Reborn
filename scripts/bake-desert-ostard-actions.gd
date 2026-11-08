extends SceneTree

const Ostard := preload("res://Presentation/OstardVisual.gd")
const Actions := preload("res://Presentation/DesertOstardActions.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const JOINTS := ["spine", "spine1", "neck", "neck1", "neck2", "head", "ponytail1", "tail", "tail1"]
const SAMPLES := 96
const RECEIPT := "res://local-art/ostards/desert-actions-bake.json"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var assets := {}
	for treatment: String in Actions.TREATMENTS:
		var actor := Ostard.new()
		actor.treatment = treatment
		root.add_child(actor)
		var rig: Skeleton3D = actor.skeleton
		var player: AnimationPlayer = actor.animator
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("")
		var preview := AnimationLibrary.new()
		for group: int in Actions.CLIPS:
			var clip: String = Actions.CLIPS[group]
			var motion := fit(group, player, rig, skin)
			if library.has_animation(clip):
				library.remove_animation(clip)
			assert(library.add_animation(clip, motion) == OK)
			assert(preview.add_animation(clip, motion) == OK)
			assert(verify_pose(clip, player, rig, skin))
		var path := Actions.asset_path(treatment)
		assert(ResourceSaver.save(preview, path) == OK)
		assets[treatment] = {"source": FileAccess.get_sha256(actor.model_resource_path("ostards", "desert")),
			"actions": FileAccess.get_sha256(path)}
		actor.free()
	var evidence := FileAccess.open(RECEIPT, FileAccess.WRITE)
	assert(evidence != null)
	evidence.store_string(JSON.stringify({"assets": assets,
		"recipe": FileAccess.get_sha256("res://../scripts/bake-desert-ostard-actions.gd")}, "\t"))
	evidence.close()
	print("DESERT OSTARD ACTION LIBRARIES: six distinct actions, 1746 sampled weighted skins")
	quit()

func fit(group: int, player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary) -> Animation:
	var seed := "Attack" if group == 6 else "Death" if group == 12 else "Idle"
	var source := player.get_animation(seed)
	var result := source.duplicate(true) as Animation
	result.loop_mode = Animation.LOOP_NONE
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var tracks := {}
	for name: String in JOINTS:
		var bone := rig.find_bone("bip01 " + name)
		assert(bone >= 0)
		var path := NodePath("%s:%s" % [rig_path, rig.get_bone_name(bone)])
		tracks[bone] = empty_track(result, path, Animation.TYPE_ROTATION_3D)
	var origin := rig.find_bone("bip01")
	var location := empty_track(result, NodePath("%s:bip01" % rig_path), Animation.TYPE_POSITION_3D)
	# Use the final source key before restoring any source loop.
	var source_loop := source.loop_mode
	source.loop_mode = Animation.LOOP_NONE
	player.play(seed, 0.)
	player.advance(0.)
	for sample in SAMPLES + 1:
		var phase := float(sample) / SAMPLES
		rig.reset_bone_poses()
		player.seek(source.length * phase, true)
		rig.force_update_all_bone_transforms()
		pose(group, phase, rig)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var root_pose := rig.get_bone_global_pose(origin)
		root_pose.origin += rig.global_basis.inverse() * Vector3.UP * (0.003 - gap)
		rig.set_bone_global_pose(origin, root_pose)
		var time := phase * result.length
		result.position_track_insert_key(location, time, rig.get_bone_pose_position(origin))
		for bone: int in tracks:
			result.rotation_track_insert_key(tracks[bone], time, rig.get_bone_pose_rotation(bone))
	source.loop_mode = source_loop
	return result

func empty_track(clip: Animation, path: NodePath, kind: Animation.TrackType) -> int:
	var track := clip.find_track(path, kind)
	if track < 0:
		track = clip.add_track(kind)
		clip.track_set_path(track, path)
	for key in range(clip.track_get_key_count(track) - 1, -1, -1):
		clip.track_remove_key(track, key)
	return track

func pose(group: int, phase: float, rig: Skeleton3D) -> void:
	var dip := pulse(phase, 0.08, 0.38, 0.57, 0.98)
	var twitch := pulse(phase, 0.13, 0.27, 0.32, 0.57) - 0.55 * pulse(phase, 0.36, 0.53, 0.61, 0.87)
	match group:
		4:
			turn(rig, "spine1", Vector3.RIGHT, -0.12 * dip)
			turn(rig, "neck", Vector3.RIGHT, -0.17 * dip)
			turn(rig, "head", Vector3.RIGHT, 0.16 * dip)
			turn(rig, "tail", Vector3.RIGHT, -0.12 * dip)
		6:
			var peck := pulse(phase, 0.18, 0.45, 0.53, 0.88)
			turn(rig, "spine1", Vector3.RIGHT, 0.24 * peck)
			turn(rig, "neck", Vector3.RIGHT, 0.64 * peck)
			turn(rig, "neck1", Vector3.RIGHT, 0.47 * peck)
			turn(rig, "head", Vector3.RIGHT, 0.32 * peck)
			turn(rig, "tail", Vector3.RIGHT, -0.32 * peck)
		9:
			turn(rig, "neck", Vector3.RIGHT, 0.37 * dip)
			turn(rig, "neck1", Vector3.RIGHT, 0.20 * dip)
			turn(rig, "head", Vector3.RIGHT, 0.38 * dip)
			turn(rig, "tail1", Vector3.UP, -0.17 * dip)
		10:
			turn(rig, "neck2", Vector3.UP, 0.16 * twitch)
			turn(rig, "head", Vector3.UP, -0.41 * twitch)
			turn(rig, "head", Vector3.FORWARD, 0.21 * twitch)
			turn(rig, "ponytail1", Vector3.FORWARD, -0.12 * twitch)
		11:
			var settle := pulse(phase, 0.04, 0.42, 0.68, 0.99)
			turn(rig, "spine", Vector3.RIGHT, 0.16 * settle)
			turn(rig, "neck", Vector3.RIGHT, 0.28 * settle)
			turn(rig, "head", Vector3.RIGHT, -0.24 * settle)
			turn(rig, "tail", Vector3.RIGHT, 0.23 * settle)
		12:
			var collapse := smoothstep(0.28, 0.88, phase)
			turn(rig, "spine", Vector3.RIGHT, 0.34 * collapse)
			turn(rig, "neck", Vector3.RIGHT, 0.37 * collapse)
			turn(rig, "head", Vector3.FORWARD, 0.20 * collapse)
			turn(rig, "tail", Vector3.RIGHT, 0.44 * collapse)
			turn(rig, "tail1", Vector3.RIGHT, -0.20 * collapse)

func turn(rig: Skeleton3D, name: String, axis: Vector3, angle: float) -> void:
	var bone := rig.find_bone("bip01 " + name)
	var global_pose := rig.get_bone_global_pose(bone)
	var twist := Quaternion((rig.global_basis.inverse() * axis).normalized(), angle)
	global_pose.basis = Basis(twist) * global_pose.basis
	rig.set_bone_global_pose(bone, global_pose)
	rig.force_update_all_bone_transforms()

func pulse(phase: float, start: float, peak: float, release: float, end: float) -> float:
	return smoothstep(start, peak, phase) * (1.0 - smoothstep(release, end, phase))

func verify_pose(clip: String, player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary) -> bool:
	player.play(clip, 0.0)
	player.advance(0.0)
	var low := INF
	var high := -INF
	var low_sample := -1
	for sample in SAMPLES + 1:
		var time := player.current_animation_length * sample / SAMPLES
		rig.reset_bone_poses()
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		if gap < low:
			low_sample = sample
		low = minf(low, gap)
		high = maxf(high, gap)
	print(clip, ": ", low, "..", high, " m ground gap, low at sample ", low_sample)
	return is_finite(low) and low >= 0.0025 and high <= 0.0035
