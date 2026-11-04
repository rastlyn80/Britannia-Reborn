extends SceneTree

const SOURCE := "res://local-art/creatures/flails_corpser-modern.gltf"
const OUTPUT := "res://local-art/creatures/corpser-emergence.scn"

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("bake")

func bake() -> void:
	var model := (load(SOURCE) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var library := player.get_animation_library("")
	var idle := library.get_animation("Idle")
	var emergence := idle.duplicate(true) as Animation
	emergence.length = 1.1
	emergence.loop_mode = Animation.LOOP_NONE
	var root_translation := false
	var parent := rig.get_bone_parent(rig.find_bone("bip01"))
	var up := (rig.global_basis * rig.get_bone_global_rest(parent).basis).inverse() * Vector3.UP
	for track in emergence.get_track_count():
		var kind := idle.track_get_type(track)
		var path := str(idle.track_get_path(track))
		for key in range(emergence.track_get_key_count(track) - 1, -1, -1):
			emergence.track_remove_key(track, key)
		for step in 17:
			var phase := float(step) / 16.0
			var time := idle.length * phase * 0.55
			var value: Variant
			if kind == Animation.TYPE_POSITION_3D:
				value = idle.position_track_interpolate(track, time)
				if path.ends_with(":bip01"):
					root_translation = true
					value -= up * (2.20 * (1.0 - smoothstep(0.04, 0.92, phase)))
			elif kind == Animation.TYPE_ROTATION_3D:
				value = idle.rotation_track_interpolate(track, time)
			elif kind == Animation.TYPE_SCALE_3D:
				value = idle.scale_track_interpolate(track, time)
			else:
				assert(false, "Unexpected source track")
			emergence.track_insert_key(track, phase * emergence.length, value)
	assert(root_translation)
	library.add_animation("Emerge", emergence)
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, OUTPUT, ResourceSaver.FLAG_COMPRESS) == OK)
	print("CORPSER BAKE: source-rig rise clip from classic slot 12 reference")
	quit()
