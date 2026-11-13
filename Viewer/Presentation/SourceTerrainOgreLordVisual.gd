# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedOgreLordVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var club_points := PackedVector3Array()


func _ready() -> void:
	super._ready()
	animator.mixer_applied.disconnect(settle_collapse)
	contact.modification_processed.disconnect(gesture.support.bind(self, GROUNDED_CLIPS))
	terrain.bind(self, Vector2(2.8, 2.55))
	for surface in club.mesh.get_surface_count():
		club_points.append_array(club.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
	contact.modification_processed.connect(settle_fitted)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	if not is_fitted():
		settle_fitted()


func settle_fitted() -> void:
	if terrain.actor == null or terrain.plane.is_empty():
		super.settle_fitted()
		return
	if dead:
		if animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
			terrain.settle(self)
		club.hide()
		return
	terrain.release_live()
	if is_fitted():
		var normal := (global_basis.inverse() * Vector3(terrain.plane.normal)).normalized()
		model.basis = (Basis(Quaternion(Vector3.UP, normal)) * source_model_basis).scaled_local(model.scale)
	terrain.settle_live(.0005)
	sync_club()
	if not club.visible:
		return
	var floor: Dictionary = terrain.plane
	var gap := terrain.piece_step_gap(club_points, club.global_transform, floor) if terrain.split else INF
	if not terrain.split:
		var normal: Vector3 = floor.normal
		for point in club_points:
			gap = minf(gap, normal.dot(club.to_global(point) - Vector3(floor.position)) / normal.y)
	if gap < .0025:
		var rise := .0025 - gap
		terrain.live_lift += rise
		model.global_position.y += rise
		club.global_position.y += rise


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		collapse_plane = {}
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	var previous: RefCounted = source.terrain
	terrain.split = previous.split
	if not source.dead:
		model.transform = source.model.transform
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	return terrain.begin_from_source(self, source, previous, false)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
