# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceSpaceDisplayedFallPlayback.gd"

var split := false
var step_query := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.DOWN, 1)


func settle(actor: Node3D) -> void:
	if not split:
		super.settle(actor)
		return
	actor.model.position -= shift
	shift = Vector3.ZERO
	if not actor.dead or plane.is_empty() or actor.animator.current_animation_length <= 0.0:
		return
	if not blend_pose.is_empty():
		var weight := clampf((actor.animator.current_animation_position - blend_start) / blend_length, 0.0, 1.0)
		if weight < 1.0:
			for bone in blend_pose.size():
				actor.skeleton.set_bone_pose(bone, blend_pose[bone].interpolate_with(actor.skeleton.get_bone_pose(bone), weight))
		else:
			blend_pose.clear()
	actor.skeleton.force_update_all_bone_transforms()
	var gap := step_gap(actor.skeleton)
	if not is_finite(gap):
		return
	var lift := .002 - gap
	if lift < 0.0:
		var phase: float = actor.animator.current_animation_position / actor.animator.current_animation_length
		lift *= smoothstep(.75, 1.0, phase)
	var prior: Vector3 = actor.model.position
	actor.model.global_position.y += lift
	shift = actor.model.position - prior


func step_gap(rig: Skeleton3D) -> float:
	var matrices: Array[Transform3D] = []
	for index in skin.bones.size():
		matrices.append(rig.global_transform * rig.get_bone_global_pose(skin.bones[index]) * skin.bind_poses[index])
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
			if point.y - minimum > height + .65:
				continue
			step_query.from = Vector3(point.x, height + .65, point.z)
			step_query.to = Vector3(point.x, height - .65, point.z)
			var hit := space.intersect_ray(step_query)
			if not hit.is_empty() and hit.normal.y > .75:
				minimum = minf(minimum, point.y - float(hit.position.y))
	return minimum
