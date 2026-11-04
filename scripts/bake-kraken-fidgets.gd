extends SceneTree

const STEM := "res://local-art/creatures/krakens_kraken"

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var scenes := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source := "%s-%s.gltf" % [STEM, treatment]
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("")
		var sweep := library.get_animation("Fidget")
		var pulse := mantle_pulse(library.get_animation("Idle"), sweep)
		library.rename_animation("Fidget", "Fidget2")
		assert(library.add_animation("Fidget", pulse) == OK)
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		var output := "%s-fidgets-%s.scn" % [STEM, treatment]
		assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
		scenes[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
		model.free()
	var receipt := FileAccess.open("res://../work/creatures/mul-motion-review/kraken-fidgets-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path), "scenes": scenes}))
	receipt.close()
	print("KRAKEN: shallow Classic 11/17 pulse and unchanged recovered sweep for 18")
	quit()

func mantle_pulse(idle: Animation, sweep: Animation) -> Animation:
	var motion := idle.duplicate(true) as Animation
	motion.length = 1.06
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		var first: Variant = idle.track_get_key_value(track, 0)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		var path := motion.track_get_path(track)
		var joint := str(path.get_concatenated_subnames())
		var tentacle := " calf" in joint or " foot" in joint or " toe" in joint
		var mantle := joint in ["bip01 spine1", "bip01 spine2", "bip01 neck"]
		if motion.track_get_type(track) != Animation.TYPE_ROTATION_3D or not (tentacle or mantle):
			motion.track_insert_key(track, 0.0, first)
			continue
		var donor := sweep.find_track(path, Animation.TYPE_ROTATION_3D)
		assert(donor >= 0)
		var initial := sweep.rotation_track_interpolate(donor, 0.0).inverse()
		var amplitude := 0.15 if tentacle else 0.10
		for sample in 73:
			var phase := float(sample) / 72.0
			var relative := initial * sweep.rotation_track_interpolate(donor, sweep.length * phase)
			var strength := amplitude * (1.0 - smoothstep(0.85, 1.0, phase))
			motion.rotation_track_insert_key(track, motion.length * phase,
				(first * Quaternion.IDENTITY.slerp(relative, strength)).normalized())
	return motion
