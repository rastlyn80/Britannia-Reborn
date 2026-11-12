# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const TargetArt := "res://local-art/creatures/serpents_snake_giant_silver-"
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const Shared := ["SerpentCombatSlither", "SerpentQuietIdle", "SerpentUncoilStrike", "SerpentSurface",
	"SerpentLowWatch", "SerpentRaisedCoil", "SerpentCoilAlert", "LowNeckRecoil", "Death2"]


func _initialize() -> void:
	create_timer(70.).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	var folder := ""
	var sibling := "res://local-art/creatures/giant-serpent-enhanced"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--study="):
			folder = argument.trim_prefix("--study=")
		if argument.begins_with("--donor="):
			sibling = argument.trim_prefix("--donor=")
	assert(not folder.is_empty(), "Supply the private bake output directory.")
	var result := {}
	for style: String in ["original", "rounded", "modern"]:
		var donor_path := sibling.path_join("giant-serpent-enhanced-%s.scn" % style)
		var target_path := TargetArt + style + ".gltf"
		var donor := (load(donor_path) as PackedScene).instantiate()
		var silver := (load(target_path) as PackedScene).instantiate()
		root.add_child(donor)
		root.add_child(silver)
		var old_rig := donor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var new_rig := silver.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var old_player := donor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var new_player := silver.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var old_root := old_player.get_node(old_player.root_node)
		var new_root := new_player.get_node(new_player.root_node)
		var mesh := silver.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var new_space := silver.find_child("SourceSpace", true, false) as Node3D
		var rest_space := new_space.transform
		var library := new_player.get_animation_library("").duplicate(true) as AnimationLibrary
		new_player.remove_animation_library("")
		new_player.add_animation_library("", library)
		new_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var clips := {}
		for name: String in Shared:
			assert(not library.has_animation(name))
			var clip := old_player.get_animation(name).duplicate(true) as Animation
			remap_tracks(clip, old_root, new_root, old_rig, new_rig, new_space)
			assert(library.add_animation(name, clip) == OK)
			clips[name] = measure(new_player, new_rig, mesh, name)
		verify_prior_keys(new_player, target_path)
		new_player.stop()
		new_rig.reset_bone_poses()
		new_space.transform = rest_space
		new_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		var packed := PackedScene.new()
		assert(packed.pack(silver) == OK)
		var scene_path := folder.path_join("silver-serpent-enhanced-%s.scn" % style)
		assert(ResourceSaver.save(packed, scene_path, ResourceSaver.FLAG_COMPRESS) == OK)
		result[style] = {"source_sha256": FileAccess.get_sha256(target_path),
			"donor_sha256": FileAccess.get_sha256(donor_path), "scene_sha256": FileAccess.get_sha256(scene_path),
			"shared_clips": clips}
		donor.free()
		silver.free()
		print("SILVER SERPENT FIT: ", style, ", nine retargeted clips with every source key and material retained")
	var output := FileAccess.open(folder.path_join("shared-motion-bake.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "  "))
	output.close()
	quit()


func remap_tracks(clip: Animation, donor_root: Node, target_root: Node, old_rig: Skeleton3D,
		new_rig: Skeleton3D, new_space: Node3D) -> void:
	for track in range(clip.get_track_count() - 1, -1, -1):
		var path := clip.track_get_path(track)
		var node := donor_root.get_node_or_null(NodePath(str(path).get_slice(":", 0)))
		assert(node != null, str(path))
		if node == old_rig and path.get_subname_count() > 0:
			var name := path.get_subname(0)
			var old_bone := old_rig.find_bone(name)
			var new_bone := new_rig.find_bone(name)
			if name == &"serpents_snake_giant" and new_bone < 0:
				# This unweighted leaf names the source model.
				clip.remove_track(track)
				continue
			assert(old_bone >= 0 and new_bone >= 0, str(path))
			var a := old_rig.get_bone_rest(old_bone)
			var b := new_rig.get_bone_rest(new_bone)
			assert(a.origin.distance_to(b.origin) < .001
				and a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion()) < .005, str(path))
			for key in clip.track_get_key_count(track):
				var value: Variant = clip.track_get_key_value(track, key)
				match clip.track_get_type(track):
					Animation.TYPE_POSITION_3D:
						clip.track_set_key_value(track, key, b.origin + value - a.origin)
					Animation.TYPE_ROTATION_3D:
						var rotation: Quaternion = b.basis.get_rotation_quaternion() * a.basis.get_rotation_quaternion().inverse() * value
						clip.track_set_key_value(track, key, rotation.normalized())
			clip.track_set_path(track, NodePath("%s:%s" % [target_root.get_path_to(new_rig), name]))
		else:
			assert(node.name == "SourceSpace" and path.get_subname_count() == 0, str(path))
			clip.track_set_path(track, target_root.get_path_to(new_space))


func measure(player: AnimationPlayer, rig: Skeleton3D, mesh: MeshInstance3D, name: String) -> Dictionary:
	player.play(name, 0.)
	player.advance(0.)
	var min_floor := INF
	var max_floor := -INF
	var min_head := INF
	var max_head := -INF
	var skin := Ground.skin_points(mesh, rig)
	var head := rig.find_bone("bip01 head")
	for sample in 41:
		player.seek(player.current_animation_length * float(sample) / 40., true)
		rig.force_update_all_bone_transforms()
		var box := Geometry.deformed_bounds(mesh, rig)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		assert(box.is_finite() and box.size.length() < 14. and is_finite(gap))
		min_floor = minf(min_floor, gap)
		max_floor = maxf(max_floor, gap)
		var y := rig.to_global(rig.get_bone_global_pose(head).origin).y
		min_head = minf(min_head, y)
		max_head = maxf(max_head, y)
	return {"min_floor": min_floor, "max_floor": max_floor, "head_height": [min_head, max_head], "samples": 41}


func verify_prior_keys(player: AnimationPlayer, source: String) -> void:
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
