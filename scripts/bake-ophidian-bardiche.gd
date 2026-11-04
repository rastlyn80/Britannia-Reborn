extends "res://../scripts/bake-skeleton-axe-trial.gd"

const INPUT_DIR := "res://../work/creatures/ophidian-bardiche/"
const ART := "res://local-art/creatures/"
const BARDICHE := "ophidian bardiche"
const GRIP_DEPTH := 0.18
const SOURCE_MOTIONS := ["Idle", "Walk", "Run", "Attack", "Hit", "Fidget", "Death"]
const Clearance := preload("res://../scripts/ophidian-bardiche-clearance.gd")
const FIT_AXES := [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK,
	Vector3.UP, Vector3.DOWN, Vector3(1, 0, 1), Vector3(-1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, -1)]

func _initialize() -> void:
	create_timer(75.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var corners: Array = JSON.parse_string(FileAccess.get_file_as_string(INPUT_DIR + "corners.json"))
	assert(corners.size() == 162)
	var material := StandardMaterial3D.new()
	var atlas := Image.load_from_file(INPUT_DIR + "atlas.png")
	assert(atlas != null and not atlas.is_empty())
	material.albedo_texture = ImageTexture.create_from_image(atlas)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.12
	material.roughness = 0.80
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	var points := PackedVector3Array()
	for row: Array in corners:
		var position := Vector3(row[0], row[1] + GRIP_DEPTH, row[2])
		points.append(position)
		vertex(builder, position, Vector3(row[3], row[4], row[5]), Vector2(row[6], row[7]))
	var mesh := builder.commit()
	var treatments := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source := ART + "ophidians_ophidian_warrior-" + treatment + ".gltf"
		var output := ART + "ophidian-86-bardiche-" + treatment + ".scn"
		bake_ophidian(source, output, mesh, points, material)
		treatments[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
	var receipt := FileAccess.open(INPUT_DIR + "bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({
		"treatments": treatments, "recipe": FileAccess.get_sha256(get_script().resource_path),
		"corners": FileAccess.get_sha256(INPUT_DIR + "corners.json"), "atlas": FileAccess.get_sha256(INPUT_DIR + "atlas.png"),
		"arm": FileAccess.get_sha256("res://../scripts/bake-skeleton-axe-trial.gd"),
		"weapon": FileAccess.get_sha256("res://../scripts/bake-troll-weapons-trial.gd"),
		"clearance": FileAccess.get_sha256("res://../scripts/ophidian-bardiche-clearance.gd"),
	}))
	receipt.close()
	quit()

func bake_ophidian(source: String, output: String, mesh: ArrayMesh, points: PackedVector3Array, material: Material) -> void:
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var clearance := Clearance.new(model.find_children("*", "MeshInstance3D", true, false)[0], rig)
	var grip := rig.find_bone("cp_grasp_rhand")
	assert(grip >= 0)
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var socket := rig.global_transform * rig.get_bone_global_pose(grip)
	var aim := Vector3(-0.18, 0.80, 0.55).normalized()
	var fit := Basis(Quaternion(Vector3.UP, (socket.basis.inverse() * aim).normalized()))
	var joint := rig.add_bone(BARDICHE)
	rig.set_bone_parent(joint, grip)
	rig.set_bone_rest(joint, Transform3D(fit, Vector3.ZERO))
	rig.reset_bone_pose(joint)
	var prop := MeshInstance3D.new()
	prop.name = "OphidianBardiche"
	prop.mesh = mesh
	prop.material_override = material
	var skin := Skin.new()
	skin.add_bind(joint, Transform3D.IDENTITY)
	prop.skin = skin
	prop.skeleton = NodePath("..")
	rig.add_child(prop)
	prop.owner = model
	add_dip(player, rig, grip, joint)
	player.stop()
	for clip: String in SOURCE_MOTIONS + ["BardicheDip"]:
		fit_clip(player, rig, grip, joint, points, clearance, clip)
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("OPHIDIAN 86: 54 source triangles on the original right grasp in ", output.get_file())

func add_dip(player: AnimationPlayer, rig: Skeleton3D, grip: int, weapon: int) -> void:
	var idle := player.get_animation("Idle")
	var motion := idle.duplicate(true) as Animation
	motion.length = 1.05
	motion.loop_mode = Animation.LOOP_NONE
	var names := ["bip01 spine", "bip01 spine1", "bip01 head", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
		"bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3", "bip01 tail4", "ophidian bardiche"]
	var tracks: Array[int] = []
	var idle_rotations: Array[Quaternion] = []
	var path := player.get_node(player.root_node).get_path_to(rig)
	for track in motion.get_track_count():
		var value: Variant = motion.track_get_key_value(track, 0)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		motion.track_insert_key(track, 0.0, value)
	for name: String in names:
		var node := NodePath("%s:%s" % [path, name])
		var track := motion.find_track(node, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, node)
		tracks.append(track)
		idle_rotations.append(rig.get_bone_pose_rotation(rig.find_bone(name)))
	var arm: Array[int] = [rig.find_bone(names[3]), rig.find_bone(names[4]), rig.find_bone(names[5])]
	var x := (rig.global_basis.inverse() * Vector3.RIGHT).normalized()
	var y := (rig.global_basis.inverse() * Vector3.UP).normalized()
	var saved := rig.get_bone_rest(weapon)
	for sample in 127:
		var phase := float(sample) / 126.0
		for i in names.size():
			rig.set_bone_pose_rotation(rig.find_bone(names[i]), idle_rotations[i])
		rig.force_update_all_bone_transforms()
		var raise := smoothstep(0.0, 0.18, phase) * (1.0 - smoothstep(0.78, 1.0, phase))
		var lean := smoothstep(0.10, 0.38, phase) * (1.0 - smoothstep(0.49, 0.85, phase))
		for i in range(3):
			var angles := [0.20, 0.25, -0.16]
			rotate_joint(rig, rig.find_bone(names[i]), Quaternion(x, angles[i] * lean))
		for i in range(6, 11):
			rotate_joint(rig, rig.find_bone(names[i]), Quaternion(y, sin(float(i - 6) * 0.67 + phase * PI) * 0.14 * lean))
		if raise > 0.0:
			lift_hand(rig, arm, 0.57 * raise)
		var socket := rig.global_transform * rig.get_bone_global_pose(grip)
		var reference := (socket.basis * saved.basis.y).normalized()
		var direction := reference.slerp(Vector3(-0.22, 0.91, 0.35).normalized(), raise)
		var pose := Basis(Quaternion(Vector3.UP, (socket.basis.inverse() * direction).normalized()))
		pose = pose * Basis(Quaternion(Vector3.UP, -0.95 * raise))
		rig.set_bone_pose_rotation(weapon, pose.get_rotation_quaternion())
		for i in names.size():
			motion.rotation_track_insert_key(tracks[i], phase * motion.length, rig.get_bone_pose_rotation(rig.find_bone(names[i])))
	assert(player.get_animation_library("").add_animation("BardicheDip", motion) == OK)

func fit_clip(player: AnimationPlayer, rig: Skeleton3D, grip: int, joint: int, points: PackedVector3Array, clearance: RefCounted, label: String) -> void:
	var animation := player.get_animation(label)
	var path := NodePath("%s:%s" % [player.get_node(player.root_node).get_path_to(rig), BARDICHE])
	var track := animation.find_track(path, Animation.TYPE_ROTATION_3D)
	var rest := rig.get_bone_rest(joint)
	var samples: Array[Quaternion] = []
	var intervals := ceili(animation.length * (240.0 if label == "Hit" else 120.0))
	var margin := 0.05 if label == "Hit" else 0.039
	var floor_margin := 0.012 if label == "Hit" else 0.008
	var minimum := INF
	var unresolved := 0
	player.play(label, 0.0)
	player.advance(0.0)
	for i in intervals + 1:
		var time := animation.length * float(i) / intervals
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		var socket := rig.global_transform * rig.get_bone_global_pose(grip)
		var desired := Basis(animation.rotation_track_interpolate(track, time)) if track >= 0 else rest.basis
		var pose := socket * Transform3D(desired, Vector3.ZERO)
		if label == "Run":
			# The source wrist turns sharply in the run. Carry the blade out to the side.
			var carry := Basis(Vector3.UP, deg_to_rad(280.0)) * Basis(Vector3.RIGHT, deg_to_rad(60.0))
			pose.basis = carry.scaled_local(socket.basis.get_scale())
		var fit := settle_weapon(pose, points, floor_margin, true)
		# Keep the shaft through the grasp. Only retain the solver's rotation.
		fit.origin = pose.origin
		clearance.update_pose()
		var previous := socket.basis * Basis(samples.back()) if not samples.is_empty() else fit.basis
		if label != "Run":
			fit = fit_body(fit, previous, points, clearance, margin, floor_margin)
		if clearance.intersects(fit):
			unresolved += 1
		minimum = minf(minimum, floor_gap(fit, points))
		samples.append((socket.basis.inverse() * fit.basis).orthonormalized().get_rotation_quaternion())
	player.stop()
	if track < 0:
		track = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, path)
	else:
		for i in range(animation.track_get_key_count(track) - 1, -1, -1):
			animation.track_remove_key(track, i)
	for i in samples.size():
		animation.rotation_track_insert_key(track, animation.length * float(i) / intervals, samples[i])
	print(label, " fitted bardiche minimum floor / centerline conflicts: ", [minimum, unresolved])

func fit_body(desired: Transform3D, previous: Basis, points: PackedVector3Array, clearance: RefCounted,
		margin: float, floor_margin: float) -> Transform3D:
	var previous_rotation := previous.orthonormalized().get_rotation_quaternion()
	var wanted_rotation := desired.basis.orthonormalized().get_rotation_quaternion()
	var blended := desired
	blended.basis = Basis(previous_rotation.slerp(wanted_rotation, 0.17)).scaled_local(desired.basis.get_scale())
	if floor_gap(blended, points) >= floor_margin and not clearance.intersects(blended, margin):
		return blended
	for degrees in [3.0, 6.0, 10.0, 16.0, 24.0, 36.0, 52.0, 72.0, 95.0]:
		var best := desired
		var best_angle := INF
		for axis: Vector3 in FIT_AXES:
			var pose := blended
			pose.basis = Basis(Quaternion(axis.normalized(), deg_to_rad(degrees))) * blended.basis
			if floor_gap(pose, points) < floor_margin or clearance.intersects(pose, margin):
				continue
			var rotation := pose.basis.orthonormalized().get_rotation_quaternion()
			var score := rotation.angle_to(wanted_rotation)
			if score < best_angle:
				best_angle = score
				best = pose
		if is_finite(best_angle):
			return best
	return desired
