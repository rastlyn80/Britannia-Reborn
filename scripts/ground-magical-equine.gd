# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
## Bundle local glTF after measuring penetration on the actual imported skin.

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Required := ["Idle", "Walk", "Run", "Attack", "Hit", "Death", "Fidget"]


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var input := ""
	var output := ""
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--input="):
			input = option.trim_prefix("--input=")
		elif option.begins_with("--output="):
			output = option.trim_prefix("--output=")
	if not input.is_absolute_path() or not output.is_absolute_path() or not output.ends_with(".scn"):
		fail("pass absolute --input= and --output= paths")
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(input, state) != OK:
		fail("could not load the local source glTF")
		return
	var actor := document.generate_scene(state)
	root.add_child(actor)
	var rigs := actor.find_children("*", "Skeleton3D", true, false)
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	var meshes := actor.find_children("*", "MeshInstance3D", true, false)
	if rigs.size() != 1 or players.size() != 1 or meshes.size() != 1:
		fail("one rig, player and skinned mesh are required")
		return
	var rig := rigs[0] as Skeleton3D
	var player := players[0] as AnimationPlayer
	var mesh := meshes[0] as MeshInstance3D
	var space := actor.find_child("SourceSpace", true, false) as Node3D
	if space == null or rig.get_bone_count() not in [30, 35, 38] or not Required.all(player.has_animation):
		fail("incomplete magical equine source")
		return
	player.deterministic = true
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skin := Ground.skin_points(mesh, rig)
	var rest := space.transform
	var parent_up := space.get_parent_node_3d().global_basis.inverse() * Vector3.UP
	var path := player.get_node(player.root_node).get_path_to(space)
	var maximum := 0.
	var samples := 0
	for clip: String in player.get_animation_list():
		if clip == "RESET":
			continue
		var motion := player.get_animation(clip)
		var track := motion.find_track(path, Animation.TYPE_POSITION_3D)
		if track < 0:
			fail("the original %s lacks its source-space track" % clip)
			return
		var time_keys := {}
		for channel in motion.get_track_count():
			for key in motion.track_get_key_count(channel):
				time_keys[motion.track_get_key_time(channel, key)] = true
		for step in int(ceil(motion.length * 240.)) + 1:
			time_keys[minf(motion.length, float(step) / 240.)] = true
		var times := time_keys.keys()
		times.sort()
		var positions := PackedVector3Array()
		player.stop()
		rig.reset_bone_poses()
		player.play(clip, 0.)
		player.advance(0.)
		for moment: float in times:
			player.seek(moment, true)
			rig.force_update_all_bone_transforms()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
			if not is_finite(gap):
				fail("non-finite source pose in " + clip)
				return
			var rise := maxf(0., .002 - gap)
			maximum = maxf(maximum, rise)
			positions.append(space.position + parent_up * rise)
			samples += 1
		player.stop()
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		for index in times.size():
			motion.position_track_insert_key(track, times[index], positions[index])
	rig.reset_bone_poses()
	space.transform = rest
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	var scene := PackedScene.new()
	if scene.pack(actor) != OK or ResourceSaver.save(scene, output,
			ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES) != OK:
		fail("could not save the grounded bundle")
		return
	print("MAGICAL EQUINE GROUND: ", samples, " measured skin poses, max upward correction ", maximum,
		" m, ", FileAccess.get_sha256(output))
	actor.free()
	quit()


func fail(message: String) -> void:
	printerr("MAGICAL EQUINE GROUND FAIL: ", message)
	quit(1)
