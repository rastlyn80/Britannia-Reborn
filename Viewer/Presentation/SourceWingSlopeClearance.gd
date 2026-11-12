# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEagleWingClearance.gd"


func clear_slope(plane: Dictionary) -> void:
	var rig := get_skeleton()
	var normal: Vector3 = plane.normal
	for wing: Dictionary in wings:
		var joint: int = wing.joints[0]
		var skin: Dictionary = wing.skin[0]
		for attempt in 4:
			var point := lowest_point(rig, skin, plane.position, normal)
			var lift := .005 - normal.dot(point - Vector3(plane.position))
			if lift < .008:
				break
			var pivot := rig.to_global(rig.get_bone_global_pose(joint).origin)
			var axis := (point - pivot).cross(normal)
			var lever := axis.length()
			if lever < .08:
				break
			var parent_basis := rig.get_bone_global_pose(rig.get_bone_parent(joint)).basis
			var local_axis := (parent_basis.inverse() * rig.global_basis.inverse() * axis).normalized()
			var turn := Quaternion(local_axis, minf(.09, lift / lever))
			rig.set_bone_pose_rotation(joint, (turn * rig.get_bone_pose_rotation(joint)).normalized())
			rig.force_update_all_bone_transforms()


func lowest_point(rig: Skeleton3D, skin: Dictionary, origin: Vector3, normal: Vector3) -> Vector3:
	var matrices: Array[Transform3D] = []
	for index in skin.bones.size():
		matrices.append(rig.global_transform * rig.get_bone_global_pose(skin.bones[index]) * skin.bind_poses[index])
	var nearest := INF
	var result := origin + normal
	for surface: Dictionary in skin.surfaces:
		var stride: int = surface.stride
		for vertex in surface.points.size():
			var point := Vector3.ZERO
			for influence in stride:
				var slot: int = vertex * stride + influence
				if surface.weights[slot] > 0.0:
					point += (matrices[surface.bindings[slot]] * surface.points[vertex]) * surface.weights[slot]
			var distance := normal.dot(point - origin)
			if distance < nearest:
				nearest = distance
				result = point
	return result
