# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/goat-eagle/"
const HeadJoints := ["Bone", "Bone.001", "Bone.002", "Bone.003", "Bone.004"]

func run() -> void:
	var row := Registry.entry(5)
	var source := Registry.asset_path(row)
	assert(FileAccess.file_exists(source))
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		skins.append(Ground.skin_points(mesh, rig))
	var quiet := fit_grounded(player, rig, skins, 1.0, "Bone", HeadJoints, pose_watch.bind(false), .003)
	var glance := fit_grounded(player, rig, skins, .90, "Bone", HeadJoints, pose_watch.bind(true), .003)
	assert(library.add_animation("EagleQuietWatch", quiet) == OK)
	assert(library.add_animation("EagleGlance", glance) == OK)
	assert(library.add_animation("EagleWingBeat", fit_wingbeat(player, rig, skins, false)) == OK)
	assert(library.add_animation("AirEagleWingBeat", fit_wingbeat(player, rig, skins, true)) == OK)
	verify_base_clips(player, source)
	player.stop()
	rig.reset_bone_poses()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, Stage + "5-modern.scn", ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("EAGLE ENHANCED: two perched fits and grounded/airborne wingbeats on the retained licensed rig")
	quit()

func pose_watch(rig: Skeleton3D, phase: float, glance: bool) -> void:
	var breath := sin(TAU * phase)
	var scan := sin(PI * phase) * (.41 if glance else .045)
	turn_world(rig, "Bone.001", Vector3.RIGHT, .028 * breath + .11 * scan)
	turn_world(rig, "Bone.002", Vector3.UP, .27 * scan)
	turn_world(rig, "Bone.003", Vector3.UP, .73 * scan)
	turn_world(rig, "Bone.003", Vector3.RIGHT, .050 * breath - .09 * scan)
	turn_world(rig, "Bone.004", Vector3.RIGHT, -.037 * breath)

func fit_wingbeat(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], airborne: bool) -> Animation:
	player.play("Idle", 0.0)
	player.advance(0.0)
	var perch: Array[Transform3D] = []
	for bone in rig.get_bone_count():
		perch.append(rig.get_bone_pose(bone))
	var fly := player.get_animation("Fly")
	var clip := fly.duplicate(true) as Animation
	clip.length = .90
	clip.loop_mode = Animation.LOOP_NONE
	var tracks := PackedInt32Array()
	for track in clip.get_track_count():
		var label := clip.track_get_path(track).get_concatenated_subnames()
		tracks.append(rig.find_bone(label))
		assert(tracks[-1] >= 0)
		for key in range(clip.track_get_key_count(track) - 1, -1, -1):
			clip.track_remove_key(track, key)
	player.play("Fly", 0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := float(frame) / 80.0
		var wing_phase := fposmod(2.0 * phase, 1.0)
		player.seek(wing_phase * fly.length, true)
		var lift := smoothstep(.04, .29, phase) * (1.0 - smoothstep(.70, .98, phase))
		if not airborne:
			for bone in rig.get_bone_count():
				var in_flight := rig.get_bone_pose(bone)
				var blended := perch[bone].interpolate_with(in_flight, lift)
				rig.set_bone_pose_position(bone, blended.origin)
				rig.set_bone_pose_rotation(bone, blended.basis.get_rotation_quaternion())
				rig.set_bone_pose_scale(bone, blended.basis.get_scale())
		var dive := smoothstep(.43, .61, phase) * (1.0 - smoothstep(.68, .91, phase))
		turn_world(rig, "Bone", Vector3.RIGHT, .66 * dive - .12 * lift)
		turn_world(rig, "Bone.001", Vector3.RIGHT, .22 * dive)
		turn_world(rig, "Bone.004", Vector3.RIGHT, -.26 * dive)
		var low := INF
		for skin in skins:
			low = minf(low, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		var body := rig.get_bone_global_pose(0)
		var offset := -.14 * dive if airborne else 0.0
		body.origin += rig.global_basis.inverse() * Vector3.UP * maxf(offset, (.15 if airborne else .004) - low)
		rig.set_bone_global_pose(0, body)
		var time := phase * clip.length
		for track in tracks.size():
			var bone := tracks[track]
			match clip.track_get_type(track):
				Animation.TYPE_POSITION_3D: clip.position_track_insert_key(track, time, rig.get_bone_pose_position(bone))
				Animation.TYPE_ROTATION_3D: clip.rotation_track_insert_key(track, time, rig.get_bone_pose_rotation(bone))
				Animation.TYPE_SCALE_3D: clip.scale_track_insert_key(track, time, rig.get_bone_pose_scale(bone))
				_: assert(false, "Unexpected Eagle flight channel")
	return clip
