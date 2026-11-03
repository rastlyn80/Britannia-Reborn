extends SceneTree

const FOLDER := "res://local-art/creatures/raptor/"
const PREFIX := "Armature|Velociraptor_"

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("bake")

func bake() -> void:
	var source := load("res://local-art/creatures/raptor-trial/Velociraptor.fbx") as PackedScene
	var model := source.instantiate() as Node3D
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert(rig.get_bone_count() == 37 and mesh.mesh.get_surface_count() == 3 and mesh.skin != null)
	var bounds := (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
	assert(bounds.size.z > bounds.size.y and bounds.size.z > bounds.size.x)
	model.scale = Vector3.ONE * (2.5 / bounds.size.z)
	var center := bounds.get_center()
	center.y = bounds.position.y
	model.position = -(model.basis * center)

	var original := player.get_animation_library("")
	var library := AnimationLibrary.new()
	for clip in ["Attack", "Death", "Idle", "Jump", "Run", "Walk"]:
		var motion := original.get_animation(PREFIX + clip)
		assert(motion != null and motion.get_track_count() == 36)
		library.add_animation(clip, motion)
	var idle := library.get_animation("Idle")
	var hit := Animation.new()
	hit.length = 0.42
	for track in idle.get_track_count():
		var type := idle.track_get_type(track)
		var target := hit.add_track(type)
		var path := idle.track_get_path(track)
		hit.track_set_path(target, path)
		var rest: Variant = idle.track_get_key_value(track, 0)
		var recoil: Variant = rest
		if type == Animation.TYPE_ROTATION_3D and str(path).ends_with(":Torso"):
			recoil = rest * Quaternion(Vector3.RIGHT, -0.27)
		elif type == Animation.TYPE_ROTATION_3D and str(path).ends_with(":Head"):
			recoil = rest * Quaternion(Vector3.RIGHT, 0.42)
		hit.track_insert_key(target, 0.0, rest)
		hit.track_insert_key(target, 0.11, recoil)
		hit.track_insert_key(target, hit.length, rest)
	library.add_animation("Hit", hit)
	library.add_animation("Fidget", idle.duplicate())
	player.remove_animation_library("")
	player.add_animation_library("", library)

	var triangles := 0
	for surface in mesh.mesh.get_surface_count():
		triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
		var material := mesh.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
		var palette := {"c7a172": "bf8343", "ffffff": "c8b292"}
		var color := Color(palette.get(material.albedo_color.to_html(false), material.albedo_color.to_html(false)))
		var texture := Image.create_empty(4, 4, false, Image.FORMAT_RGB8)
		texture.fill(color)
		material.albedo_color = Color.WHITE
		material.albedo_texture = ImageTexture.create_from_image(texture)
		material.roughness = 0.86
		mesh.mesh.surface_set_material(surface, material)
	assert(triangles == 1248)
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, FOLDER + "raptor.scn", ResourceSaver.FLAG_COMPRESS) == OK)
	print("RAPTOR BAKE: 1248 triangles, 37 bones, six CC0 clips and authored recoil")
	quit()
