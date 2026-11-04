extends "res://../scripts/bake-dog-bear-actions.gd"

const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const CLIPS := ["Attack2", "Death", "Fidget2", "Death2"]

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var scenes := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var target_path := Registry.asset_path(Registry.entry(25), treatment)
		var donor_path := Registry.asset_path(Registry.entry(225), treatment)
		var target := (load(target_path) as PackedScene).instantiate()
		var donor := (load(donor_path) as PackedScene).instantiate()
		root.add_child(target)
		var rig := target.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var timber_rig := donor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		assert(rig.get_bone_count() == 32 and rig.get_bone_count() == timber_rig.get_bone_count())
		for bone in rig.get_bone_count():
			assert(rig.get_bone_name(bone) == timber_rig.get_bone_name(bone))
			assert(rig.get_bone_parent(bone) == timber_rig.get_bone_parent(bone))
			assert(rig.get_bone_rest(bone).is_equal_approx(timber_rig.get_bone_rest(bone)))
		var player := target.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var timber_player := donor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		library.rename_animation("Death", "RecoveredDeath")
		library.rename_animation("Attack", "RecoveredAttack")
		for clip: String in CLIPS:
			assert(library.add_animation(clip, timber_player.get_animation(clip).duplicate(true)) == OK)
		player.deterministic = true
		var mesh := target.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		assert(library.add_animation("Attack", calibrated_attack(player, rig, skin)) == OK)
		Exact.check_earlier_keys(player, target_path)
		for clip: String in CLIPS:
			player.play(clip, 0.0)
			player.advance(0.0)
			var minimum := INF
			for frame in 65:
				player.seek(player.current_animation_length * frame / 64.0, true)
				rig.force_update_all_bone_transforms()
				minimum = minf(minimum, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
			assert(minimum > -0.006)
			print(treatment, " ", clip, " clearance ", minimum)
		player.stop()
		var output := PackedScene.new()
		var destination := "res://local-art/creatures/grey-wolf-actions-%s.scn" % treatment
		assert(output.pack(target) == OK and ResourceSaver.save(output, destination, ResourceSaver.FLAG_COMPRESS) == OK)
		scenes[treatment] = {"source": FileAccess.get_sha256(target_path),
			"donor": FileAccess.get_sha256(donor_path), "scene": FileAccess.get_sha256(destination)}
		donor.free()
		target.free()
	save_receipt("res://local-art/creatures/grey-wolf-actions-bake.json", scenes)
	print("GREY WOLF BAKE: 32 matching joints, 780 pose samples, exact retained source keys")
	quit()

func save_receipt(path: String, scenes: Dictionary) -> void:
	var inputs := {}
	for file: String in [get_script().resource_path, "res://../scripts/bake-dog-bear-actions.gd",
		"res://../scripts/bake-quadruped-actions.gd",
		"res://Presentation/WaterElementalFidgets.gd",
		"res://Presentation/SourceGroundLookup.gd"]:
		inputs[file.get_file()] = FileAccess.get_sha256(file)
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify({"inputs": inputs, "scenes": scenes}, "\t"))
	output.close()
