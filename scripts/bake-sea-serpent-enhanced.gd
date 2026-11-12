# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-sea-serpent-actions.gd"

const Fits := {
	0: ["SeaCombatSwim", 1.2], 1: ["SeaCombatIdle", 1.2], 2: ["SeaSideFall", 1.2],
	3: ["SeaRollFall", 1.4], 4: ["SeaSnap", .8], 5: ["SeaDiveStrike", .8],
	10: ["SeaRecoil", .6], 15: ["SeaGuard", .5], 25: ["SeaQuietIdle", 1.2],
	26: ["SeaQuietFidget", .9], 27: ["SeaDeepFidget", 1.2], 28: ["SeaAlert", .7],
}
const Loops := [0, 1, 25]
const Head := "bip01 head"
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")


func run() -> void:
	var folder := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--study="):
			folder = argument.trim_prefix("--study=")
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder):
		printerr("Provide an existing private output directory using --study.")
		quit(1)
		return
	for treatment: String in ["original", "rounded", "modern"]:
		var source := STEM + "-classic-" + treatment + ".scn"
		var actor := (load(source) as PackedScene).instantiate()
		root.add_child(actor)
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := actor.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for group: int in Fits:
			assert(library.add_animation(Fits[group][0], fit_motion(player, rig, group)) == OK)
		var receipt := verify_fit(player, rig, mesh, source)
		player.stop()
		rig.reset_bone_poses()
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		var scene := PackedScene.new()
		assert(scene.pack(actor) == OK)
		var output := folder.path_join("sea-serpent-enhanced-" + treatment + ".scn")
		assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
		var report := FileAccess.open(folder.path_join("bake-" + treatment + ".json"), FileAccess.WRITE)
		report.store_string(JSON.stringify({"source": FileAccess.get_sha256(source),
			"scene": FileAccess.get_sha256(output), "groups": receipt}, "  "))
		report.close()
		actor.free()
		print("SEA SERPENT FIT: ", treatment, " retains its source rig and Classic keys with 12 additional clips")
	quit()


func fit_motion(player: AnimationPlayer, rig: Skeleton3D, group: int) -> Animation:
	var motion := player.get_animation("Idle").duplicate(true) as Animation
	motion.length = Fits[group][1]
	motion.loop_mode = Animation.LOOP_LINEAR if group in Loops else Animation.LOOP_NONE
	for track in motion.get_track_count():
		for key in range(motion.track_get_key_count(track) - 1, 0, -1):
			motion.track_remove_key(track, key)
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var rotation_tracks := {}
	for name: String in FRONT + TAIL + [BODY_JOINT, Head, JAW]:
		var bone := rig.find_bone(name)
		assert(bone >= 0)
		rotation_tracks[bone] = ensure_track(motion, NodePath("%s:%s" % [rig_path, name]), Animation.TYPE_ROTATION_3D)
	var body := rig.find_bone(BODY_JOINT)
	var position := ensure_track(motion, NodePath("%s:%s" % [rig_path, BODY_JOINT]), Animation.TYPE_POSITION_3D)
	player.play("Idle", 0.)
	player.advance(0.)
	for frame in 73:
		var phase := float(frame) / 72.
		rig.reset_bone_poses()
		player.seek(0., true)
		rig.force_update_all_bone_transforms()
		pose_reference(rig, phase, group)
		var time := phase * motion.length
		motion.position_track_insert_key(position, time, rig.get_bone_pose_position(body))
		for bone: int in rotation_tracks:
			motion.rotation_track_insert_key(rotation_tracks[bone], time, rig.get_bone_pose_rotation(bone))
	return motion


func ensure_track(clip: Animation, path: NodePath, type: Animation.TrackType) -> int:
	var track := clip.find_track(path, type)
	if track < 0:
		track = clip.add_track(type)
		clip.track_set_path(track, path)
	return track


func pose_reference(rig: Skeleton3D, phase: float, group: int) -> void:
	var raise := 0.
	var dive := 0.
	var jaw := 0.
	var bend := 0.
	var sink := 0.
	var forward := 0.
	var wave := 0.
	match group:
		0:
			dive = .035 + .06 * sin(phase * TAU)
			wave = .29
		1:
			raise = .20 + .052 * sin(phase * TAU)
			wave = .07
		2, 3:
			pose_collapse(rig, phase, group == 3)
			return
		4:
			var strike := pulse(phase, .12, .43, .46, .78)
			raise = .24 * pulse(phase, .02, .20, .23, .42)
			dive = .29 * strike
			jaw = .47 * strike
			forward = .52 * strike
			wave = .14 * strike
		5:
			raise = .42 * pulse(phase, .03, .25, .27, .40)
			dive = .65 * pulse(phase, .25, .44, .61, .92)
			jaw = .39 * pulse(phase, .09, .24, .32, .50)
			sink = .44 * pulse(phase, .29, .47, .65, .92)
			wave = .19 * sin(PI * phase)
		10:
			raise = .61 * pulse(phase, .02, .27, .45, .94)
			jaw = .18 * raise
			forward = -.31 * raise
		15:
			bend = .37 * pulse(phase, .04, .25, .47, .94)
			raise = .13 * sin(PI * phase)
		25:
			dive = .02 + .018 * sin(phase * TAU)
			wave = .09
		26:
			dive = .02 - .09 * pulse(phase, .02, .33, .50, .98)
			bend = .15 * sin(phase * TAU)
			wave = .09
		27:
			raise = .30 * pulse(phase, .08, .42, .63, .98)
			wave = .25 * sin(PI * phase)
		28:
			dive = .06 * (1. - smoothstep(.10, .68, phase))
			raise = .22 * smoothstep(.20, .76, phase)
			wave = .12 * sin(PI * phase)
	for index in FRONT.size():
		rotate_joint(rig, FRONT[index], Vector3.RIGHT, .32 * NECK_PITCH[index] * (dive - raise))
		rotate_joint(rig, FRONT[index], Vector3.UP, bend * (.14 + .02 * index))
	for index in TAIL.size():
		rotate_joint(rig, TAIL[index], Vector3.UP, wave * sin(phase * TAU - .65 * index))
	rotate_joint(rig, JAW, Vector3.RIGHT, jaw)
	shift_body(rig, Vector3(0., -sink, forward))


func pose_collapse(rig: Skeleton3D, phase: float, rolled: bool) -> void:
	var heave := pulse(phase, .08, .36 if rolled else .26, .54, .74)
	var fall := smoothstep(.49 if rolled else .40, .90, phase)
	var side := -1. if rolled else 1.
	for index in FRONT.size():
		rotate_joint(rig, FRONT[index], Vector3.RIGHT, .32 * NECK_PITCH[index] * (.86 * fall - .80 * heave))
		rotate_joint(rig, FRONT[index], Vector3.UP, side * .10 * fall)
	for index in TAIL.size():
		rotate_joint(rig, TAIL[index], Vector3.RIGHT, (.19 + .06 * index) * heave - .17 * fall)
	rotate_joint(rig, BODY_JOINT, Vector3.BACK, side * (.80 if rolled else .48) * fall)
	rotate_joint(rig, JAW, Vector3.RIGHT, .36 * heave)
	shift_body(rig, Vector3(side * .25 * fall, -.78 * fall, 0.))


func pulse(phase: float, start: float, peak: float, hold: float, finish: float) -> float:
	return smoothstep(start, peak, phase) * (1. - smoothstep(hold, finish, phase))


func shift_body(rig: Skeleton3D, offset: Vector3) -> void:
	var bone := rig.find_bone(BODY_JOINT)
	var pose := rig.get_bone_global_pose(bone)
	pose.origin += rig.global_basis.inverse() * offset
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()


func verify_fit(player: AnimationPlayer, rig: Skeleton3D, mesh: MeshInstance3D, source: String) -> Dictionary:
	var original := (load(source) as PackedScene).instantiate()
	var prior := original.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for label: String in prior.get_animation_list():
		var before := prior.get_animation(label)
		var after := player.get_animation(label)
		assert(before.length == after.length and before.get_track_count() == after.get_track_count())
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track)
				and before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
	original.free()
	var head := rig.find_bone(Head)
	var skin := Ground.skin_points(mesh, rig)
	var result := {}
	for group: int in Fits:
		var clip: String = Fits[group][0]
		player.play(clip, 0.)
		player.advance(0.)
		var range_y := Vector2(INF, -INF)
		var origin := rig.global_position
		for frame in 37:
			player.seek(player.current_animation_length * float(frame) / 36., true)
			rig.force_update_all_bone_transforms()
			var bounds := Geometry.deformed_bounds(mesh, rig)
			assert(bounds.is_finite() and bounds.size.length() < 24.)
			assert(is_finite(Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)))
			assert(rig.global_position.is_equal_approx(origin), "the native water anchor is unchanged")
			var y := rig.to_global(rig.get_bone_global_pose(head).origin).y
			range_y.x = minf(range_y.x, y)
			range_y.y = maxf(range_y.y, y)
		result[group] = {"clip": clip, "head_min": range_y.x, "head_max": range_y.y, "samples": 37}
	return result
