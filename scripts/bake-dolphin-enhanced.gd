# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-orc-enhanced.gd"

const DolphinOutput := "res://../work/creatures/native-form-audit/enhanced-source-gaps/bird-ettin/dolphin-enhanced.scn"
const DolphinClips := {25: "DolphinHover", 26: "DolphinBank"}
const DolphinFrames := {25: 11, 26: 8}
const DolphinJoints := ["body", "head", "flipper.L", "flipper.R", "tail_base", "tail_mid", "tail_tip", "flukes"]
const Bank: Array[float] = [0.0, .18, .43, .89, 1.0, .71, .28, 0.0]

func run() -> void:
	var source := Registry.asset_path(Registry.entry(151))
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for group: int in DolphinClips:
		assert(library.add_animation(DolphinClips[group], fit_water_motion(player, rig, group)) == OK)
	Exact.check_earlier_keys(player, source)
	player.stop()
	rig.reset_bone_poses()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, DolphinOutput, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("DOLPHIN ENHANCED: retained six-surface skin and two source-guided waterline motions")
	quit()

func fit_water_motion(player: AnimationPlayer, rig: Skeleton3D, group: int) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	var frames: int = DolphinFrames[group]
	clip.length = float(frames - 1) * .10
	clip.loop_mode = Animation.LOOP_NONE
	for track in clip.get_track_count():
		for key in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, key)
	var path := player.get_node(player.root_node).get_path_to(rig)
	var tracks := {}
	for name: String in DolphinJoints:
		var joint := rig.find_bone(name)
		assert(joint >= 0)
		var channel := NodePath("%s:%s" % [path, name])
		var track := clip.find_track(channel, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track, channel)
		tracks[joint] = track
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in frames:
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		var phase := float(frame) / (frames - 1)
		if group == 25:
			pose_hover(rig, phase)
		else:
			pose_bank(rig, Bank[frame], phase)
		for joint: int in tracks:
			clip.rotation_track_insert_key(tracks[joint], frame * .10, rig.get_bone_pose_rotation(joint))
	return clip

func pose_hover(rig: Skeleton3D, phase: float) -> void:
	var breath := sin(TAU * phase)
	var tail := sin(TAU * (phase - .10)) - sin(-TAU * .10)
	turn_world(rig, "body", Vector3.RIGHT, .036 * breath)
	turn_world(rig, "head", Vector3.RIGHT, -.021 * breath)
	turn_world(rig, "flipper.L", Vector3.BACK, .10 * breath)
	turn_world(rig, "flipper.R", Vector3.BACK, -.10 * breath)
	turn_world(rig, "tail_base", Vector3.RIGHT, -.048 * tail)
	turn_world(rig, "tail_mid", Vector3.RIGHT, -.022 * tail)
	turn_world(rig, "flukes", Vector3.RIGHT, .072 * tail)

func pose_bank(rig: Skeleton3D, bank: float, phase: float) -> void:
	var flex := sin(TAU * phase)
	turn_world(rig, "body", Vector3.BACK, -.24 * bank)
	turn_world(rig, "body", Vector3.UP, .12 * bank)
	turn_world(rig, "head", Vector3.RIGHT, .040 * bank)
	turn_world(rig, "flipper.L", Vector3.BACK, .12 * bank)
	turn_world(rig, "flipper.R", Vector3.BACK, -.30 * bank)
	turn_world(rig, "tail_base", Vector3.RIGHT, .080 * flex)
	turn_world(rig, "tail_mid", Vector3.RIGHT, .054 * flex)
	turn_world(rig, "tail_tip", Vector3.UP, -.09 * bank)
	turn_world(rig, "flukes", Vector3.RIGHT, -.040 * flex)
