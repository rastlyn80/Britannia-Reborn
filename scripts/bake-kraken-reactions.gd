extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const STEM := "res://local-art/creatures/kraken-brief-hit"

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var row := Registry.entry(77)
	assert(not row.has("classic_gesture_batch") and row.kind == "krakens_kraken" and row.classic_gesture_native_sha256)
	var scenes := {}
	for treatment: String in row.assets:
		var source: String = row.assets[treatment]
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("")
		var hit := library.get_animation("Hit")
		var clip := hit.duplicate(true) as Animation
		clip.length = hit.length * 0.75
		for track in clip.get_track_count():
			for key in range(clip.track_get_key_count(track) - 1, -1, -1):
				clip.track_remove_key(track, key)
			for sample in 41:
				var phase := float(sample) / 40.0
				# Both short Classic slots use the same neutral, recoil and neutral views.
				var pulse := smoothstep(0.0, 0.5, phase) if phase <= 0.5 else 1.0 - smoothstep(0.5, 1.0, phase)
				var donor_time := hit.length * 0.31 * pulse
				var time := clip.length * phase
				match clip.track_get_type(track):
					Animation.TYPE_POSITION_3D:
						clip.position_track_insert_key(track, time, hit.position_track_interpolate(track, donor_time))
					Animation.TYPE_ROTATION_3D:
						clip.rotation_track_insert_key(track, time, hit.rotation_track_interpolate(track, donor_time))
					Animation.TYPE_SCALE_3D:
						clip.scale_track_insert_key(track, time, hit.scale_track_interpolate(track, donor_time))
					_:
						assert(false, "Unexpected Kraken track type")
		assert(library.add_animation("BriefHit", clip) == OK)
		var output := PackedScene.new()
		var path := "%s-%s.scn" % [STEM, treatment]
		assert(output.pack(model) == OK and ResourceSaver.save(output, path, ResourceSaver.FLAG_COMPRESS) == OK)
		scenes[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(path)}
		model.free()
	var receipt := FileAccess.open(STEM + ".json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path), "scenes": scenes}))
	receipt.close()
	print("KRAKEN: recovered long hit plus short recoil shared by the two equal source groups")
	quit()
