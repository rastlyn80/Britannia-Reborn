# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const FanUV := Rect2(.539, .854, .465, .145)
const RightFanBones := ["bip01 r hand", "bip01 r finger0", "bip01 r finger1"]
const Hue := preload("res://Presentation/HumanHue.gd")


static func capture(actor: Node3D, hue: int) -> Dictionary:
	var body := actor.model.find_child("Body", true, false) as MeshInstance3D
	var rig: Skeleton3D = actor.skeleton
	if body == null or body.skin == null or body.mesh.get_surface_count() != 1:
		return {}
	var active := body.get_active_material(0) as ShaderMaterial
	if active == null:
		return {}
	rig.force_update_all_bone_transforms()
	var source := body.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = source[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var bones: PackedInt32Array = source[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = source[Mesh.ARRAY_WEIGHTS]
	if points.is_empty() or normals.size() != points.size() or uvs.size() != points.size():
		return {}
	var stride := bones.size() / points.size()
	var matrices: Array[Transform3D] = []
	var normal_matrices: Array[Basis] = []
	var fan_bindings := PackedByteArray()
	for index in body.skin.get_bind_count():
		var bone := body.skin.get_bind_bone(index)
		if bone < 0:
			bone = rig.find_bone(body.skin.get_bind_name(index))
		if bone < 0:
			return {}
		var pose := rig.global_transform * rig.get_bone_global_pose(bone) * body.skin.get_bind_pose(index)
		matrices.append(pose)
		normal_matrices.append(pose.basis.inverse().transposed())
		fan_bindings.append(int(rig.get_bone_name(bone) in RightFanBones))
	var fan_points := PackedVector3Array()
	var fan_normals := PackedVector3Array()
	var fan_uvs := PackedVector2Array()
	for start in range(0, indices.size(), 3):
		var face := indices.slice(start, start + 3)
		if not is_fan_face(face, uvs, bones, weights, stride, fan_bindings):
			continue
		for vertex in face:
			var point := Vector3.ZERO
			var normal := Vector3.ZERO
			for influence in stride:
				var at := vertex * stride + influence
				var weight := weights[at]
				if weight > 0.0:
					var bind := bones[at]
					point += (matrices[bind] * points[vertex]) * weight
					normal += (normal_matrices[bind] * normals[vertex]) * weight
			fan_points.append(point)
			fan_normals.append(normal.normalized())
			fan_uvs.append(uvs[vertex])
	if fan_points.size() != 576:
		return {}
	var bounds := AABB(fan_points[0], Vector3.ZERO)
	for point: Vector3 in fan_points:
		bounds = bounds.expand(point)
	var centre := bounds.get_center()
	for index in fan_points.size():
		fan_points[index] -= centre
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = fan_points
	arrays[Mesh.ARRAY_NORMAL] = fan_normals
	arrays[Mesh.ARRAY_TEX_UV] = fan_uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := active.duplicate() as ShaderMaterial
	var palette: Texture2D = Hue.palette(hue)
	material.set_shader_parameter("hue_palette", palette)
	material.set_shader_parameter("use_hue", palette != null)
	material.set_shader_parameter("partial_hue", (hue & 0x8000) != 0)
	mesh.surface_set_material(0, material)
	return {"mesh": mesh, "centre": centre}


static func is_fan_face(face: PackedInt32Array, uvs: PackedVector2Array, bones: PackedInt32Array,
		weights: PackedFloat32Array, stride: int, fan_bindings: PackedByteArray) -> bool:
	for vertex in face:
		if not FanUV.has_point(uvs[vertex]):
			return false
		var owned := 0.0
		for influence in stride:
			var index := vertex * stride + influence
			owned += weights[index] * fan_bindings[bones[index]]
		if owned < .998:
			return false
	return true
