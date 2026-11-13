# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceCreatureTreadTerrain.gd"

var initial_clearance_deficit := 0.0


func begin_collapse(source: Node3D, extra_lift := Vector3.ZERO) -> float:
	if not source.dead:
		var support: Dictionary = source.terrain.plane
		if support.is_empty():
			support = floor_under(source)
		var rig: Skeleton3D = source.skeleton
		rig.force_update_all_bone_transforms()
		var gap: float = source.terrain.step_gap(rig) if source.terrain.split else Ground.minimum_plane_gap(
			skin, rig, rig.global_transform, support.position, support.normal)
		if is_finite(gap):
			initial_clearance_deficit = maxf(0.0, .002 - gap)
	return super.begin_collapse(source, extra_lift)


func settle(visual: Node3D) -> void:
	if split or plane.is_empty() or initial_clearance_deficit == 0.0:
		super.settle(visual)
		return
	var floor: Vector3 = plane.position
	plane.position = floor - plane.normal * unsettled_clearance()
	super.settle(visual)
	plane.position = floor


func step_gap(rig: Skeleton3D) -> float:
	return super.step_gap(rig) + unsettled_clearance()


func unsettled_clearance() -> float:
	if initial_clearance_deficit == 0.0 or blend_length <= 0.0:
		return 0.0
	var progress: float = (actor.animator.current_animation_position - blend_start) / blend_length
	return initial_clearance_deficit * (1.0 - smoothstep(0.0, 1.0, progress))
