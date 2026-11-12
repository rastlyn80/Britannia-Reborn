# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/GiantSpiderActionsVisual.gd"

const TerrainFall := preload("res://Presentation/CougarTerrainFall.gd")
const Probes := [Vector2(-2.0, -1.3), Vector2(-2.0, 0.0), Vector2(-2.0, 1.3),
	Vector2(0.0, -1.3), Vector2(0.0, 1.3),
	Vector2(2.0, -1.3), Vector2(2.0, 0.0), Vector2(2.0, 1.3)]
var terrain := TerrainFall.new()
var live_lift := 0.0
var ground_ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.DOWN, 1)


func _ready() -> void:
	super._ready()
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	terrain.skin = Ground.skin_points(mesh, skeleton)


func _physics_process(_delta: float) -> void:
	if dead:
		return
	release_lift()
	var floor := terrain.floor_under(self)
	if not floor.has("collider"):
		terrain.plane = {}
		return
	terrain.remember_floor(self, floor)
	var inclination := sampled_inclination(floor)
	var scale := model.scale
	model.basis = (Basis(Quaternion(Vector3.UP, inclination)) * source_model_basis).scaled_local(scale)
	settle_living()


func sampled_inclination(floor: Dictionary) -> Vector3:
	terrain.split = false
	var normal: Vector3 = floor.normal
	var space := get_world_3d().direct_space_state
	var gradients := Vector2.ZERO
	var span := Vector2.ZERO
	for offset: Vector2 in Probes:
		var point := to_global(Vector3(offset.x, 0.0, offset.y))
		ground_ray.from = Vector3(point.x, global_position.y + .65, point.z)
		ground_ray.to = Vector3(point.x, global_position.y - .65, point.z)
		var hit := space.intersect_ray(ground_ray)
		if hit.is_empty() or hit.normal.y <= .75:
			continue
		var displacement := Vector3(hit.position) - Vector3(floor.position)
		var residual := normal.dot(displacement)
		if absf(residual) > .018 or normal.dot(hit.normal) < .995:
			terrain.split = true
		gradients += offset * residual
		span += offset * offset
	var local_normal := global_basis.inverse() * normal
	if terrain.split:
		local_normal.x -= gradients.x / maxf(span.x, .01)
		local_normal.z -= gradients.y / maxf(span.y, .01)
	return local_normal.normalized()


func release_lift() -> void:
	model.global_position.y -= live_lift
	live_lift = 0.0


func settle_living() -> void:
	if terrain.plane.is_empty():
		return
	release_lift()
	skeleton.force_update_all_bone_transforms()
	var normal: Vector3 = terrain.plane.normal
	var gap := terrain.step_gap(skeleton) if terrain.split else Ground.minimum_plane_gap(
		terrain.skin, skeleton, skeleton.global_transform, terrain.plane.position, normal)
	if is_finite(gap):
		live_lift = maxf(0.0, (.003 - gap) / (1.0 if terrain.split else normal.y))
		model.global_position.y += live_lift


func settle_collapse() -> void:
	if dead:
		terrain.settle(self)
	else:
		settle_living()


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead and terrain.plane.is_empty():
		terrain.remember_floor(self, terrain.floor_under(self))
	return true


func begin_death_from(source: Node3D) -> float:
	terrain.split = source.terrain.split
	return terrain.begin_from_source(self, source, source.terrain, false)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
