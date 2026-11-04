extends "res://../scripts/bake-skeleton-axe-trial.gd"

const INPUT_DIR := "res://../work/creatures/mul-motion-review/bone-knight-props/"
const ART_DIR := "res://local-art/creatures/"
const IDENTITIES := {57: "skeletons_skeleton", 75: "cyclops_cyclops"}
const BONES := ["bip01 spine", "bip01 spine1", "bip01 head",
	"bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand",
	"bip01 r thigh", "bip01 r calf", "bip01 r foot",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot"]
const BladeClearance := preload("res://../scripts/bone-knight-cyclops-clearance.gd")

func run() -> void:
	var meshes := {
		"Scimitar": prop_mesh("scimitar", Basis(Vector3.DOWN, Vector3.RIGHT, Vector3.BACK), 0.49, Vector3.ZERO),
		"WoodenShield": prop_mesh("wooden_shield", Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), 1.0, Vector3(-0.098, 0.04, 0.205)),
		"CyclopsMallet": prop_mesh("mallet", Basis.IDENTITY, 1.30, Vector3.ZERO),
	}
	shield_grip(meshes.WoodenShield)
	var mallet := meshes.CyclopsMallet as ArrayMesh
	cylinder(mallet, 0.195, 0.54, Vector3(0.033, 0.66, -0.07), Color("51321f"), 0.0)
	for end: float in [-0.24, 0.24]:
		cylinder(mallet, 0.202, 0.057, Vector3(0.033, 0.66, -0.07 + end), Color("a77a35"), 0.67)
	var forms := {}
	for body: int in IDENTITIES:
		var variants := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var source := ART_DIR + str(IDENTITIES[body]) + "-" + treatment + ".gltf"
			var model := (load(source) as PackedScene).instantiate()
			root.add_child(model)
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var skin := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var clearance := BladeClearance.new(skin, rig)
			var names := ["Scimitar", "WoodenShield"] if body == 57 else ["CyclopsMallet"]
			var props: Array[Dictionary] = []
			for name: String in names:
				props.append(attach(model, rig, name, meshes[name], "l" if name == "WoodenShield" else "r"))
			var label := "KnightDip" if body == 57 else "MalletDip"
			add_dip(player, rig, label, body == 75)
			for clip in player.get_animation_list():
				if clip != "RESET":
					fit_clip(player, rig, clip, props, clearance)
			player.stop()
			var scene := PackedScene.new()
			assert(scene.pack(model) == OK)
			var output := ART_DIR + "bone-cyclops-%d-%s.scn" % [body, treatment]
			assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
			variants[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
			model.free()
		forms[str(body)] = variants
	var receipt := FileAccess.open(INPUT_DIR + "bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({
		"recipe": FileAccess.get_sha256(get_script().resource_path),
		"arm": FileAccess.get_sha256("res://../scripts/bake-skeleton-axe-trial.gd"),
		"weapon": FileAccess.get_sha256("res://../scripts/bake-troll-weapons-trial.gd"),
		"clearance": FileAccess.get_sha256("res://../scripts/bone-knight-cyclops-clearance.gd"),
		"skin": FileAccess.get_sha256("res://../scripts/ophidian-bardiche-clearance.gd"),
		"inputs": FileAccess.get_sha256(INPUT_DIR + "bake-inputs.json"),
		"forms": forms,
	}))
	receipt.close()
	quit()

func prop_mesh(kind: String, alignment: Basis, scale: float, offset: Vector3) -> ArrayMesh:
	var data: Array = JSON.parse_string(FileAccess.get_file_as_string(INPUT_DIR + kind + "-corners.json"))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(INPUT_DIR + kind + "-atlas.png"))
	material.albedo_color = Color("765342") if kind == "mallet" else Color.WHITE
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.12
	material.roughness = 0.83
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	for row: Array in data:
		var point := Vector3(row[0], row[1], row[2])
		var normal := Vector3(row[3], row[4], row[5])
		if kind == "mallet" and point.y < 0.0:
			# Keep the donor's hand and head spans. Shorten the butt that
			# otherwise strikes the thigh and face during source motions.
			point.y *= 0.27
			normal.y /= 0.27
		vertex(builder, alignment * point * scale + offset, alignment * normal.normalized(),
			Vector2(row[6], row[7]))
	return builder.commit()

func cylinder(mesh: ArrayMesh, radius: float, height: float, center: Vector3, tint: Color, metallic: float) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 16
	shape.rings = 0
	var data := shape.get_mesh_arrays()
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = metallic
	material.roughness = 0.63
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	var axis := Basis(Vector3.RIGHT, PI * 0.5)
	for i: int in data[Mesh.ARRAY_INDEX]:
		vertex(builder, center + axis * data[Mesh.ARRAY_VERTEX][i], axis * data[Mesh.ARRAY_NORMAL][i], data[Mesh.ARRAY_TEX_UV][i])
	builder.commit(mesh)

func shield_grip(mesh: ArrayMesh) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("433025")
	material.roughness = 0.88
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	var rails := [
		[Vector3(-0.095, 0.0, 0.132), Vector3(0.044, 0.048, 0.263)],
		[Vector3(0.095, 0.0, 0.132), Vector3(0.044, 0.048, 0.263)],
		[Vector3.ZERO, Vector3(0.19, 0.047, 0.049)],
	]
	for rail: Array in rails:
		var shape := BoxMesh.new()
		shape.size = rail[1]
		var data := shape.get_mesh_arrays()
		for i: int in data[Mesh.ARRAY_INDEX]:
			vertex(builder, rail[0] + data[Mesh.ARRAY_VERTEX][i], data[Mesh.ARRAY_NORMAL][i], data[Mesh.ARRAY_TEX_UV][i])
	builder.commit(mesh)

func attach(model: Node3D, rig: Skeleton3D, label: String, mesh: ArrayMesh, side: String) -> Dictionary:
	var grip := rig.find_bone("cp_grasp_%shand" % side)
	assert(grip >= 0)
	var joint := rig.add_bone(label.to_lower())
	rig.set_bone_parent(joint, grip)
	var prop := MeshInstance3D.new()
	prop.name = label
	prop.mesh = mesh
	prop.set_meta("source_visual_prop", true)
	prop.skin = Skin.new()
	prop.skin.add_bind(joint, Transform3D.IDENTITY)
	prop.skeleton = NodePath("..")
	rig.add_child(prop)
	prop.owner = model
	var points := PackedVector3Array()
	for i in mesh.get_surface_count():
		points.append_array(mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX])
	return {"label": label, "grip": grip, "bone": joint, "points": points}

func add_dip(player: AnimationPlayer, rig: Skeleton3D, label: String, giant: bool) -> void:
	var motion := player.get_animation("Idle").duplicate(true) as Animation
	motion.length = 0.88
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		var first: Variant = motion.track_get_key_value(track, 0)
		for i in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, i)
		motion.track_insert_key(track, 0.0, first)
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var path := player.get_node(player.root_node).get_path_to(rig)
	var inverse := rig.global_basis.inverse()
	var right := (inverse * Vector3.RIGHT).normalized()
	var forward := (inverse * Vector3.BACK).normalized()
	var joints: Array[int] = []
	var tracks: Array[int] = []
	var poses: Array[Quaternion] = []
	for name: String in BONES:
		var joint := rig.find_bone(name)
		assert(joint >= 0)
		joints.append(joint)
		poses.append(rig.get_bone_pose_rotation(joint))
		tracks.append(channel(motion, NodePath("%s:%s" % [path, name]), Animation.TYPE_ROTATION_3D))
	var pelvis := rig.find_bone("bip01 pelvis")
	var pelvis_position := rig.get_bone_pose_position(pelvis)
	var hips_down := rig.get_bone_global_pose(rig.get_bone_parent(pelvis)).basis.inverse() * inverse * Vector3.DOWN
	var pelvis_track := channel(motion, NodePath("%s:bip01 pelvis" % path), Animation.TYPE_POSITION_3D)
	var right_foot := rig.get_bone_global_pose(joints[11])
	var left_foot := rig.get_bone_global_pose(joints[14])
	var left_arm: Array[int] = [joints[6], joints[7], joints[8]]
	for sample in 121:
		var phase := float(sample) / 120.0
		var t := motion.length * phase
		var dip := smoothstep(0.02, 0.41, phase) * (1.0 - smoothstep(0.58, 0.99, phase))
		for i in joints.size():
			rig.set_bone_pose_rotation(joints[i], poses[i])
		var hip := pelvis_position + hips_down * dip * (0.19 if giant else 0.080)
		rig.set_bone_pose_position(pelvis, hip)
		motion.position_track_insert_key(pelvis_track, t, hip)
		rig.force_update_all_bone_transforms()
		if dip > 0.00001:
			rotate_joint(rig, joints[0], Quaternion(right, dip * (0.22 if giant else 0.16)))
			rotate_joint(rig, joints[1], Quaternion(right, dip * 0.13))
			rotate_joint(rig, joints[2], Quaternion(right, -dip * 0.09))
			rotate_joint(rig, joints[3], Quaternion(forward, -dip * (0.34 if giant else 0.49)))
			rotate_joint(rig, joints[3], Quaternion(right, -dip * 0.30))
			rotate_joint(rig, joints[4], Quaternion(right, -dip * 0.14))
			if giant:
				lift_hand(rig, left_arm, dip * 0.48)
			else:
				rotate_joint(rig, joints[6], Quaternion(right, -dip * 0.17))
				rotate_joint(rig, joints[6], Quaternion(forward, dip * 0.14))
			# Both thighs descend from the spine joint in these source rigs.
			plant(rig, joints[9], joints[10], joints[11], right_foot, forward)
			plant(rig, joints[12], joints[13], joints[14], left_foot, forward)
		for i in joints.size():
			motion.rotation_track_insert_key(tracks[i], t, rig.get_bone_pose_rotation(joints[i]))
	assert(player.get_animation_library("").add_animation(label, motion) == OK)

func channel(motion: Animation, path: NodePath, type: int) -> int:
	var track := motion.find_track(path, type)
	if track < 0:
		track = motion.add_track(type)
		motion.track_set_path(track, path)
	return track

func plant(rig: Skeleton3D, hip: int, knee: int, foot: int, target: Transform3D, forward: Vector3) -> void:
	var a := rig.get_bone_global_pose(hip).origin
	var upper := a.distance_to(rig.get_bone_global_pose(knee).origin)
	var lower := rig.get_bone_global_pose(knee).origin.distance_to(rig.get_bone_global_pose(foot).origin)
	var direction := (target.origin - a).normalized()
	var reach := clampf(a.distance_to(target.origin), absf(upper - lower) + 0.0001, upper + lower - 0.0001)
	var along := (upper * upper - lower * lower + reach * reach) / (2.0 * reach)
	var pole := (forward - direction * direction.dot(forward)).normalized()
	var bend := sqrt(maxf(0.0, upper * upper - along * along))
	aim_joint(rig, hip, knee, a + direction * along + pole * bend)
	aim_joint(rig, knee, foot, target.origin)
	var pose := rig.get_bone_global_pose(foot)
	pose.basis = target.basis
	rig.set_bone_global_pose(foot, pose)

func fit_clip(player: AnimationPlayer, rig: Skeleton3D, clip: String,
		props: Array[Dictionary], clearance: RefCounted) -> void:
	var motion := player.get_animation(clip)
	var path := player.get_node(player.root_node).get_path_to(rig)
	var tracks: Array[int] = []
	var drops: Array[int] = []
	for prop in props:
		var prop_path := NodePath("%s:%s" % [path, rig.get_bone_name(prop.bone)])
		tracks.append(channel(motion, prop_path, Animation.TYPE_ROTATION_3D))
		var releases: bool = (prop.label == "CyclopsMallet" and clip == "Death") \
			or (prop.label == "WoodenShield" and clip == "Death2")
		drops.append(channel(motion, prop_path, Animation.TYPE_POSITION_3D) if releases else -1)
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var rate := 240.0
	if clip in ["Death", "Death2", "Run", "Walk"]:
		rate = 360.0
	var intervals := ceili(motion.length * rate)
	var floors := {}
	var collisions := {}
	var headings := {}
	for sample in intervals + 1:
		var phase := float(sample) / intervals
		var time := phase * motion.length
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		clearance.update_pose()
		for i in props.size():
			var prop := props[i]
			var socket := rig.global_transform * rig.get_bone_global_pose(prop.grip)
			var label: String = prop.label
			if drops[i] >= 0:
				var away := Vector3(-0.22, 0.115, 0.075) * smoothstep(0.69, 0.98, phase)
				if label == "WoodenShield":
					# The alternate fall drops the shield on the outside of
					# the forearm when the wrist reaches the ground.
					away = Vector3(0.29, 0.095, 0.12) * smoothstep(0.49, 0.72, phase)
				motion.position_track_insert_key(drops[i], time, socket.basis.inverse() * away)
				socket.origin += away
			var goal := orientation(label, clip, phase)
			var previous: Basis = headings.get(label, goal)
			var result: Dictionary = clearance.fit_prop(socket, label, clip, phase, goal, previous, prop.points)
			headings[label] = result.heading
			floors[label] = minf(floors.get(label, INF), result.floor)
			collisions[label] = int(collisions.get(label, 0)) + int(result.crossed)
			motion.rotation_track_insert_key(tracks[i], time, result.rotation)
	print(clip, " prop floors / sampled crossings ", floors, " / ", collisions)

func orientation(label: String, clip: String, phase: float) -> Basis:
	var dip := smoothstep(0.02, 0.41, phase) * (1.0 - smoothstep(0.58, 0.99, phase))
	if label == "WoodenShield":
		var pitch := -0.08
		var yaw := -0.24
		if clip in ["Run", "Walk"]:
			yaw = 0.65
		if clip in ["Death", "Death2"]:
			var rest := smoothstep(0.50, 0.80, phase)
			pitch = lerpf(pitch, -PI * 0.5, rest)
			yaw = lerpf(yaw, 0.65, rest)
		return Basis(Vector3.UP, yaw).rotated(Vector3.RIGHT, pitch)
	var shaft := Vector3(-0.32, 0.41, 0.86).normalized()
	if label == "CyclopsMallet":
		shaft = Vector3(-0.55, 0.52, 0.72).normalized()
		if clip in ["Run", "Walk"]:
			var passing_hip := smoothstep(0.63, 0.74, phase) * (1.0 - smoothstep(0.82, 0.91, phase))
			shaft = shaft.slerp(Vector3(-0.20, 0.83, 0.50).normalized(), passing_hip)
	if clip == "KnightDip":
		shaft = shaft.slerp(Vector3(-0.83, -0.15, 0.58).normalized(), dip)
	elif clip == "MalletDip":
		shaft = shaft.slerp(Vector3(-0.86, -0.31, 0.40).normalized(), dip)
	elif clip == "Attack":
		shaft = shaft.slerp(Vector3(-0.29, 0.91, 0.30).normalized(), sin(phase * PI) * 0.90)
	elif clip == "Death":
		shaft = shaft.slerp(Vector3(-0.90, 0.02, 0.45).normalized(), smoothstep(0.1, 0.75, phase))
		if label == "CyclopsMallet":
			var pass_face := smoothstep(0.01, 0.08, phase) * (1.0 - smoothstep(0.17, 0.29, phase))
			shaft = shaft.slerp(Vector3(-0.80, -0.33, 0.55).normalized(), pass_face)
			shaft = shaft.slerp(Vector3(-0.87, 0.39, 0.30).normalized(), smoothstep(0.68, 0.98, phase))
	return Basis(Quaternion(Vector3.UP, shaft))
