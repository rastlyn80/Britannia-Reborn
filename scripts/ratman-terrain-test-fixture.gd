# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Height := .22


func floor_box(center: float, top: float) -> void:
	var ground := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, .20, 8.0)
	collision.shape = shape
	ground.position = Vector3(center, top - .10, 0.0)
	ground.add_child(collision)
	root.add_child(ground)


func step_gap(skin: Dictionary, rig: Skeleton3D, detail: Dictionary = {}) -> float:
	var matrices: Array[Transform3D] = []
	for bind in skin.bones.size():
		matrices.append(rig.global_transform * rig.get_bone_global_pose(skin.bones[bind]) * skin.bind_poses[bind])
	var lowest := INF
	for surface: Dictionary in skin.surfaces:
		for vertex in surface.points.size():
			var point := Vector3.ZERO
			var heaviest := 0.0
			var joint := -1
			for slot in surface.stride:
				var index: int = vertex * surface.stride + slot
				var weight: float = surface.weights[index]
				if weight > 0.0:
					point += (matrices[surface.bindings[index]] * surface.points[vertex]) * weight
					if weight > heaviest:
						heaviest = weight
						joint = skin.bones[surface.bindings[index]]
			var gap := point.y - (Height if point.x > 0.0 else 0.0)
			if gap < lowest:
				lowest = gap
				detail["point"] = str(point)
				detail["joint"] = rig.get_bone_name(joint)
	return lowest


func bow_step_gap(bow: MeshInstance3D) -> float:
	var lowest := INF
	for vertex: Vector3 in bow.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var point := bow.to_global(vertex)
		lowest = minf(lowest, point.y - (Height if point.x > 0.0 else 0.0))
	return lowest
