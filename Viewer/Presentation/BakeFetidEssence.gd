extends SceneTree

const OUTPUT := "res://local-art/creatures/fetid_essence/fetid-essence.scn"

const Surface = preload("res://Presentation/FetidEssenceSurface.gdshader")

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("bake")

func bake() -> void:
	var source := load("res://Art/Creatures/Wisp/wisp.scn") as PackedScene
	assert(source != null)
	var model := source.instantiate() as Node3D
	root.add_child(model)
	var rig := model.get_node("Rig") as Skeleton3D
	var player := model.get_node("AnimationPlayer") as AnimationPlayer
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for clip in library.get_animation_list():
		var motion := library.get_animation(clip)
		for track in motion.get_track_count():
			if motion.track_get_type(track) != Animation.TYPE_SCALE_3D:
				continue
			var path := str(motion.track_get_path(track))
			for index in motion.track_get_key_count(track):
				var value: Vector3 = motion.track_get_key_value(track, index)
				if path.ends_with(":EnergyRoot"):
					value *= Vector3(1.7, 1.35, 1.6)
				elif path.contains(":Ray"):
					value *= Vector3(1.85, 0.8, 1.85)
				motion.track_set_key_value(track, index, value)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.mesh = mesh.mesh.duplicate()
		var material := mesh.mesh.surface_get_material(0).duplicate() as ShaderMaterial
		material.shader = Surface
		material.set_shader_parameter("core", mesh.name in ["Core", "Halo"])
		material.set_shader_parameter("energy_colour", Color("79ae3a"))
		material.set_shader_parameter("density", 0.56 if mesh.name == "Core" else 0.82)
		mesh.mesh.surface_set_material(0, material)
	assert(rig.get_bone_count() == 7 and library.has_animation("Cast"))
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, OUTPUT, ResourceSaver.FLAG_COMPRESS) == OK)
	print("FETID ESSENCE BAKE: seven-joint green energy model with Wisp-derived motions")
	quit()

