extends SceneTree

const ART := "res://local-art/creatures/khaldun_doom/"
const OUTPUT := "res://local-art/creatures/restless_soul_actions/"
const BASIS := "res://../work/creatures/mul-motion-review/ghost-on-foot-metrics.json"
const GROUND := preload("res://Presentation/SourceGroundLookup.gd")
const TREATMENTS := ["original", "rounded", "modern"]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DirAccess.make_dir_recursive_absolute(OUTPUT) == OK)
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASIS))
	var row: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "preparation.json")).models[1]
	assert(int(row.bodies[0].body) == 970)
	var base := (load(ART + "restless-soul-on-foot-review.scn") as PackedScene).instantiate()
	var donor := base.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for treatment: String in TREATMENTS:
		var model := (load(row.assets[treatment]) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("")
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var space := model.find_child("SourceSpace", true, false) as Node3D
		var skin := GROUND.skin_points(mesh, rig)
		player.deterministic = true
		var max_lift := 0.0
		for slot: String in recipe:
			var label: String = recipe[slot].clip
			var clip := donor.get_animation(label).duplicate(true) as Animation
			assert(library.add_animation(label, clip) == OK)
			max_lift = maxf(max_lift, calibrate_floor(player, rig, space, skin, label, clip))
		player.stop()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		var path := OUTPUT + "restless-soul-" + treatment + ".scn"
		assert(ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS) == OK)
		row.assets[treatment] = path
		row.asset_sha256[treatment] = FileAccess.get_sha256(path)
		print("GHOST STAGED ", treatment, " additional floor lift ", max_lift)
		model.free()
	base.free()
	row.family = "restless_soul_actions"
	var frames := [10, 10, 10, 10, 1, 5, 5, 1, 1, 7, 7, 7, 7, 7, 7, 10, 7, 7, 7, 7, 5, 6, 6, 5, 5, 1, 5, 5, 7, 5, 5, 7, 5, 5, 5]
	row.action_witness_frames = {}
	for slot: String in recipe:
		assert(row.classic_action_categories[slot] == "")
		row.classic_action_categories[slot] = recipe[slot].clip
		row.action_witness_frames[slot] = frames[int(slot)]
	var output := FileAccess.open(OUTPUT + "preparation.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"models": [row], "review_metrics_sha256": FileAccess.get_sha256(BASIS)}, "\t"))
	output.close()
	print("GHOST STAGED: ", recipe.size(), " on-foot routes in all three treatments")
	quit()

func calibrate_floor(player: AnimationPlayer, rig: Skeleton3D, space: Node3D, skin: Dictionary,
		label: String, clip: Animation) -> float:
	var maximum := 0.0
	var space_path := player.get_node(player.root_node).get_path_to(space)
	var track := clip.find_track(space_path, Animation.TYPE_POSITION_3D)
	assert(track >= 0)
	var placements: Array[Vector3] = []
	var lift_vector := space.get_parent_node_3d().global_basis.inverse() * Vector3.UP
	var samples := ceili(clip.length * 180.0)
	player.stop()
	player.play(label, 0.0)
	player.advance(0.0)
	for sample in range(samples + 1):
		var time := clip.length * float(sample) / samples
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		var gap := GROUND.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var lift := maxf(0.0, 0.006 - gap)
		maximum = maxf(maximum, lift)
		placements.append(clip.position_track_interpolate(track, time) + lift_vector * lift)
	player.stop()
	for key in range(clip.track_get_key_count(track) - 1, -1, -1):
		clip.track_remove_key(track, key)
	for sample in placements.size():
		clip.position_track_insert_key(track, clip.length * float(sample) / samples, placements[sample])
	return maximum
