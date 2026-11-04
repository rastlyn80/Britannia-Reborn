extends SceneTree

const BASE := "res://local-art/creatures/khaldun_doom/"
const REVIEW := "res://../work/creatures/mul-motion-review/"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var importer := GLTFDocument.new()
	var state := GLTFState.new()
	var library := "--library" in OS.get_cmdline_user_args()
	var on_foot := "--on-foot" in OS.get_cmdline_user_args()
	var mounted := "--mounted" in OS.get_cmdline_user_args()
	var input := BASE + ("restless-soul-comparison-library.gltf" if library else "restless-soul-recovered-original-trial.gltf")
	var model: Node3D
	if on_foot:
		model = (load(BASE + "restless-soul-on-foot-review.scn") as PackedScene).instantiate()
	elif mounted:
		model = (load(BASE + "restless-soul-mounted-robe-review.scn") as PackedScene).instantiate()
	else:
		assert(importer.append_from_file(input, state) == OK)
		model = importer.generate_scene(state)
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert(mesh.mesh.get_surface_count() == 1 and rig.get_bone_count() == 40)
	var arrays := mesh.mesh.surface_get_arrays(0)
	var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var bind_ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var stride := int(float(weights.size()) / source.size())
	var compact := {}
	var unique: Array[int] = []
	var aliases := PackedInt32Array()
	for i in source.size():
		var key: Array = [source[i]]
		for slot in stride:
			key.append(bind_ids[i * stride + slot])
			key.append(weights[i * stride + slot])
		if not compact.has(key):
			compact[key] = unique.size()
			unique.append(i)
		aliases.append(compact[key])
	var faces := Array(indices)
	for i in faces.size():
		faces[i] = aliases[faces[i]]
	var bone_ids: Array[int] = []
	for i in mesh.skin.get_bind_count():
		var bone := mesh.skin.get_bind_bone(i)
		if bone < 0:
			bone = rig.find_bone(mesh.skin.get_bind_name(i))
		assert(bone >= 0)
		bone_ids.append(bone)
	var poses := {}
	player.deterministic = true
	for clip: String in player.get_animation_list():
		if clip == "RESET":
			continue
		var samples: Array = []
		player.stop()
		player.play(clip, 0.0)
		player.advance(0.0)
		for frame in 25:
			player.seek(player.current_animation_length * float(frame) / 24.0, true)
			rig.force_update_all_bone_transforms()
			var bind: Array[Transform3D] = []
			for i in bone_ids.size():
				bind.append(rig.get_bone_global_pose(bone_ids[i]) * mesh.skin.get_bind_pose(i))
			var points: Array = []
			for i in unique:
				var point := Vector3.ZERO
				for slot in stride:
					var j := i * stride + slot
					point += (bind[bind_ids[j]] * source[i]) * weights[j]
				point = rig.to_global(point)
				points.append([snappedf(point.x, 0.00001), snappedf(point.y, 0.00001), snappedf(point.z, 0.00001)])
			samples.append(points)
		poses[clip] = samples
		print("GHOST SKIN ", clip, " ", samples.size())
	var output := "ghost-library-poses.json" if library else "ghost-silhouette-poses.json"
	if on_foot:
		output = "ghost-on-foot-poses.json"
	if mounted:
		output = "ghost-mounted-poses.json"
	var report := FileAccess.open(REVIEW + output, FileAccess.WRITE)
	report.store_string(JSON.stringify({"indices": faces, "poses": poses}))
	report.close()
	model.free()
	quit()
