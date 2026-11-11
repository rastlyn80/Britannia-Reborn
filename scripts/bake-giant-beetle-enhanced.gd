# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Body := 791
const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/giant-beetle-enhanced/"
const Gaits := {22: ["Walk", "BeetleQuietWalk"], 29: ["Walk", "BeetleMountedWalk"],
	30: ["Run", "BeetleMountedRun"], 31: ["Idle", "BeetleMountedIdle"]}
const WingRig := preload("beetle-wing-rig.gd")
const OpenClips := {
	0: ["Walk", "BeetleWingedWalk"], 1: ["Idle", "BeetleWingedIdle"],
	2: ["Death", "Death2"], 4: ["Attack", "BeetleWingedBite"],
	5: ["Attack2", "BeetleWingedHook"], 10: ["Hit", "BeetleWingedHit"],
	26: ["Fidget", "BeetleWingedFlare"], 27: ["Fidget2", "BeetleWingedDisplay"],
	28: ["Idle", "BeetleRaiseWings"],
}
const Heads := ["bip01 head", "horn 02", "horn 01", "large pincher r 03", "larger pincher l 03",
	"large pincher r 02", "larger pincher l 02", "small pincher r", "small pincher l"]
const Held := ["bip01 pelvis", "dummy01", "dummy02", "dummy03", "dummy04", "dummy05", "dummy06"]


func run() -> void:
	var row := Registry.entry(Body)
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var samples := 0
		for group: int in Gaits:
			var donor: String = Gaits[group][0]
			var name: String = Gaits[group][1]
			var clip := fitted_gait(player, rig, donor, group)
			assert(library.add_animation(name, clip) == OK)
			samples += verify_support_keys(player, rig, donor, name)
		player.stop()
		rig.reset_bone_poses()
		var wings := WingRig.new()
		wings.install(model, rig)
		var reset := Animation.new()
		var reset_tracks := wing_tracks(reset, player, wings)
		write_wing_keys(reset, wings, reset_tracks, 0.0)
		assert(library.add_animation("RESET", reset) == OK)
		for group: int in OpenClips:
			var donor: String = OpenClips[group][0]
			var name: String = OpenClips[group][1]
			assert(library.add_animation(name, fitted_wings(player, wings, donor, group)) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		var path := Destination + "%d-%s.scn" % [Body, treatment]
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("GIANT BEETLE GAITS ", treatment, " ", Gaits.size() + OpenClips.size(), " fits, ", samples,
			" unchanged seat and sole sample pairs / ", FileAccess.get_sha256(path))
	quit()


func wing_tracks(clip: Animation, player: AnimationPlayer, wings: WingRig) -> Dictionary:
	var rig_path := player.get_node(player.root_node).get_path_to(wings.rig)
	var result := {}
	for joint: int in wings.joints():
		var path := NodePath("%s:%s" % [rig_path, wings.rig.get_bone_name(joint)])
		var rotation := clip.add_track(Animation.TYPE_ROTATION_3D)
		var position := clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(rotation, path)
		clip.track_set_path(position, path)
		result[joint] = Vector2i(rotation, position)
	return result


func write_wing_keys(clip: Animation, wings: WingRig, tracks: Dictionary, time: float) -> void:
	for joint: int in tracks:
		var pair: Vector2i = tracks[joint]
		clip.rotation_track_insert_key(pair.x, time, wings.rig.get_bone_pose_rotation(joint))
		clip.position_track_insert_key(pair.y, time, wings.rig.get_bone_pose_position(joint))


func fitted_wings(player: AnimationPlayer, wings: WingRig, donor: String, group: int) -> Animation:
	var source := player.get_animation(donor)
	var clip := source.duplicate(true) as Animation
	var tracks := wing_tracks(clip, player, wings)
	var looping := group in [0, 1]
	var source_loop := source.loop_mode
	source.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	clip.loop_mode = source.loop_mode
	player.stop()
	player.play(donor, 0.0)
	player.advance(0.0)
	for index in 97:
		var phase := float(index) / 96.0
		var time := clip.length * phase
		wings.rig.reset_bone_poses()
		player.seek(time, true)
		wings.rig.force_update_all_bone_transforms()
		wings.spread(wing_spread(group, phase), phase)
		write_wing_keys(clip, wings, tracks, time)
	source.loop_mode = source_loop
	return clip


func wing_spread(group: int, phase: float) -> float:
	var pulse := sin(PI * phase)
	match group:
		0: return .88 + .075 * sin(TAU * 2.0 * phase)
		1: return .86 + .095 * sin(TAU * phase)
		2: return .94 * (1.0 - smoothstep(.40, .96, phase))
		4: return .86 + .16 * pulse
		5: return .89 + .21 * pulse * pulse
		10: return .86 + .20 * pulse
		26: return .86 + .19 * sin(TAU * phase)
		27: return .86 + .25 * pulse
		28: return .86 * smoothstep(.07, .88, phase)
	return 0.0


func fitted_gait(player: AnimationPlayer, rig: Skeleton3D, donor: String, group: int) -> Animation:
	var motion := player.get_animation(donor).duplicate(true) as Animation
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var tracks := {}
	for label: String in Heads:
		var bone := rig.find_bone(label)
		assert(bone >= 0)
		var path := NodePath("%s:%s" % [rig_path, label])
		var track := motion.find_track(path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, path)
		else:
			for key in range(motion.track_get_key_count(track) - 1, -1, -1):
				motion.track_remove_key(track, key)
		tracks[bone] = track
	player.play(donor, 0.0)
	player.advance(0.0)
	for index in 65:
		var phase := float(index) / 64.0
		var time := motion.length * phase
		rig.reset_bone_poses()
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		shape_head(rig, phase, group)
		for bone: int in tracks:
			motion.rotation_track_insert_key(tracks[bone], time, rig.get_bone_pose_rotation(bone))
	motion.loop_mode = Animation.LOOP_LINEAR
	return motion


func shape_head(rig: Skeleton3D, phase: float, group: int) -> void:
	var swing := sin(TAU * phase)
	var stride := sin(TAU * 2.0 * phase)
	var dip := -.065 + .040 * stride if group == 30 else -.036 + .025 * stride
	var nod := .06 * sin(PI * phase) * sin(PI * phase) if group == 31 else 0.0
	var jaw := .080 if group == 31 else .054
	var yaw := .028 * swing if group in [22, 31] else .014 * swing
	turn_world(rig, "bip01 head", Vector3.RIGHT, dip + nod)
	turn_world(rig, "bip01 head", Vector3.UP, yaw)
	turn_world(rig, "horn 02", Vector3.RIGHT, -.37 * dip + .040 * nod)
	turn_world(rig, "horn 01", Vector3.RIGHT, .31 * dip)
	turn_world(rig, "large pincher r 03", Vector3.UP, -jaw + .021 * swing)
	turn_world(rig, "larger pincher l 03", Vector3.UP, jaw + .021 * swing)
	turn_world(rig, "large pincher r 02", Vector3.RIGHT, .033 * stride)
	turn_world(rig, "larger pincher l 02", Vector3.RIGHT, .033 * stride)
	turn_world(rig, "small pincher r", Vector3.UP, -.32 * jaw)
	turn_world(rig, "small pincher l", Vector3.UP, .32 * jaw)


func verify_support_keys(player: AnimationPlayer, rig: Skeleton3D, donor: String, fitted: String) -> int:
	var reference := []
	var base_clip := player.get_animation(donor)
	var source_loop := base_clip.loop_mode
	base_clip.loop_mode = Animation.LOOP_LINEAR
	for clip: String in [donor, fitted]:
		player.stop()
		player.play(clip, 0.0)
		player.advance(0.0)
		for index in 65:
			rig.reset_bone_poses()
			player.seek(player.current_animation_length * index / 64.0, true)
			rig.force_update_all_bone_transforms()
			for label: String in Held:
				var pose := rig.get_bone_global_pose(rig.find_bone(label))
				if clip == donor:
					reference.append(pose)
				else:
					var expected: Transform3D = reference[index * Held.size() + Held.find(label)]
					assert(expected.is_equal_approx(pose), "%s moved %s at %d by %.8f" % [fitted, label, index, pose.origin.distance_to(expected.origin)])
	base_clip.loop_mode = source_loop
	return reference.size()
