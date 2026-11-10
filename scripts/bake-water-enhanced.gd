# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Output := "res://../work/creatures/native-form-audit/enhanced-source-gaps/amou/water-modern.scn"
const Arm := preload("res://Presentation/WaterElementalFidgets.gd")
const Actions := {23: "WaterEmerge", 28: "WaterAlert"}
const Joints := ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
	"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
	"clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]
# Scale is measured against the final silhouette, then the arms unfold.
const Formation := [
	Vector3(.17, .19, .17), Vector3(.39, .47, .39), Vector3(.60, .65, .61), Vector3(.73, .77, .74),
	Vector3(.98, .97, 1.0), Vector3(1.01, 1.0, 1.0), Vector3(1.0, 1.0, 1.0), Vector3.ONE,
]
const Right := [Vector3.ZERO, Vector3(-.09, .09, .10), Vector3(-.23, .23, .18),
	Vector3(-.19, .26, .14), Vector3(-.17, .25, .11)]
const Left := [Vector3.ZERO, Vector3(.02, .02, .06), Vector3(.10, .08, .12),
	Vector3(.24, .14, .17), Vector3(.23, .15, .18)]

func run() -> void:
	var row := Registry.entry(16)
	assert(row.kind == "water_elemental")
	var source := Registry.asset_path(row)
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var fluid := model.find_child("FluidBody", true, false) as MeshInstance3D
	assert(fluid != null)
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	tuck_arms(rig, 1.0)
	add_surge_shape(fluid, rig)
	player.stop()
	var morph_path := NodePath("%s:FormationSpire" % player.get_node(player.root_node).get_path_to(fluid))
	var reset := Animation.new()
	var reset_track := reset.add_track(Animation.TYPE_BLEND_SHAPE)
	reset.track_set_path(reset_track, morph_path)
	reset.blend_shape_track_insert_key(reset_track, 0.0, 0.0)
	assert(library.add_animation("RESET", reset) == OK)
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skins.append(Ground.skin_points(mesh, rig))
	for group: int in Actions:
		var clip := fit_grounded(player, rig, skins, .7 if group == 23 else .4, "root", Joints,
			pose_water.bind(group), .004)
		if group == 23:
			var path := NodePath("%s:root" % player.get_node(player.root_node).get_path_to(rig))
			var track := clip.find_track(path, Animation.TYPE_SCALE_3D)
			if track < 0:
				track = clip.add_track(Animation.TYPE_SCALE_3D)
				clip.track_set_path(track, path)
			for frame in 81:
				var phase := float(frame) / 80.0
				clip.scale_track_insert_key(track, phase * clip.length, sample(Formation, phase))
			var morph := clip.add_track(Animation.TYPE_BLEND_SHAPE)
			clip.track_set_path(morph, morph_path)
			for key: Vector2 in [Vector2(0, 1), Vector2(.10, 1), Vector2(.20, .80), Vector2(.30, .48),
					Vector2(.40, .14), Vector2(.50, 0), Vector2(.70, 0)]:
				clip.blend_shape_track_insert_key(morph, key.x, key.y)
		assert(library.add_animation(Actions[group], clip) == OK)
	Exact.check_earlier_keys(player, source)
	player.stop()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, Output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("WATER ENHANCED CANDIDATE: measured growth and alert with original keys preserved")
	quit()

func add_surge_shape(mesh: MeshInstance3D, rig: Skeleton3D) -> void:
	var base := mesh.mesh as ArrayMesh
	assert(base.get_surface_count() == 1 and base.get_blend_shape_count() == 0)
	var arrays := base.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL].duplicate()
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT].duplicate()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var stride := indices.size() / points.size()
	var matrices: Array[Transform3D] = []
	for bind in mesh.skin.get_bind_count():
		var bone := mesh.skin.get_bind_bone(bind)
		if bone < 0:
			bone = rig.find_bone(mesh.skin.get_bind_name(bind))
		assert(bone >= 0)
		matrices.append(rig.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
	for index in points.size():
		var basis := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
		var origin := Vector3.ZERO
		for slot in stride:
			var weight := weights[index * stride + slot]
			if weight == 0.0:
				continue
			var matrix := matrices[indices[index * stride + slot]]
			basis.x += matrix.basis.x * weight
			basis.y += matrix.basis.y * weight
			basis.z += matrix.basis.z * weight
			origin += matrix.origin * weight
		assert(absf(basis.determinant()) > .025)
		var pose := Transform3D(basis, origin)
		var p := pose * points[index]
		var height := clampf(p.y / 1.83, 0.0, 1.0)
		var radial := Vector2(p.x, p.z).normalized()
		var radius := .30 * pow(1.0 - height, 1.25) + .015
		var end_cap := smoothstep(0.0, .025, height) * (1.0 - smoothstep(.95, 1.0, height))
		points[index] = pose.affine_inverse() * Vector3(radial.x * radius * end_cap, p.y, radial.y * radius * end_cap)
		if not radial.is_zero_approx():
			normals[index] = (basis.transposed() * Vector3(radial.x, .18, radial.y)).normalized()
			var tangent := (basis.inverse() * Vector3(radial.y, 0.0, -radial.x)).normalized()
			tangents[index * 4] = tangent.x
			tangents[index * 4 + 1] = tangent.y
			tangents[index * 4 + 2] = tangent.z
	var shape := []
	shape.resize(Mesh.ARRAY_MAX)
	shape[Mesh.ARRAY_VERTEX] = points
	shape[Mesh.ARRAY_NORMAL] = normals
	shape[Mesh.ARRAY_TANGENT] = tangents
	var result := ArrayMesh.new()
	result.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	result.add_blend_shape("FormationSpire")
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [shape], {},
		base.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	result.surface_set_material(0, base.surface_get_material(0))
	mesh.mesh = result

func pose_water(rig: Skeleton3D, phase: float, group: int) -> void:
	if group == 23:
		tuck_arms(rig, 1.0 - smoothstep(.35, .72, phase))
		rig.set_bone_pose_scale(rig.find_bone("root"), sample(Formation, phase))
	else:
		var turn := smoothstep(.0, .75, phase)
		turn_world(rig, "spine_01", Vector3.UP, .10 * turn)
		turn_world(rig, "spine_03", Vector3.UP, .12 * turn)
		turn_world(rig, "Head", Vector3.UP, .16 * turn)
		turn_world(rig, "Head", Vector3.RIGHT, -.07 * turn)
		Arm.move_hand(rig, "r", sample(Right, phase))
		rig.force_update_all_bone_transforms()
		Arm.move_hand(rig, "l", sample(Left, phase))
	rig.force_update_all_bone_transforms()

func tuck_arms(rig: Skeleton3D, tuck: float) -> void:
	turn_world(rig, "spine_02", Vector3.RIGHT, -.15 * tuck)
	turn_world(rig, "spine_03", Vector3.RIGHT, -.23 * tuck)
	turn_world(rig, "Head", Vector3.RIGHT, .40 * tuck)
	Arm.move_hand(rig, "l", Vector3(-.19, -.15, -.01) * tuck)
	rig.force_update_all_bone_transforms()
	Arm.move_hand(rig, "r", Vector3(.20, -.13, .01) * tuck)
	rig.force_update_all_bone_transforms()

func sample(values: Array, phase: float) -> Vector3:
	var offset := phase * (values.size() - 1)
	var index := mini(floori(offset), values.size() - 2)
	var from: Vector3 = values[index]
	return from.lerp(values[index + 1], smoothstep(0.0, 1.0, offset - index))
