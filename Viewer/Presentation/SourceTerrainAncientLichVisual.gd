# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/LichActionsVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var staff_points := PackedVector3Array()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.4, 1.7))
	animator.mixer_applied.connect(ground_living)
	if staff != null:
		var inverse := staff.global_transform.affine_inverse()
		for mesh: MeshInstance3D in staff_meshes():
			var relative := inverse * mesh.global_transform
			for surface in mesh.mesh.get_surface_count():
				for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					staff_points.append(relative * point)
	contact.modification_processed.connect(ground_living)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	ground_living()


func ground_living() -> void:
	if terrain.actor == null or dead or terrain.plane.is_empty():
		return
	terrain.settle_live(.0005)
	update_grip()
	var lift := staff_clearance_lift()
	if lift > 0.0:
		model.global_position.y += lift
		staff.global_position.y += lift
		terrain.live_lift += lift
		update_landmarks()


func staff_clearance_lift() -> float:
	if staff_points.is_empty() or terrain.plane.is_empty():
		return 0.0
	var normal: Vector3 = terrain.plane.normal
	var point: Vector3 = terrain.plane.position
	var gap := INF
	if terrain.split:
		gap = terrain.piece_step_gap(staff_points, staff.global_transform, terrain.plane)
	else:
		for vertex: Vector3 in staff_points:
			gap = minf(gap, (staff.to_global(vertex) - point).dot(normal))
	return maxf(0.0, (.003 - gap) / (1.0 if terrain.split else normal.y))


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func settle_collapse() -> void:
	if terrain.actor == null or terrain.plane.is_empty():
		super.settle_collapse()
		return
	if not dead or (animator.current_animation_position <= 0.0 and terrain.blend_pose.is_empty()):
		return
	terrain.settle(self)
	update_grip()
	if staff != null:
		staff.global_position.y += staff_clearance_lift()
		update_landmarks()


func begin_death_from(source: Node3D) -> float:
	terrain.split = source.terrain.split
	var previous: RefCounted = source.terrain
	if not source.dead:
		model.transform = source.model.transform
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	var duration := terrain.begin_from_source(self, source, previous, false)
	if staff != null and source.staff != null:
		staff.global_transform = source.staff.global_transform
		update_landmarks()
	return duration


func corpse_snapshot_floor() -> float:
	var floor := terrain.snapshot_floor(self)
	for vertex: Vector3 in staff_points:
		floor = minf(floor, to_local(staff.to_global(vertex)).y)
	return floor
