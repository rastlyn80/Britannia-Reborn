# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Ground := preload("res://Presentation/SourceGroundLookup.gd")

static func fit_source_floor(model: Node3D) -> void:
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var source_space := model.find_child("SourceSpace", true, false) as Node3D
	assert(is_instance_valid(source_space))
	var data := Ground.skin_points(mesh, rig)
	var path := player.get_node(player.root_node).get_path_to(source_space)
	var up := source_space.get_parent_node_3d().global_basis.inverse() * Vector3.UP
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for name: String in player.get_animation_list():
		var clip := player.get_animation(name)
		var track := clip.find_track(path, Animation.TYPE_POSITION_3D)
		assert(track >= 0, str([name, path]))
		var positions := PackedVector3Array()
		var samples := ceili(240.0 * clip.length)
		var lift_max := 0.0
		player.play(name, 0.)
		player.advance(0.)
		for sample in samples + 1:
			var time := clip.length * float(sample) / float(samples)
			player.seek(time, true)
			rig.force_update_all_bone_transforms()
			var gap := Ground.minimum_plane_gap(data, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
			assert(is_finite(gap))
			var lift := maxf(0.0, 0.003 - gap)
			lift_max = maxf(lift_max, lift)
			positions.append(source_space.position + up * lift)
		player.stop()
		for key in range(clip.track_get_key_count(track) - 1, -1, -1):
			clip.track_remove_key(track, key)
		for sample in samples + 1:
			clip.position_track_insert_key(track, clip.length * float(sample) / float(samples), positions[sample])
		print("SOURCE SKIN FLOOR ", name, " maximum lift ", lift_max)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
