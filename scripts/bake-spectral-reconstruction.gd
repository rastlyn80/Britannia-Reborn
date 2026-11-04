extends SceneTree

const ART := "res://local-art/creatures/khaldun_doom/"
const FIT := "res://../work/creatures/mul-motion-review/spectral-silhouette-fit.json"
const Ground := preload("res://Presentation/SourceGroundLookup.gd")

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIT))
	var groups := {}
	var guard := point(data.guard)
	for row: Dictionary in data.poses:
		var slot := int(row.slot)
		if not groups.has(slot):
			groups[slot] = []
		assert(groups[slot].size() == int(row.frame))
		groups[slot].append(row)
	var model := (load(ART + "spectral-scimitar.gltf") as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.deterministic = true
	var library := player.get_animation_library("")
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var path := NodePath("%s:weapon_scimitar" % player.get_node(player.root_node).get_path_to(rig))
	var inverse := rig.global_basis.inverse()
	for slot: int in groups:
		var rows: Array = groups[slot]
		var clip := Animation.new()
		clip.length = rows.size() * 0.16
		var position := clip.add_track(Animation.TYPE_POSITION_3D)
		var rotation := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(position, path)
		clip.track_set_path(rotation, path)
		for index in rows.size():
			var row: Dictionary = rows[index]
			var hilt := point(row.hilt)
			var columns: Array = row.basis
			var pose := (inverse * Basis(point(columns[0]), point(columns[1]), point(columns[2]))).orthonormalized()
			assert(pose.is_finite() and pose.determinant() > 0.99)
			clip.position_track_insert_key(position, index * 0.16, rig.to_local(hilt) - pose * guard)
			clip.rotation_track_insert_key(rotation, index * 0.16, pose.get_rotation_quaternion())
		var label := "Reconstructed%d" % slot
		assert(library.add_animation(label, clip) == OK)
		if slot in [21, 22]:
			clear_death_floor(player, rig, skin, label, position)
	player.stop()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, ART + "spectral-reconstruction-trial.scn", ResourceSaver.FLAG_COMPRESS) == OK)
	print("SPECTRAL FIT: ", groups.size(), " private preview clips / ", data.poses.size(), " fitted poses with silhouette roll")
	model.free()
	quit()

func point(xyz: Array) -> Vector3:
	return Vector3(xyz[0], xyz[1], xyz[2])

func clear_death_floor(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, label: String, track: int) -> void:
	var clip := player.get_animation(label)
	var corrections: Array[Vector3] = []
	var maximum := 0.0
	var samples := ceili(clip.length * 480.0)
	var up := rig.global_basis.inverse() * Vector3.UP
	player.play(label, 0.0)
	player.advance(0.0)
	for i in range(samples + 1):
		var time := clip.length * float(i) / samples
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var lift := maxf(0.0, 0.010 - gap)
		maximum = maxf(maximum, lift)
		corrections.append(clip.position_track_interpolate(track, time) + up * lift)
	player.stop()
	for key in range(clip.track_get_key_count(track) - 1, -1, -1):
		clip.track_remove_key(track, key)
	for i in range(samples + 1):
		clip.position_track_insert_key(track, clip.length * float(i) / samples, corrections[i])
	print(label, " floor lift maximum ", maximum)
