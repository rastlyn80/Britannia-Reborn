extends "res://../scripts/bake-ophidian-staff-gestures.gd"

const MAGE_INPUT := "res://../work/creatures/mul-motion-review/skeletal-mage-staff/"
const CLIP := "MageStaffCheck"
const BONE := "skeletal mage staff"
const Clearance := preload("res://../scripts/skeletal-mage-staff-clearance.gd")
const Grip := preload("res://Presentation/LichGrip.gd")
const CHAINS := [["bip01 r finger0", "bip01 r finger01"], ["bip01 r finger1", "bip01 r finger11"]]

func run() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(MAGE_INPUT + "staff-atlas.png"))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.12
	material.roughness = 0.82
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	var points := PackedVector3Array()
	var data: Array = JSON.parse_string(FileAccess.get_file_as_string(MAGE_INPUT + "staff-corners.json"))
	assert(data.size() == 54)
	var scale := Vector3(0.60, 0.45, 0.45)
	var alignment := Basis(Vector3.FORWARD, -PI / 2.0)
	for row: Array in data:
		var point := alignment * (Vector3(row[0], row[1], row[2]) * scale)
		var normal := alignment * (Vector3(row[3], row[4], row[5]) / scale).normalized()
		points.append(point)
		vertex(builder, point, normal, Vector2(row[6], row[7]))
	var mesh := builder.commit()
	var forms := {}
	for treatment in ["original", "rounded", "modern"]:
		var source := ART_DIR + "skeletons_skeleton_mage-%s.gltf" % treatment
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var body := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var grip := rig.find_bone("cp_grasp_rhand")
		var staff := attach_staff(model, rig, grip, mesh, material)
		rig.set_bone_name(staff, BONE)
		var prop := rig.find_child("OphidianMageStaff", false, false)
		prop.name = "SkeletonMageStaff"
		prop.set_meta("source_visual_prop", true)
		add_check(player, rig)
		var clearance := Clearance.new(body, rig)
		var fingers := measure_fingers(body, rig)
		for clip in player.get_animation_list():
			if clip != "RESET":
				fit_clip(player, rig, grip, staff, points, clearance, clip)
				if clip not in ["Death", "Death2"]:
					close_grip(player, rig, staff, fingers, clip)
		player.stop()
		var saved := PackedScene.new()
		assert(saved.pack(model) == OK)
		var output := ART_DIR + "skeletal-mage-staff-%s.scn" % treatment
		assert(ResourceSaver.save(saved, output, ResourceSaver.FLAG_COMPRESS) == OK)
		forms[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
		model.free()
	var scripts := {}
	for path: String in ["scripts/bake-skeletal-mage-staff.gd", "scripts/skeletal-mage-staff-clearance.gd",
			"scripts/bake-ophidian-staff-gestures.gd", "scripts/bake-skeleton-axe-trial.gd",
			"scripts/bake-troll-weapons-trial.gd", "scripts/ophidian-bardiche-clearance.gd",
			"Viewer/Presentation/LichGrip.gd"]:
		scripts[path] = FileAccess.get_sha256("res://../" + path)
	var inputs := {}
	for name in ["staff-corners.json", "staff-atlas.png"]:
		inputs[name] = FileAccess.get_sha256(MAGE_INPUT + name)
	var receipt := FileAccess.open(MAGE_INPUT + "bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"forms": forms, "scripts": scripts, "inputs": inputs}))
	receipt.close()
	quit()

func add_check(player: AnimationPlayer, rig: Skeleton3D) -> void:
	var motion := player.get_animation("Idle").duplicate(true) as Animation
	motion.length = 0.72
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		var first: Variant = motion.track_get_key_value(track, 0)
		clear_keys(motion, track)
		motion.track_insert_key(track, 0.0, first)
	var joint := rig.find_bone("bip01 head")
	assert(joint >= 0)
	var track := channel(motion, joint_path(player, rig, joint), Animation.TYPE_ROTATION_3D)
	clear_keys(motion, track)
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	var initial := rig.get_bone_pose_rotation(joint)
	var axis := (rig.global_basis.inverse() * Vector3.RIGHT).normalized()
	for sample in 91:
		var phase := float(sample) / 90.0
		var nod := smoothstep(0.20, 0.51, phase) * (1.0 - smoothstep(0.58, 0.89, phase))
		rig.set_bone_pose_rotation(joint, initial)
		rotate_joint(rig, joint, Quaternion(axis, 0.052 * nod))
		motion.rotation_track_insert_key(track, phase * motion.length, rig.get_bone_pose_rotation(joint))
	assert(player.get_animation_library("").add_animation(CLIP, motion) == OK)

func joint_path(player: AnimationPlayer, rig: Skeleton3D, joint: int) -> NodePath:
	return NodePath("%s:%s" % [player.get_node(player.root_node).get_path_to(rig), rig.get_bone_name(joint)])

func channel(motion: Animation, path: NodePath, type: Animation.TrackType) -> int:
	var track := motion.find_track(path, type)
	if track < 0:
		track = motion.add_track(type)
		motion.track_set_path(track, path)
	return track

func clear_keys(motion: Animation, track: int) -> void:
	for key in range(motion.track_get_key_count(track) - 1, -1, -1):
		motion.track_remove_key(track, key)

func fit_clip(player: AnimationPlayer, rig: Skeleton3D, grip: int, staff: int,
		points: PackedVector3Array, clearance: RefCounted, clip: String) -> void:
	var motion := player.get_animation(clip)
	var track := channel(motion, joint_path(player, rig, staff), Animation.TYPE_ROTATION_3D)
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var collapsing := clip in ["Death", "Death2"]
	var intervals := ceili(motion.length * (360.0 if collapsing else 240.0))
	var release_track := channel(motion, joint_path(player, rig, staff), Animation.TYPE_POSITION_3D)
	var previous := Basis.IDENTITY
	for sample in intervals + 1:
		var phase := float(sample) / intervals
		var time := phase * motion.length
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		var socket := rig.global_transform * rig.get_bone_global_pose(grip)
		var aim := staff_direction(rig, socket, "Death" if collapsing else clip, phase)
		var release := smoothstep(0.70, 0.86, phase) if clip == "Death" else 0.0
		# The native wrist swings around the torso late in the primary collapse.
		# Leave the staff beside that arc and carry its landing into the corpse.
		var landing := socket.origin.lerp(Vector3(1.17, 0.054, 0.35), release)
		motion.position_track_insert_key(release_track, time, socket.basis.inverse() * (landing - socket.origin))
		socket.origin = landing
		if clip == "Death":
			aim = aim.slerp(Vector3(0.02, 0.0, 1.0).normalized(), release)
		elif clip == "Death2":
			aim = Vector3(-0.60, 1.0, -0.60).normalized().slerp(aim, smoothstep(0.04, 0.18, phase))
		var pose := Transform3D(Basis(Quaternion(Vector3.UP, aim)).scaled_local(socket.basis.get_scale()), socket.origin)
		clearance.update_pose()
		pose = fit_staff(pose, socket, previous if sample > 0 else pose.basis, points, clearance, null, 0.006)
		previous = pose.basis
		motion.rotation_track_insert_key(track, time, staff_local_rotation(socket, pose.basis))

func measure_fingers(mesh: MeshInstance3D, rig: Skeleton3D) -> Array[Dictionary]:
	var fingers: Array[Dictionary] = []
	for pair: Array in CHAINS:
		var upper := rig.find_bone(pair[0])
		var lower := rig.find_bone(pair[1])
		assert(upper >= 0 and lower >= 0)
		var tip := 0.0
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var stride := weights.size() / vertices.size()
			for i in vertices.size():
				for slot in stride:
					var index := i * stride + slot
					if weights[index] <= 0.45:
						continue
					var bind := joints[index]
					var bone := mesh.skin.get_bind_bone(bind)
					if bone < 0:
						bone = rig.find_bone(mesh.skin.get_bind_name(bind))
					if bone == lower:
						tip = maxf(tip, (mesh.skin.get_bind_pose(bind) * vertices[i]).x)
		assert(tip > 0.001)
		fingers.append({"upper": upper, "lower": lower, "length": tip})
	return fingers

func close_grip(player: AnimationPlayer, rig: Skeleton3D, staff: int, fingers: Array[Dictionary], clip: String) -> void:
	var motion := player.get_animation(clip)
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var poses: Array[Dictionary] = []
	var intervals := ceili(motion.length * 90.0)
	for sample in intervals + 1:
		for chain in fingers:
			for joint: int in [chain.upper, chain.lower]:
				rig.set_bone_pose_rotation(joint, rig.get_bone_rest(joint).basis.get_rotation_quaternion())
		player.seek(motion.length * float(sample) / intervals, true)
		rig.force_update_all_bone_transforms()
		var shaft := rig.get_bone_global_pose(staff)
		var axis := shaft.basis.y.normalized()
		var rotations := {}
		for chain in fingers:
			var upper: int = chain.upper
			var lower: int = chain.lower
			var length := Vector3(chain.length, 0.0, 0.0)
			var a := rig.get_bone_global_pose(upper).origin
			var b := rig.get_bone_global_pose(lower).origin
			var tip := rig.get_bone_global_pose(lower) * length
			var radial := (a - shaft.origin).slide(axis).normalized()
			var target := shaft.origin + axis * clampf((tip - shaft.origin).dot(axis), -0.05, 0.05) - radial * 0.009
			Grip.aim(rig, upper, b, Grip.knee(a, b, tip, target))
			Grip.aim(rig, lower, rig.get_bone_global_pose(lower) * length, target)
			for joint in [upper, lower]:
				rotations[joint] = rig.get_bone_pose_rotation(joint)
		poses.append(rotations)
	for joint: int in poses[0]:
		var track := channel(motion, joint_path(player, rig, joint), Animation.TYPE_ROTATION_3D)
		clear_keys(motion, track)
		for sample in poses.size():
			motion.rotation_track_insert_key(track, motion.length * float(sample) / intervals, poses[sample][joint])
