extends SceneTree

const SOURCE := "res://local-art/creatures/lizard_race_lizardman-modern.gltf"
const WEAPON_BONE := "lizardman weapon"
const HAND_BONE := "bip01 r hand"
const OUTPUT := "res://local-art/creatures/lizardman-pillage-trial.scn"

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func fit_weapon(rig: Skeleton3D, form: String, owner: Node) -> MeshInstance3D:
	var hand := rig.find_bone(HAND_BONE)
	assert(hand >= 0 and rig.find_bone(WEAPON_BONE) < 0)
	var bone := rig.add_bone(WEAPON_BONE)
	rig.set_bone_parent(bone, hand)
	var rotation := Vector3(PI / 2.0, 0.0, 0.0)
	var position := Vector3(0.11, 0.075, 0.0)
	if form == "Spear":
		rotation.x -= 0.80
		rotation.z = -0.30
		# Shift along the shaft to keep its centerline inside the same grip.
		position += Basis.from_euler(rotation).y * 0.25
	var bind := Transform3D(Basis.from_euler(rotation), position)
	rig.set_bone_rest(bone, bind)
	rig.reset_bone_pose(bone)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/lizardman-weapon-trial.json"))
	var image := Image.load_from_file("res://local-art/creatures/lizardman-weapon-trial.png")
	assert(image != null and not image.is_empty())
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.roughness = 0.8
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	for row: Array in data[form]:
		builder.set_normal(Vector3(row[3], row[4], row[5]))
		builder.set_uv(Vector2(row[6], row[7]))
		builder.set_bones(PackedInt32Array([0, 0, 0, 0]))
		builder.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		builder.add_vertex(Vector3(row[0], row[1], row[2]))
	var weapon := MeshInstance3D.new()
	weapon.name = form
	weapon.mesh = builder.commit()
	# One rigid influence keeps the visible frame and synchronous CPU corpse
	# bake on the same joint, including immediately after an animation seek.
	var skin := Skin.new()
	skin.add_bind(bone, Transform3D.IDENTITY)
	weapon.skin = skin
	weapon.skeleton = NodePath("..")
	rig.add_child(weapon)
	weapon.owner = owner
	return weapon

func bake_death_grip(player: AnimationPlayer, rig: Skeleton3D, weapon: MeshInstance3D) -> void:
	var hand_bone := rig.find_bone(HAND_BONE)
	var bind := rig.get_bone_rest(rig.find_bone(WEAPON_BONE))
	var animation_root := player.get_node(player.root_node)
	var target := NodePath("%s:%s" % [animation_root.get_path_to(rig), WEAPON_BONE])
	var vertices: PackedVector3Array = weapon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var death := player.get_animation("Death")
	var corrections: Array[Transform3D] = []
	const SAMPLES := 121
	player.play("Death")
	player.advance(0.0)
	for i in SAMPLES:
		player.seek(death.length * float(i) / (SAMPLES - 1), true)
		rig.force_update_all_bone_transforms()
		var hand := rig.global_transform * rig.get_bone_global_pose(hand_bone)
		var pose := hand * bind
		var min_y := INF
		for point in vertices:
			min_y = minf(min_y, (pose * point).y)
		if min_y < 0.06:
			var shaft := pose.basis.y.normalized()
			var horizontal := Vector3(shaft.x, 0, shaft.z).normalized()
			if horizontal.length_squared() > 0.5:
				var flat := Quaternion(shaft, horizontal)
				var amount := smoothstep(0.06, -0.12, min_y)
				pose.basis = Basis(Quaternion.IDENTITY.slerp(flat, amount)) * pose.basis
			min_y = INF
			for point in vertices:
				min_y = minf(min_y, (pose * point).y)
			pose.origin.y += maxf(0.0, 0.018 - min_y)
		corrections.append(hand.affine_inverse() * pose)
	player.stop()
	for name in player.get_animation_list():
		var clip := player.get_animation(name)
		var rotations := clip.add_track(Animation.TYPE_ROTATION_3D)
		var positions := clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(rotations, target)
		clip.track_set_path(positions, target)
		if name != "Death":
			clip.rotation_track_insert_key(rotations, 0.0, bind.basis.get_rotation_quaternion())
			clip.position_track_insert_key(positions, 0.0, bind.origin)
			continue
		for i in SAMPLES:
			var time := clip.length * float(i) / (SAMPLES - 1)
			var correction := corrections[i]
			clip.rotation_track_insert_key(rotations, time, correction.basis.orthonormalized().get_rotation_quaternion())
			clip.position_track_insert_key(positions, time, correction.origin)

func hold_grip(player: AnimationPlayer, rig: Skeleton3D) -> void:
	var walk := player.get_animation("Walk")
	var animation_root := player.get_node(player.root_node)
	for bone in ["bip01 r finger0", "bip01 r finger01", "bip01 r finger1", "bip01 r finger11"]:
		var path := NodePath("%s:%s" % [animation_root.get_path_to(rig), bone])
		var source_track := walk.find_track(path, Animation.TYPE_ROTATION_3D)
		assert(source_track >= 0)
		var closed := walk.track_get_key_value(source_track, 0) as Quaternion
		for name in player.get_animation_list():
			if name == "Death":
				continue
			var clip := player.get_animation(name)
			var track := clip.find_track(path, Animation.TYPE_ROTATION_3D)
			assert(track >= 0)
			for key in clip.track_get_key_count(track):
				clip.track_set_key_value(track, key, closed)

func run() -> void:
	var model := (load(SOURCE) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var library := player.get_animation_library("")
	var idle := library.get_animation("Idle")
	var motion := idle.duplicate(true) as Animation
	motion.length = 1.15
	motion.loop_mode = Animation.LOOP_NONE
	var tracks := {}
	for track in motion.get_track_count():
		var value: Variant = motion.track_get_key_value(track, 0)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		motion.track_insert_key(track, 0.0, value)
		var path := motion.track_get_path(track)
		if motion.track_get_type(track) == Animation.TYPE_ROTATION_3D and path.get_subname_count() == 1:
			tracks[str(path.get_subname(0))] = track
	var joint_angles := {"bip01 spine": 0.32, "bip01 spine1": 0.24, "bip01 head": -0.18}
	var axis := (rig.global_basis.inverse() * Vector3.RIGHT).normalized()
	for sample in [[0.0, 0.0], [0.29, 0.58], [0.57, 1.0], [0.79, 0.82], [1.15, 0.0]]:
		player.play("Idle")
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		for name: String in joint_angles:
			var bone := rig.find_bone(name)
			assert(bone >= 0 and tracks.has(name))
			var pose := rig.get_bone_global_pose(bone)
			pose.basis = Basis(Quaternion(axis, float(joint_angles[name]) * float(sample[1]))) * pose.basis
			rig.set_bone_global_pose(bone, pose)
			motion.rotation_track_insert_key(tracks[name], sample[0], rig.get_bone_pose_rotation(bone))
	library.add_animation("Pillage", motion)
	player.stop()
	var form := "Mace" if "mace" in OS.get_cmdline_user_args() else "Spear"
	hold_grip(player, rig)
	var weapon := fit_weapon(rig, form, model)
	bake_death_grip(player, rig, weapon)
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, OUTPUT.replace(".scn", "-" + form.to_lower() + ".scn"), ResourceSaver.FLAG_COMPRESS) == OK)
	print("LIZARDMAN TRIAL: authored legacy stoop on the original Idle rig")
	quit()
