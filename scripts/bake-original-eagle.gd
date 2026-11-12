# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Gaits := preload("res://Presentation/SourceCreatureGaitLoop.gd")
const RootJoint := "__root"
const Pelvis := "bip01 pelvis"
const SourceClips := ["Idle", "Walk", "Run", "Attack", "Hit", "Fidget", "Eat", "Death"]
const Lengths := {"Fly": 1.0, "TakeOff": .75, "Land": .85, "AirAttack": 1.0, "AirHit": .49,
	"AirDeath": 2.98, "EagleQuietWatch": 1.0, "EagleGlance": .9,
	"EagleWingBeat": .94, "AirEagleWingBeat": .94}

var player: AnimationPlayer
var rig: Skeleton3D
var space: Node3D
var skin: Dictionary
var perch: Array[Transform3D]
var perch_space: Vector3
var tracks := PackedInt32Array()


func _initialize() -> void:
	create_timer(180.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	var folder := preview_folder()
	for treatment: String in ["original", "rounded", "modern"]:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		assert(doc.append_from_file(folder.path_join("birds_eagle-%s.gltf" % treatment), state) == OK)
		var model := doc.generate_scene(state)
		root.add_child(model)
		rig = model.find_children("*", "Skeleton3D", true, false)[0]
		space = model.find_child("SourceSpace", true, false) as Node3D
		assert(space != null)
		player = model.find_children("*", "AnimationPlayer", true, false)[0]
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		skin = Ground.skin_points(mesh, rig)
		sample_source("Idle", 0.0)
		perch = read_pose()
		perch_space = space.position
		var library := player.get_animation_library("")
		var original := {}
		for clip: String in SourceClips:
			original[clip] = library.get_animation(clip).duplicate(true)
		for clip: String in Lengths:
			assert(library.add_animation(clip, make_clip(clip, Lengths[clip])) == OK)
		for clip: String in SourceClips:
			verify_keys(library.get_animation(clip), original[clip])
		player.stop()
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK)
		assert(ResourceSaver.save(packed, folder.path_join("5-%s.scn" % treatment), ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
	print("ORIGINAL EAGLE BAKE: 8 preserved source clips and 10 derived motions across 3 mesh treatments")
	quit()


func make_clip(label: String, length: float) -> Animation:
	var clip := player.get_animation("Run").duplicate(true) as Animation
	clip.length = length
	clip.loop_mode = Animation.LOOP_LINEAR if label == "Fly" else Animation.LOOP_NONE
	tracks.clear()
	var has_root_position := false
	for track in clip.get_track_count():
		var path := clip.track_get_path(track)
		var joint := rig.find_bone(path.get_concatenated_subnames()) if path.get_subname_count() else -1
		assert(joint >= 0 or (path.get_name(path.get_name_count() - 1) == space.name
			and clip.track_get_type(track) == Animation.TYPE_POSITION_3D), str(path))
		has_root_position = has_root_position or (joint == rig.find_bone(RootJoint)
			and clip.track_get_type(track) == Animation.TYPE_POSITION_3D)
		tracks.append(joint)
		for key in range(clip.track_get_key_count(track) - 1, -1, -1):
			clip.track_remove_key(track, key)
	if not has_root_position:
		var animation_root := player.get_node(player.root_node)
		var root_track := clip.add_track(Animation.TYPE_POSITION_3D)
		var path := NodePath(str(animation_root.get_path_to(rig)) + ":" + RootJoint)
		clip.track_set_path(root_track, path)
		tracks.append(rig.find_bone(RootJoint))
	var frames := ceili(length * 100)
	for index in frames + 1:
		var phase := index / float(frames)
		pose(label, phase)
		for track in clip.get_track_count():
			var joint := tracks[track]
			var time := length * phase
			if joint < 0:
				clip.position_track_insert_key(track, time, space.position)
				continue
			match clip.track_get_type(track):
				Animation.TYPE_POSITION_3D: clip.position_track_insert_key(track, time, rig.get_bone_pose_position(joint))
				Animation.TYPE_ROTATION_3D: clip.rotation_track_insert_key(track, time, rig.get_bone_pose_rotation(joint))
				Animation.TYPE_SCALE_3D: clip.scale_track_insert_key(track, time, rig.get_bone_pose_scale(joint))
				_: assert(false, "Unexpected source Eagle channel")
	if label == "Fly":
		for track in clip.get_track_count():
			Gaits.close_track(clip, track, .12)
	return clip


func pose(label: String, phase: float) -> void:
	match label:
		"Fly":
			sample_source("Run", phase)
			normalise_flight_height(phase, .54)
		"TakeOff", "Land":
			var takeoff := label == "TakeOff"
			var weight := smoothstep(.08, .92, phase if takeoff else 1.0 - phase)
			var flight_phase := (phase - 1.0) * .48 if takeoff else phase * .48
			sample_source("Fly", fposmod(flight_phase, 1.0))
			blend_perch(weight)
			raise_root(0.0, lerpf(.003, .11, weight))
		"AirAttack", "AirHit", "AirDeath":
			sample_source(label.trim_prefix("Air"), phase)
			if label == "AirDeath":
				var altitude := .46 * (1.0 - smoothstep(.0, .69, phase))
				raise_root(altitude, .003)
			else:
				raise_root(.43 - joint_height(Pelvis), .14)
		"EagleQuietWatch", "EagleGlance":
			sample_source("Idle", phase * .32)
			var glance := sin(PI * phase)
			if label == "EagleGlance":
				turn("bip01 neck1", Vector3.UP, .19 * glance)
				turn("bip01 head", Vector3.UP, .47 * glance)
			raise_root(0.0, .003)
		"EagleWingBeat", "AirEagleWingBeat":
			var air := label == "AirEagleWingBeat"
			var lift := 1.0 if air else smoothstep(.04, .26, phase) * (1.0 - smoothstep(.73, .98, phase))
			var dive := smoothstep(.42, .62, phase) * (1.0 - smoothstep(.67, .90, phase))
			flight(phase * 2.0, .51 - .13 * dive)
			blend_perch(lift)
			turn(Pelvis, Vector3.RIGHT, .34 * dive * lift)
			raise_root(0.0, .23 if air else lerpf(.003, .14, lift))


func flight(phase: float, height: float) -> void:
	sample_source("Fly", fposmod(phase, 1.0))
	normalise_flight_height(phase, height)


func normalise_flight_height(phase: float, height: float) -> void:
	var target := height + .035 * sin(TAU * phase)
	raise_root(target - joint_height(Pelvis), .17)


func sample_source(label: String, phase: float) -> void:
	var root_joint := rig.find_bone(RootJoint)
	rig.set_bone_pose_position(root_joint, rig.get_bone_rest(root_joint).origin)
	if player.assigned_animation != label:
		player.play(label, 0.0)
		player.advance(0.0)
	player.seek(player.current_animation_length * phase, true)
	rig.force_update_all_bone_transforms()


func read_pose() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for joint in rig.get_bone_count():
		result.append(rig.get_bone_pose(joint))
	return result


func blend_perch(weight: float) -> void:
	space.position = perch_space.lerp(space.position, weight)
	for joint in rig.get_bone_count():
		rig.set_bone_pose(joint, perch[joint].interpolate_with(rig.get_bone_pose(joint), weight))
	rig.force_update_all_bone_transforms()


func joint_height(label: String) -> float:
	var joint := rig.find_bone(label)
	assert(joint >= 0)
	return rig.to_global(rig.get_bone_global_pose(joint).origin).y


func raise_root(offset: float, clearance: float) -> void:
	var minimum := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
	var joint := rig.find_bone(RootJoint)
	assert(joint >= 0 and rig.get_bone_parent(joint) == -1)
	var target := rig.get_bone_pose_position(joint)
	target += rig.global_basis.inverse() * Vector3.UP * maxf(offset, clearance - minimum)
	rig.set_bone_pose_position(joint, target)
	rig.force_update_all_bone_transforms()


func turn(label: String, axis: Vector3, radians: float) -> void:
	var joint := rig.find_bone(label)
	assert(joint >= 0)
	var pose := rig.get_bone_global_pose(joint)
	pose.basis = Basis(Quaternion((rig.global_basis.inverse() * axis).normalized(), radians)) * pose.basis
	rig.set_bone_global_pose(joint, pose)
	rig.force_update_all_bone_transforms()


func verify_keys(after: Animation, before: Animation) -> void:
	assert(before.length == after.length and before.get_track_count() == after.get_track_count())
	for track in before.get_track_count():
		assert(before.track_get_path(track) == after.track_get_path(track))
		assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))


func preview_folder() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--eagle-preview="):
			return argument.trim_prefix("--eagle-preview=")
	return "res://local-art/creatures/original-eagle"
