# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CougarTerrainFall.gd"

var actor: Node3D
var extent := Vector2.ONE
var live_lift := 0.0
var ground_ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.DOWN, 1)


func bind(visual: Node3D, footprint: Vector2) -> void:
	actor = visual
	extent = footprint
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	skin = Ground.skin_points(mesh, actor.skeleton)


func sample() -> void:
	var floor := floor_under(actor)
	if not floor.has("collider"):
		plane = {}
		split = false
		return
	remember_floor(actor, floor)
	split = spans_treads(floor)


func spans_treads(floor: Dictionary) -> bool:
	var space := actor.get_world_3d().direct_space_state
	var normal: Vector3 = floor.normal
	for x: float in [-extent.x, 0.0, extent.x]:
		for z: float in [-extent.y, 0.0, extent.y]:
			if x == 0.0 and z == 0.0:
				continue
			var point := actor.to_global(Vector3(x, 0.0, z))
			var height := actor.global_position.y
			ground_ray.from = Vector3(point.x, height + .65, point.z)
			ground_ray.to = Vector3(point.x, height - .65, point.z)
			var hit := space.intersect_ray(ground_ray)
			if not hit.is_empty() and hit.normal.y > .75 and (normal.dot(hit.normal) < .995
					or absf(normal.dot(hit.position - floor.position)) > .018):
				return true
	return false


func release_live() -> void:
	actor.model.global_position.y -= live_lift
	live_lift = 0.0


func settle_live(allowed_depth := 0.0) -> void:
	if actor == null or actor.dead or plane.is_empty():
		return
	release_live()
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	var normal: Vector3 = plane.normal
	var gap := (step_gap(rig) if split
		else Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.position, normal))
	if not is_finite(gap):
		return
	live_lift = maxf(0.0, (.003 - allowed_depth - gap) / (1.0 if split else normal.y))
	actor.model.global_position.y += live_lift
