extends SceneTree

const REGISTRY := preload("res://Presentation/CreatureRegistry.gd")
const EXACT := preload("res://../scripts/test-quadruped-actions.gd")

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var row := REGISTRY.entry(778)
	var scenes := {}
	for treatment: String in ["original", "modern"]:
		var source := REGISTRY.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		assert(rig.get_bone_count() == 126)
		var library := player.get_animation_library("").duplicate() as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var root_rotation := (rig.global_basis.inverse() * Vector3.FORWARD).normalized()
		assert(library.add_animation("LarvaRecoil", fit(player.get_animation("Hit"), root_rotation, true)) == OK)
		assert(library.add_animation("LarvaTilt", fit(player.get_animation("Fidget"), root_rotation, false)) == OK)
		EXACT.check_earlier_keys(player, source)
		var output := "res://local-art/creatures/gazer_larva/swarm-distinct-actions-%s.scn" % treatment
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS) == OK)
		scenes[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
		model.free()
		print(treatment, " Gazer Larva, 126 preserved factor joints and two fitted motions")
	var receipt := FileAccess.open("res://local-art/creatures/gazer_larva/swarm-distinct-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	var inputs := {"bake-gazer-larva-distinct-actions.gd": FileAccess.get_sha256(get_script().resource_path)}
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": scenes}))
	receipt.close()
	quit()

func fit(source: Animation, axis: Vector3, recoil: bool) -> Animation:
	var result := Animation.new()
	result.length = 0.42 if recoil else 0.72
	assert(source.get_track_count() == 252)
	var samples := 61
	for track in source.get_track_count():
		var kind := source.track_get_type(track)
		var path := source.track_get_path(track)
		var id := result.add_track(kind)
		result.track_set_path(id, path)
		var root := path.get_concatenated_subnames() == &"__matrix_factor_0"
		for index in samples:
			var phase := float(index) / (samples - 1)
			var source_phase := phase
			if recoil:
				source_phase = 0.52 * smoothstep(0.0, 0.49, phase) + 0.48 * smoothstep(0.49, 1.0, phase)
			var at := source.length * source_phase
			var time := result.length * phase
			match kind:
				Animation.TYPE_POSITION_3D:
					result.position_track_insert_key(id, time, source.position_track_interpolate(track, at))
				Animation.TYPE_ROTATION_3D:
					var value := source.rotation_track_interpolate(track, at)
					if root:
						var accent := 0.16 * sin(TAU * phase) if recoil else -0.43 * sin(PI * phase)
						value = Quaternion(axis, accent) * value
					result.rotation_track_insert_key(id, time, value)
				Animation.TYPE_SCALE_3D:
					result.scale_track_insert_key(id, time, source.scale_track_interpolate(track, at))
				_:
					assert(false, "Expected only affine factor transforms")
	return result
