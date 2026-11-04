extends SceneTree

const INPUT := "res://../work/creatures/late-client-inputs/troll-action-trial/"
const FORMS := {
	53: ["trolls_troll", "Axe"],
	55: ["trolls_troll_frost", "FrostClub"],
}
const JOINT := "troll weapon"

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func vertex(builder: SurfaceTool, position: Vector3, normal: Vector3, uv: Vector2) -> void:
	builder.set_normal(normal)
	builder.set_uv(uv)
	builder.set_bones(PackedInt32Array([0, 0, 0, 0]))
	builder.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
	builder.add_vertex(position)

func spikes(mesh: ArrayMesh) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = 0.0
	shape.bottom_radius = 0.066
	shape.height = 0.25
	shape.radial_segments = 5
	shape.rings = 0
	var data := shape.get_mesh_arrays()
	var positions: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("9ba8ab")
	material.metallic = 0.63
	material.roughness = 0.52
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	for i in 4:
		var angle := PI * (float(i) + 0.5) / 2.0
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var axis := (radial + Vector3.UP * 0.18).normalized()
		var basis := Basis(Quaternion(Vector3.UP, axis))
		var center := Vector3(0.01, 0.84, -0.02) + radial * 0.17 + axis * 0.125
		for index in indices:
			vertex(builder, center + basis * positions[index], basis * normals[index], Vector2.ZERO)
	builder.commit(mesh)

func floor_gap(pose: Transform3D, corners: PackedVector3Array) -> float:
	var gap := INF
	for vertex in corners:
		gap = minf(gap, (pose * vertex).y)
	return gap

func settle_weapon(pose: Transform3D, corners: PackedVector3Array) -> Transform3D:
	const MARGIN := 0.012
	var gap := floor_gap(pose, corners)
	if gap >= MARGIN:
		return pose
	var shaft := pose.basis.y.normalized()
	var flat := Vector3(shaft.x, 0.0, shaft.z).normalized()
	var best := pose
	var best_gap := gap
	if flat.length_squared() > 0.5:
		var flatten := Quaternion(shaft, flat)
		for i in range(1, 17):
			var candidate := pose
			candidate.basis = Basis(Quaternion.IDENTITY.slerp(flatten, float(i) / 16.0)) * pose.basis
			gap = floor_gap(candidate, corners)
			if gap > best_gap:
				best = candidate
				best_gap = gap
			if gap >= MARGIN:
				break
	# Thick heads can still reach below the grip even when the shaft is flat.
	best.origin.y += maxf(0.0, MARGIN - best_gap)
	return best

func aim_joint(rig: Skeleton3D, joint: int, child: int, target: Vector3) -> void:
	var pose := rig.get_bone_global_pose(joint)
	var from := (rig.get_bone_global_pose(child).origin - pose.origin).normalized()
	var to := (target - pose.origin).normalized()
	pose.basis = Basis(Quaternion(from, to)) * pose.basis
	rig.set_bone_global_pose(joint, pose)
	rig.force_update_all_bone_transforms()

func lift_hand(rig: Skeleton3D, arm: Array[int], amount: float) -> void:
	var a := rig.get_bone_global_pose(arm[0]).origin
	var b := rig.get_bone_global_pose(arm[1]).origin
	var hand := rig.get_bone_global_pose(arm[2])
	var target := hand.origin + rig.global_basis.inverse() * (Vector3.UP * amount)
	var upper := a.distance_to(b)
	var lower := b.distance_to(hand.origin)
	var direction := (target - a).normalized()
	var distance := clampf(a.distance_to(target), absf(upper - lower) + 0.0001, upper + lower - 0.0001)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var bend := b - a - direction * direction.dot(b - a)
	if bend.length_squared() < 0.000001:
		var side := rig.global_basis.inverse() * Vector3.LEFT
		bend = side - direction * direction.dot(side)
	var elbow := a + direction * along + bend.normalized() * sqrt(maxf(0.0, upper * upper - along * along))
	aim_joint(rig, arm[0], arm[1], elbow)
	aim_joint(rig, arm[1], arm[2], target)
	var pose := rig.get_bone_global_pose(arm[2])
	pose.basis = hand.basis
	rig.set_bone_global_pose(arm[2], pose)
	rig.force_update_all_bone_transforms()

func bake_death_grip(player: AnimationPlayer, rig: Skeleton3D, joint: int, mesh: ArrayMesh) -> void:
	var corners := PackedVector3Array()
	for surface in mesh.get_surface_count():
		corners.append_array(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
	var bind := rig.get_bone_rest(joint)
	var grip := rig.get_bone_parent(joint)
	var death := player.get_animation("Death")
	var samples: Array[Transform3D] = []
	var arm: Array[int] = []
	for name in ["bip01 r upperarm", "bip01 r forearm", "bip01 r hand"]:
		var index := rig.find_bone(name)
		assert(index >= 0)
		arm.append(index)
	var arm_samples: Array[Array] = []
	const POSES := 361
	player.play("Death", 0.0)
	player.advance(0.0)
	for i in POSES:
		player.seek(death.length * float(i) / (POSES - 1), true)
		rig.force_update_all_bone_transforms()
		var socket := rig.global_transform * rig.get_bone_global_pose(grip)
		var source := socket * bind
		var settled := settle_weapon(source, corners)
		var original_arm: Array[Quaternion] = []
		for bone in arm:
			original_arm.append(rig.get_bone_pose_rotation(bone))
		if settled.origin.y > source.origin.y + 0.00001:
			lift_hand(rig, arm, settled.origin.y - source.origin.y)
			socket = rig.global_transform * rig.get_bone_global_pose(grip)
		samples.append(socket.affine_inverse() * settled)
		var result: Array[Quaternion] = []
		for i_arm in arm.size():
			result.append(rig.get_bone_pose_rotation(arm[i_arm]))
			rig.set_bone_pose_rotation(arm[i_arm], original_arm[i_arm])
		arm_samples.append(result)
	player.stop()

	var animation_root := player.get_node(player.root_node)
	var rig_path := animation_root.get_path_to(rig)
	var target := NodePath("%s:%s" % [rig_path, JOINT])
	for index in arm.size():
		var channel := NodePath("%s:%s" % [rig_path, rig.get_bone_name(arm[index])])
		var track := death.find_track(channel, Animation.TYPE_ROTATION_3D)
		assert(track >= 0)
		for key in range(death.track_get_key_count(track) - 1, -1, -1):
			death.track_remove_key(track, key)
		for sample in POSES:
			var time := death.length * float(sample) / (POSES - 1)
			death.rotation_track_insert_key(track, time, arm_samples[sample][index])
	for name in player.get_animation_list():
		var animation := player.get_animation(name)
		var positions := animation.add_track(Animation.TYPE_POSITION_3D)
		var rotations := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(positions, target)
		animation.track_set_path(rotations, target)
		if name != "Death":
			animation.position_track_insert_key(positions, 0.0, bind.origin)
			animation.rotation_track_insert_key(rotations, 0.0, bind.basis.get_rotation_quaternion())
			continue
		for i in POSES:
			var time := animation.length * float(i) / (POSES - 1)
			var pose := samples[i]
			animation.position_track_insert_key(positions, time, pose.origin)
			animation.rotation_track_insert_key(rotations, time, pose.basis.orthonormalized().get_rotation_quaternion())

func run() -> void:
	var shapes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT + "weapon-sources.json"))
	var atlas := Image.load_from_file(INPUT + "weapon-atlas.png")
	assert(atlas != null and not atlas.is_empty())
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(atlas)
	material.roughness = 0.84
	for body in FORMS:
		for treatment in ["original", "rounded", "modern"]:
			bake(body, treatment, shapes, material)
	quit()

func bake(body: int, treatment: String, shapes: Dictionary, material: Material) -> void:
	var form: Array = FORMS[body]
	var suffix := "" if treatment == "modern" else "-" + treatment
	var path := "res://local-art/creatures/%s-slot11-trial%s.scn" % [form[0], suffix]
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var grip := rig.find_bone("cp_grasp_rhand")
	assert(grip >= 0)
	var joint := rig.add_bone(JOINT)
	rig.set_bone_parent(joint, grip)
	# The source socket is inside the palm. Seat the shaft at that anchor.
	var fit := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.10, 0.0))
	rig.set_bone_rest(joint, fit)
	rig.reset_bone_pose(joint)
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	for row: Array in shapes[form[1]]:
		vertex(builder, Vector3(row[0], row[1], row[2]), Vector3(row[3], row[4], row[5]), Vector2(row[6], row[7]))
	var weapon := MeshInstance3D.new()
	weapon.name = form[1]
	var mesh := builder.commit()
	if body == 55:
		spikes(mesh)
	weapon.mesh = mesh
	var skin := Skin.new()
	skin.add_bind(joint, Transform3D.IDENTITY)
	weapon.skin = skin
	weapon.skeleton = NodePath("..")
	rig.add_child(weapon)
	weapon.owner = model

	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	bake_death_grip(player, rig, joint, mesh)
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, "res://local-art/creatures/troll-%d-armed-trial%s.scn" % [body, suffix],
		ResourceSaver.FLAG_COMPRESS) == OK)
	print("Troll ", body, " uses source grip socket and ", mesh.get_surface_count(), " weapon surfaces")
	model.free()
