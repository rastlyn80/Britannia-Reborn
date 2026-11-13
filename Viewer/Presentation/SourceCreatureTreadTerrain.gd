# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceFlyingCreatureTerrain.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")


func prepare_collapse() -> void:
	release_live()
	remember_floor(actor, plane if not plane.is_empty() else floor_under(actor))


func begin_collapse(source: Node3D, extra_lift := Vector3.ZERO) -> float:
	var previous: RefCounted = source.terrain
	split = previous.split
	if not source.dead:
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
		previous.shift = source.global_basis.inverse() * Vector3.UP * source.terrain.live_lift + extra_lift
	return begin_from_source(actor, source, previous, false)


func piece_step_gap(vertices: PackedVector3Array, space: Transform3D, floor: Dictionary) -> float:
	var rays := actor.get_world_3d().direct_space_state
	var height := float(floor.position.y)
	var minimum := INF
	for vertex: Vector3 in vertices:
		var point := space * vertex
		ground_ray.from = Vector3(point.x, height + .65, point.z)
		ground_ray.to = ground_ray.from - Vector3.UP * 1.3
		var hit := rays.intersect_ray(ground_ray)
		if not hit.is_empty() and float(hit.normal.y) > .75:
			minimum = minf(minimum, point.y - float(hit.position.y))
	return minimum
