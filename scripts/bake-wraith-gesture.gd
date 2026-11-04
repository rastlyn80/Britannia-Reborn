extends SceneTree

const ART := "res://local-art/creatures/"
const TREATMENTS := ["original", "rounded", "modern"]
const LENGTH := 0.85

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	for treatment: String in TREATMENTS:
		var source := ART + "spirits_ghost-" + treatment + ".gltf"
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var animator := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := animator.get_animation_library("")
		assert(library.add_animation("GhostSway", sway(library.get_animation("Idle"))) == OK)
		if treatment != "modern":
			var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold = 0.12
				mesh.mesh.surface_set_material(surface, material)
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, ART + "mul-gesture-26-" + treatment + ".scn", ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("WRAITH ", treatment, ": GhostSway")
	quit()

func sway(idle: Animation) -> Animation:
	var result := Animation.new()
	result.length = LENGTH
	for track in idle.get_track_count():
		var type := idle.track_get_type(track)
		var destination := result.add_track(type)
		result.track_set_path(destination, idle.track_get_path(track))
		for index in 103:
			var phase := float(index) / 102.0
			var time := phase * LENGTH
			var donor := phase * idle.length
			# Classic slot 11 holds the pose with a small cloth and arm shift.
			var amount := 0.48 * pow(sin(PI * phase), 2.0)
			match type:
				Animation.TYPE_POSITION_3D:
					var start := idle.position_track_interpolate(track, 0.0)
					result.position_track_insert_key(destination, time, start.lerp(idle.position_track_interpolate(track, donor), amount))
				Animation.TYPE_ROTATION_3D:
					var start := idle.rotation_track_interpolate(track, 0.0)
					result.rotation_track_insert_key(destination, time, start.slerp(idle.rotation_track_interpolate(track, donor), amount))
				_:
					assert(false, "Unexpected Wraith idle channel")
	return result
