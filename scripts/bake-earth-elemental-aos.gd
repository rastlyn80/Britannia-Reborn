extends SceneTree

const ART := "res://local-art/creatures/earth-aos/"
const TREATMENTS := ["original", "rounded", "modern"]
const RISE_TIME := 1.5

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var assets := {}
	for treatment: String in TREATMENTS:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(ART + treatment + ".gltf", state) == OK)
		var model := document.generate_scene(state) as Node3D
		root.add_child(model)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("")
		var gesture := library.get_animation("Fidget").duplicate(true) as Animation
		gesture.loop_mode = Animation.LOOP_NONE
		assert(library.add_animation("StoneGesture", gesture) == OK)
		assert(library.add_animation("Assemble", build_assembly(player)) == OK)
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, ART + treatment + ".scn", ResourceSaver.FLAG_COMPRESS) == OK)
		assets[treatment] = {
			"source": FileAccess.get_sha256(ART + treatment + ".gltf"),
			"scene": FileAccess.get_sha256(ART + treatment + ".scn"),
		}
		model.free()
		print("EARTH ELEMENTAL: ", treatment, " StoneGesture and Assemble")
	var output := FileAccess.open(ART + "bake.json", FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify({"assets": assets, "recipe_sha256": FileAccess.get_sha256(get_script().resource_path)}))
	output.close()
	quit()

func build_assembly(player: AnimationPlayer) -> Animation:
	var death := player.get_animation("Death")
	var idle := player.get_animation("Idle")
	var clip := Animation.new()
	clip.length = RISE_TIME
	for source: Animation in [death, idle]:
		for index in source.get_track_count():
			var type := source.track_get_type(index)
			var path := source.track_get_path(index)
			if clip.find_track(path, type) < 0:
				var track := clip.add_track(type)
				clip.track_set_path(track, path)
	var lowered := false
	for track in clip.get_track_count():
		var type := clip.track_get_type(track)
		var path := clip.track_get_path(track)
		var collapsing := death.find_track(path, type)
		var standing := idle.find_track(path, type)
		var node := player.get_node(player.root_node).get_node(NodePath(path.get_concatenated_names())) as Node3D
		var bone := (node as Skeleton3D).find_bone(path.get_subname(0)) if path.get_subname_count() > 0 else -1
		var rest_position := (node as Skeleton3D).get_bone_rest(bone).origin if bone >= 0 else node.position
		var rest_rotation := (node as Skeleton3D).get_bone_rest(bone).basis.get_rotation_quaternion() if bone >= 0 else node.quaternion
		for sample in 181:
			var phase := float(sample) / 180.0
			# Spend the most time in the short source interval where the rock
			# limbs swing into place. Start below grade and finish at exact idle.
			var collapse_phase := 1.0 - 0.23 * smoothstep(0.05, 0.48, phase) - 0.77 * smoothstep(0.36, 0.89, phase)
			var source_time := clampf(collapse_phase, 0.0, 1.0) * death.length
			var settle := smoothstep(0.84, 1.0, phase)
			match type:
				Animation.TYPE_POSITION_3D:
					var start := death.position_track_interpolate(collapsing, source_time) if collapsing >= 0 else rest_position
					var end := idle.position_track_interpolate(standing, 0.0) if standing >= 0 else rest_position
					var position := start.lerp(end, settle)
					if node.name == &"SourceSpace":
						position.z -= 0.96 * (1.0 - smoothstep(0.02, 0.48, phase))
						lowered = true
					clip.position_track_insert_key(track, phase * RISE_TIME, position)
				Animation.TYPE_ROTATION_3D:
					var start := death.rotation_track_interpolate(collapsing, source_time) if collapsing >= 0 else rest_rotation
					var end := idle.rotation_track_interpolate(standing, 0.0) if standing >= 0 else rest_rotation
					clip.rotation_track_insert_key(track, phase * RISE_TIME, start.slerp(end, settle))
				_:
					assert(false, "Unexpected Earth Elemental animation channel")
	assert(lowered)
	return clip
