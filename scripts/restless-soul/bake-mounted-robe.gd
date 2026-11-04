extends "res://../scripts/restless-soul/bake-ghost-on-foot-preview.gd"

func run() -> void:
	var suffix := "-rounded" if "--rounded" in OS.get_cmdline_user_args() else ""
	var asset := ART + "restless-soul-mounted-robe" + suffix + "-review"
	var output := asset + ".scn"
	if "--reproduction" in OS.get_cmdline_user_args() or in_use(output):
		output = asset + "-reproduction.scn"
	var importer := GLTFDocument.new()
	var state := GLTFState.new()
	assert(importer.append_from_file(asset + ".gltf", state) == OK)
	var model := importer.generate_scene(state)
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var idle := player.get_animation("Horse_Idle")
	var clip := idle.duplicate(true) as Animation
	clip.length = 0.80
	clip.loop_mode = Animation.LOOP_NONE
	var affected := {}
	for track in clip.get_track_count():
		var path := clip.track_get_path(track)
		var name := str(path.get_concatenated_subnames())
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and name in [
				"bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 r clavicle",
				"bip01 r upperarm", "bip01 r forearm", "bip01 r hand"]:
			affected[track] = rig.find_bone(name)
		for key in range(clip.track_get_key_count(track) - 1, -1, -1):
			clip.track_remove_key(track, key)
	assert(affected.size() == 7)
	player.deterministic = true
	player.play("Horse_Idle", 0.0)
	player.advance(0.0)
	var fractions := [0.08, 0.31, 0.49, 0.70, 0.89]
	var overhead := [0.0, 0.85, 0.67, 0.20, 0.0]
	var forward := [0.0, 0.12, 0.61, 0.36, 0.0]
	for i in range(33):
		var phase := float(i) / 32.0
		var q := phase * 4.0
		var first := floori(q)
		var next := mini(4, first + 1)
		var progress := smoothstep(0.0, 1.0, q - first)
		var raise := lerpf(overhead[first], overhead[next], progress)
		var reach := lerpf(forward[first], forward[next], progress)
		rig.reset_bone_poses()
		var original_time := idle.length * lerpf(fractions[first], fractions[next], progress)
		player.seek(original_time, true)
		rig.force_update_all_bone_transforms()
		turn(rig, "bip01 spine1", Vector3.RIGHT, reach * 0.32)
		turn(rig, "bip01 spine2", Vector3.UP, raise * -0.20)
		turn(rig, "bip01 neck", Vector3.RIGHT, reach * -0.13)
		turn(rig, "bip01 r clavicle", Vector3.FORWARD, raise * 0.16)
		turn(rig, "bip01 r upperarm", Vector3.RIGHT, -raise * 0.58 + reach * 0.73)
		turn(rig, "bip01 r forearm", Vector3.UP, -raise * 0.57 + reach * 0.31)
		turn(rig, "bip01 r hand", Vector3.RIGHT, reach * 0.35)
		for track in clip.get_track_count():
			var value: Variant
			match clip.track_get_type(track):
				Animation.TYPE_POSITION_3D:
					value = idle.position_track_interpolate(track, original_time)
				Animation.TYPE_ROTATION_3D:
					value = rig.get_bone_pose_rotation(affected[track]) if affected.has(track) else idle.rotation_track_interpolate(track, original_time)
				Animation.TYPE_SCALE_3D:
					value = idle.scale_track_interpolate(track, original_time)
				_:
					assert(false, "Unexpected seated source track")
			clip.track_insert_key(track, phase * clip.length, value)
	assert(player.get_animation_library("").add_animation("GhostUrgeMount", clip) == OK)
	player.stop()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("MOUNTED GHOST: six original seated clips and one fitted spur gesture")
	quit()

func in_use(path: String) -> bool:
	const INDEX := "res://local-art/creatures/accepted-index.json"
	if not FileAccess.file_exists(INDEX):
		return false
	var active: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	for row: Dictionary in active.entries:
		if row.status == "validated" and path in row.get("mounted_assets", {}).values():
			return true
	return false
