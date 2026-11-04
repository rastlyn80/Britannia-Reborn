extends SceneTree

const ART := "res://local-art/creatures/"
const STEM := "monstrousinterredgrizzle-"
const CLIP := "GrizzleAntlerCheck"
const SOURCE_WINDOW := 2.8
const DURATION := 0.95

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var forms := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source := ART + STEM + treatment + ".scn"
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var donor := player.get_animation("Misc")
		assert(donor != null and donor.length > SOURCE_WINDOW)
		assert(player.get_animation_library("").add_animation(CLIP, retime(donor)) == OK)
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK)
		var output := ART + STEM + "antler-" + treatment + ".scn"
		assert(ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS) == OK)
		forms[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
		model.free()
	var path := "res://../work/creatures/mul-motion-review/grizzle-antler-bake.json"
	var receipt := FileAccess.open(path, FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path), "forms": forms}))
	receipt.close()
	print("GRIZZLE ANTLER CHECK: three source treatments retimed")
	quit()

func retime(source: Animation) -> Animation:
	var result := source.duplicate(true) as Animation
	result.length = DURATION
	result.loop_mode = Animation.LOOP_NONE
	for track in result.get_track_count():
		for key in range(result.track_get_key_count(track) - 1, -1, -1):
			result.track_remove_key(track, key)
		for sample in 115:
			var phase := float(sample) / 114.0
			var time := phase * SOURCE_WINDOW
			var key_time := phase * DURATION
			match source.track_get_type(track):
				Animation.TYPE_POSITION_3D:
					result.position_track_insert_key(track, key_time, source.position_track_interpolate(track, time))
				Animation.TYPE_ROTATION_3D:
					result.rotation_track_insert_key(track, key_time, source.rotation_track_interpolate(track, time))
				Animation.TYPE_SCALE_3D:
					result.scale_track_insert_key(track, key_time, source.scale_track_interpolate(track, time))
				_:
					assert(false, "Unexpected source track type")
	return result
