extends "res://../scripts/bake-zombie-actions.gd"

const NEW_CLIPS := ["Death2", "RaisedWingKick", "WingRush", "Wingbeat",
	"WingTuckRecoil", "WideWingRecoil", "FeatherFlick", "AirDeath"]

func run() -> void:
	var variants := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(Registry.entry(73), treatment)
		var donor_source := Registry.asset_path(Registry.entry(30), treatment)
		assert(FileAccess.get_sha256(source) == Registry.entry(73).asset_sha256[treatment])
		assert(FileAccess.get_sha256(donor_source) == Registry.entry(30).asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		var donor := (load(donor_source) as PackedScene).instantiate()
		root.add_child(model)
		root.add_child(donor)
		var base_source := "res://local-art/creatures/harpies_harpy-%s.gltf" % treatment
		var baseline := (load(base_source) as PackedScene).instantiate()
		var base_space := baseline.find_child("SourceSpace", true, false) as Node3D
		var stone_rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var harpy_rig := donor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		assert(stone_rig.get_bone_count() == 34 and harpy_rig.get_bone_count() == 34)
		for bone in stone_rig.get_bone_count():
			assert(stone_rig.get_bone_name(bone) == harpy_rig.get_bone_name(bone))
			assert(stone_rig.get_bone_parent(bone) == harpy_rig.get_bone_parent(bone))
			assert(stone_rig.get_bone_rest(bone).is_equal_approx(harpy_rig.get_bone_rest(bone)))
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var donor_player := donor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var stone_root := player.get_node(player.root_node)
		var harpy_root := donor_player.get_node(donor_player.root_node)
		var stone_path := stone_root.get_path_to(stone_rig)
		var harpy_path := harpy_root.get_path_to(harpy_rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		for name: String in NEW_CLIPS:
			var clip := donor_player.get_animation(name).duplicate(true) as Animation
			for track in clip.get_track_count():
				var path := clip.track_get_path(track)
				var source_node := harpy_root.get_node(NodePath(path.get_concatenated_names()))
				if source_node == harpy_rig:
					assert(String(path.get_concatenated_names()) == String(harpy_path))
					clip.track_set_path(track, NodePath("%s:%s" % [stone_path, path.get_concatenated_subnames()]))
				else:
					assert(source_node == harpy_rig.get_parent() and path.get_subname_count() == 0)
					var source_space := source_node as Node3D
					var stone_space := stone_rig.get_parent() as Node3D
					assert(base_space.transform.is_equal_approx(stone_space.transform) and source_space.basis.is_equal_approx(stone_space.basis))
					clip.track_set_path(track, stone_root.get_path_to(stone_space))
			assert(library.add_animation(name, clip) == OK)
		Exact.check_earlier_keys(player, source)
		var packed := PackedScene.new()
		var target := "res://local-art/creatures/stone-harpy-actions-%s.scn" % treatment
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
		variants[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target),
			"donor": FileAccess.get_sha256(donor_source), "donor_rest": FileAccess.get_sha256(base_source)}
		baseline.free()
		model.free()
		donor.free()
		print(treatment, " Stone Harpy, 34 rest joints, eight motions, earlier clip keys retained")
	write_receipt("stone-harpy-actions", 73, variants, ["bake-stone-harpy-actions.gd", "bake-zombie-actions.gd"])
	quit()
