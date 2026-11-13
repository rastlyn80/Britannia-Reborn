# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceFlyingCreatureTerrain.gd"


func prepare_collapse() -> void:
	release_live()
	remember_floor(actor, plane if not plane.is_empty() else floor_under(actor))


func begin_collapse(source: Node3D) -> float:
	var previous: RefCounted = source.terrain
	split = previous.split
	if not source.dead:
		var support := previous
		previous = preload("res://Presentation/CreatureFallPlayback.gd").new()
		previous.plane = support.plane
		previous.shift = source.global_basis.inverse() * Vector3.UP * support.live_lift
	return begin_from_source(actor, source, previous, false)


func settle_body() -> void:
	if actor.current_clip == "Assemble":
		var player: AnimationPlayer = actor.animator
		if player.current_animation_position < player.current_animation_length * .98:
			return
	settle_live(.0005)


func piece_step_gap(vertices: PackedVector3Array, space: Transform3D, floor: Dictionary) -> float:
	var rays := actor.get_world_3d().direct_space_state
	var minimum := INF
	for vertex: Vector3 in vertices:
		var point := space * vertex
		ground_ray.from = Vector3(point.x, float(floor.position.y) + .65, point.z)
		ground_ray.to = ground_ray.from - Vector3.UP * 1.3
		var hit := rays.intersect_ray(ground_ray)
		if not hit.is_empty() and float(hit.normal.y) > .75:
			minimum = minf(minimum, point.y - float(hit.position.y))
	return minimum
