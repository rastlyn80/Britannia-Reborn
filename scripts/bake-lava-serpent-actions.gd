extends SceneTree
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const NEW := ["Death2", "CoilSnap", "LongStrike", "NeckDrawback", "LowNeckRecoil", "TailRipple"]
func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")
func run() -> void:
	var row := Registry.entry(90)
	var assets: Dictionary = row.classic_gesture_base_assets if row.get("classic_gesture_batch") == "ratman_lava_actions" else row.assets
	var scenes := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source: String = assets[treatment]
		var donor := Registry.asset_path(Registry.entry(21), treatment)
		var target := "res://local-art/creatures/lava-serpent-actions-%s.scn" % treatment
		bake(treatment, source, donor, target)
		scenes[treatment] = {"source": FileAccess.get_sha256(source), "donor": FileAccess.get_sha256(donor),
			"scene": FileAccess.get_sha256(target)}
	var receipt := FileAccess.open("res://local-art/creatures/lava-serpent-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path), "scenes": scenes}))
	receipt.close()
	quit()

func bake(treatment: String, source: String, donor_path: String, target: String) -> void:
	var donor := (load(donor_path) as PackedScene).instantiate()
	root.add_child(donor)
	var donor_player := donor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var donor_rig := donor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var path := player.get_node(player.root_node).get_path_to(rig)
	var copied := 0
	for clip: String in NEW:
		var animation := donor_player.get_animation(clip).duplicate(true) as Animation
		for track in range(animation.get_track_count() - 1, -1, -1):
			var track_path := animation.track_get_path(track)
			var joint := str(track_path.get_concatenated_subnames())
			if joint.is_empty():
				var source_space := donor_player.get_node(donor_player.root_node).get_node(track_path) as Node3D
				var target_space := rig.get_parent() as Node3D
				assert(source_space.name == "SourceSpace" and target_space.name == "SourceSpace")
				assert(source_space.basis.is_equal_approx(target_space.basis) and animation.track_get_type(track) == Animation.TYPE_POSITION_3D)
				animation.track_set_path(track, player.get_node(player.root_node).get_path_to(target_space))
				var shift := target_space.position - source_space.position
				for key in animation.track_get_key_count(track):
					animation.track_set_key_value(track, key, Vector3(animation.track_get_key_value(track, key)) + shift)
				continue
			var from := donor_rig.find_bone(joint)
			var to := rig.find_bone(joint)
			if to < 0:
				assert(joint == "serpents_snake_giant", "Unmapped %s / %s type %d" % [clip, animation.track_get_path(track), animation.track_get_type(track)])
				animation.remove_track(track)
				continue
			assert(from >= 0 and donor_rig.get_bone_rest(from).is_equal_approx(rig.get_bone_rest(to)))
			animation.track_set_path(track, NodePath("%s:%s" % [path, joint]))
			copied += 1
		assert(library.add_animation(clip, animation) == OK)
	Exact.check_earlier_keys(player, source)
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK and ResourceSaver.save(scene, target, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	donor.free()
	print("LAVA SERPENT ", treatment, ": six shared-rig motions and ", copied, " exact tracks; earlier keys retained")
