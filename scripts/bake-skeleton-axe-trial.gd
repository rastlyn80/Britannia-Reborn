extends "res://../scripts/bake-troll-weapons-trial.gd"
## Body 56 keeps the plain Skeleton rig and uses the archived Skeleton Axe.

const AXE_INPUT := "res://../work/creatures/skeleton-axe/"
const SOURCE := "res://local-art/creatures/skeletons_skeleton-%s.gltf"
const OUTPUT := "res://local-art/creatures/skeleton-56-axe-trial-%s.scn"
const TIMES := [0.0, 0.12, 0.25, 0.40, 0.57, 0.72, 0.85]
const REACH := [0.0, 0.40, 0.90, 1.0, 0.88, 0.43, 0.0]

func run() -> void:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(AXE_INPUT + "corners.json"))
	assert(rows.size() == 198)
	var atlas := Image.load_from_file(AXE_INPUT + "atlas.png")
	assert(atlas != null and not atlas.is_empty())
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(atlas)
	material.roughness = 0.83
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	for row: Array in rows:
		vertex(builder, Vector3(row[0], row[1], row[2]), Vector3(row[3], row[4], row[5]), Vector2(row[6], row[7]))
	var mesh := builder.commit()
	for treatment in ["original", "rounded", "modern"]:
		if not bake_skeleton(treatment, mesh):
			quit(1)
			return
	quit()

func bake_skeleton(treatment: String, mesh: ArrayMesh) -> bool:
	var model := (load(SOURCE % treatment) as PackedScene).instantiate()
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var grip := rig.find_bone("cp_grasp_rhand")
	assert(grip >= 0)
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var socket := rig.global_transform * rig.get_bone_global_pose(grip)
	var fit := Basis(Quaternion(Vector3.UP, (socket.basis.inverse() * Vector3(0.0, 0.57, 0.82)).normalized()))
	var joint := rig.add_bone("skeleton axe")
	rig.set_bone_parent(joint, grip)
	rig.set_bone_rest(joint, Transform3D(fit, Vector3.ZERO))
	rig.reset_bone_pose(joint)
	var axe := MeshInstance3D.new()
	axe.name = "SkeletonAxe"
	axe.mesh = mesh
	var skin := Skin.new()
	skin.add_bind(joint, Transform3D.IDENTITY)
	axe.skin = skin
	axe.skeleton = NodePath("..")
	rig.add_child(axe)
	axe.owner = model
	add_reach(player, rig, grip, fit)
	if not player.has_animation("AxeReach"):
		model.free()
		return false
	player.stop()
	bake_death_grip(player, rig, joint, mesh, true)
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK and ResourceSaver.save(packed, OUTPUT % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
	print("SKELETON 56 AXE: ", treatment, ", 66 source triangles bound at the right grasp socket")
	model.free()
	return true

func add_reach(player: AnimationPlayer, rig: Skeleton3D, grip: int, fit: Basis) -> void:
	var idle := player.get_animation("Idle")
	var motion := idle.duplicate(true) as Animation
	motion.length = TIMES[-1]
	motion.loop_mode = Animation.LOOP_NONE
	var track_by_bone := {}
	for track in motion.get_track_count():
		var value: Variant = motion.track_get_key_value(track, 0)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		motion.track_insert_key(track, 0.0, value)
		var path := motion.track_get_path(track)
		if motion.track_get_type(track) == Animation.TYPE_ROTATION_3D and path.get_subname_count() == 1:
			track_by_bone[str(path.get_subname(0))] = track
	var right := (rig.global_basis.inverse() * Vector3.RIGHT).normalized()
	var names := ["bip01 spine", "bip01 spine1", "bip01 head", "bip01 r upperarm",
		"bip01 r forearm", "bip01 r hand", "bip01 l upperarm"]
	var arm: Array[int] = [rig.find_bone("bip01 r upperarm"), rig.find_bone("bip01 r forearm"),
		rig.find_bone("bip01 r hand")]
	var head := rig.find_bone("bip01 head")
	var base: Array[Quaternion] = []
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	for name: String in names:
		var bone := rig.find_bone(name)
		assert(bone >= 0)
		base.append(rig.get_bone_pose_rotation(bone))
		if not track_by_bone.has(name):
			track_by_bone[name] = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track_by_bone[name], NodePath("%s:%s" % [rig_path, name]))
	for phase in TIMES.size():
		for index in names.size():
			rig.set_bone_pose_rotation(rig.find_bone(names[index]), base[index])
		var reach: float = REACH[phase]
		var angles := [0.25, 0.12, -0.14, -0.67, -0.19, 0.0, 0.10]
		for index in names.size():
			var bone := rig.find_bone(names[index])
			if index != 5:
				rotate_joint(rig, bone, Quaternion(right, angles[index] * reach))
		var hand := arm[2]
		var head_y := rig.to_global(rig.get_bone_global_pose(head).origin).y
		var hand_y := rig.to_global(rig.get_bone_global_pose(hand).origin).y
		lift_hand(rig, arm, maxf(0.0, head_y - 0.19 - hand_y) * reach)
		rig.force_update_all_bone_transforms()
		var shaft := rig.get_bone_global_pose(grip).basis * fit.y
		var desired := Vector3(0.0, lerpf(0.57, -0.02, reach), 0.82).normalized()
		var axis := (rig.global_basis.inverse() * desired).normalized()
		rotate_joint(rig, hand, Quaternion(shaft.normalized(), axis))
		for name: String in names:
			motion.rotation_track_insert_key(track_by_bone[name], TIMES[phase], rig.get_bone_pose_rotation(rig.find_bone(name)))
	assert(player.get_animation_library("").add_animation("AxeReach", motion) == OK)

func rotate_joint(rig: Skeleton3D, bone: int, rotation: Quaternion) -> void:
	rig.force_update_all_bone_transforms()
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(rotation) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()
