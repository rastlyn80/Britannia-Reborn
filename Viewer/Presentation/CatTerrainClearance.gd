# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CougarTerrainFall.gd"

const Approach := .24
var riser := {}


func step_gap(rig: Skeleton3D) -> float:
	if riser.is_empty():
		return super.step_gap(rig)
	var matrices: Array[Transform3D] = []
	for bind in skin.bones.size():
		matrices.append(rig.global_transform * rig.get_bone_global_pose(skin.bones[bind]) * skin.bind_poses[bind])
	var space := rig.get_world_3d().direct_space_state
	var height: float = plane.position.y
	var minimum := INF
	for surface: Dictionary in skin.surfaces:
		for vertex in surface.points.size():
			var point := Vector3.ZERO
			for influence in surface.stride:
				var slot: int = vertex * surface.stride + influence
				var weight: float = surface.weights[slot]
				if weight > 0.0:
					point += (matrices[surface.bindings[slot]] * surface.points[vertex]) * weight
			if point.y - minimum > height + .45:
				continue
			step_query.from = Vector3(point.x, height + .45, point.z)
			step_query.to = Vector3(point.x, height - .45, point.z)
			var hit := space.intersect_ray(step_query)
			if not hit.is_empty() and hit.normal.y > .75:
				minimum = minf(minimum, point.y - approach_height(point, hit))
	return minimum


func approach_height(point: Vector3, hit: Dictionary) -> float:
	var floor_height: float = hit.position.y
	if riser.is_empty() or hit.collider != riser.lower.collider:
		return floor_height
	var edge_distance: float = riser.direction.dot(point - riser.edge)
	var fraction := smoothstep(-Approach, 0.0, edge_distance)
	var high: Vector3 = riser.upper.position
	var normal: Vector3 = riser.upper.normal
	var upper_height := high.y - normal.dot(Vector3(point.x - high.x, 0.0, point.z - high.z)) / normal.y
	return lerpf(floor_height, maxf(floor_height, upper_height), fraction)
