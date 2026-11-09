extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const BODY := 780
const CLIPS := {"BogBrace": ["Hit", 0.46], "BogBranchReach": ["Fidget", 0.86]}

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var row := Registry.entry(BODY)
	var retained: Dictionary = row.get("classic_gesture_base_assets", row.assets)
	var source: String = retained.original
	assert(source == retained.modern)
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert(rig.get_bone_count() == 116)
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for label: String in CLIPS:
		var spec: Array = CLIPS[label]
		assert(library.add_animation(label, fit(player, rig, label, spec[0], spec[1])) == OK)
	Exact.check_earlier_keys(player, source)
	player.stop()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK and ResourceSaver.save(scene, "res://local-art/creatures/bog-thing-gestures.scn",
		ResourceSaver.FLAG_COMPRESS) == OK)
	print("BOG THING: source tracks retained on all 116 affine joints, two fitted gestures")
	quit()

func fit(player: AnimationPlayer, rig: Skeleton3D, label: String, seed: String, length: float) -> Animation:
	var motion := Animation.new()
	motion.length = length
	var original := player.get_animation(seed)
	var accents: Dictionary = {
		"BogBrace": {"body": Vector2(0.16, -0.22), "r upper arm": Vector2(0.35, 0.32),
			"l upper arm": Vector2(0.30, -0.33), "r upper arm b": Vector2(0.10, 0.29),
			"upper jaw bone": Vector2(-0.18, 0.0), "lower jaw bone": Vector2(0.20, 0.0)},
		"BogBranchReach": {"body": Vector2(-0.13, 0.24), "r upper arm": Vector2(-0.48, -0.28),
			"l upper arm": Vector2(-0.27, 0.37), "r upper arm b": Vector2(-0.24, 0.13),
			"r forearm": Vector2(-0.14, 0.13), "upper jaw bone": Vector2(0.28, 0.0),
			"lower jaw bone": Vector2(-0.33, 0.0)},
	}[label]
	var drivers := {}
	for name: String in accents:
		var bone := rig.find_bone(name)
		assert(bone >= 1)
		var factor := rig.get_bone_parent(bone)
		assert(factor >= 0 and rig.get_bone_name(factor).begins_with("__matrix_factor_"))
		drivers[rig.get_bone_name(factor)] = accents[name]
	var retained_drivers := {}
	for track in original.get_track_count():
		var kind := original.track_get_type(track)
		var path := original.track_get_path(track)
		var output := motion.add_track(kind)
		motion.track_set_path(output, path)
		var name := path.get_concatenated_subnames()
		if kind == Animation.TYPE_ROTATION_3D and drivers.has(name):
			retained_drivers[name] = true
		for frame in 91:
			var phase := float(frame) / 90.0
			var source_time := phase * original.length
			var time := phase * length
			match kind:
				Animation.TYPE_POSITION_3D:
					motion.position_track_insert_key(output, time, original.position_track_interpolate(track, source_time))
				Animation.TYPE_SCALE_3D:
					motion.scale_track_insert_key(output, time, original.scale_track_interpolate(track, source_time))
				Animation.TYPE_ROTATION_3D:
					var value := original.rotation_track_interpolate(track, source_time)
					if drivers.has(name):
						var pulse := smoothstep(0.06, 0.44, phase) * (1.0 - smoothstep(0.58, 0.96, phase))
						var amount: Vector2 = drivers[name]
						value = value * Quaternion(Vector3.RIGHT, pulse * amount.x) * Quaternion(Vector3.UP, pulse * amount.y)
					motion.rotation_track_insert_key(output, time, value)
				_:
					assert(false, "Unexpected original affine track")
	assert(retained_drivers.size() == drivers.size())
	return motion
