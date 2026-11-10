# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Reshape the existing wind body into a narrow torso over a flared dust skirt.


static func fit(body: MeshInstance3D, rig: Skeleton3D) -> void:
	var original := body.mesh
	var arrays := original.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var regions: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var weights: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	for index in points.size():
		var point := points[index]
		if regions[index].r > .5:
			var t := clampf((point.y - .035) / 1.05, 0.0, 1.0)
			var direction := Vector2(point.x, point.z).normalized()
			var angle := direction.angle()
			var ruffle := .055 * sin(9.0 * angle + t * 7.0) + .033 * sin(15.0 * angle - t * 12.0)
			var radius := lerpf(.57, .24, pow(t, .56)) + ruffle * (1.0 - t)
			points[index] = Vector3(direction.x * radius, point.y, direction.y * radius + .08 * t)
			normals[index] = Vector3(direction.x, .28 + .30 * (1.0 - t), direction.y).normalized()
			continue
		var joint := weights[index * 4]
		var name := rig.get_bone_name(joint)
		var pivot := rig.get_bone_global_rest(joint).origin
		var scale := Vector3(.82, 1.0, .84)
		if name.begins_with("upperarm_") or name.begins_with("lowerarm_"):
			var next_name := name.replace("upperarm_", "lowerarm_") if name.begins_with("upperarm_") else name.replace("lowerarm_", "hand_")
			var end := rig.get_bone_global_rest(rig.find_bone(next_name)).origin
			pivot = Geometry3D.get_closest_point_to_segment(point, pivot, end)
			scale = Vector3.ONE * .70
		elif name.begins_with("hand_"):
			scale = Vector3(.70, .76, .64)
		elif name == "Head":
			scale = Vector3(.76, 1.0, .77)
		points[index] = pivot + (point - pivot) * scale
		normals[index] = (normals[index] / scale).normalized()
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	var fitted := ArrayMesh.new()
	fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	fitted.surface_set_material(0, original.surface_get_material(0))
	body.mesh = fitted
