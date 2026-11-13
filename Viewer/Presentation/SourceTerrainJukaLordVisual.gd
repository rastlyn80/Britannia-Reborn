# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedJukaLordVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.5, 1.7))
	contact.modification_processed.connect(settle_live)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	settle_live()


func apply_blend_ground() -> void:
	if terrain.actor == null:
		super.apply_blend_ground()
		return
	if dead:
		if not terrain.plane.is_empty() and (animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty()):
			terrain.settle(self)
		update_bow()
		return
	terrain.release_live()
	super.apply_blend_ground()
	settle_live()


func settle_live() -> void:
	if terrain.actor != null and not dead:
		terrain.settle_live(.0005)
		update_bow()
		update_landmarks()


func update_bow() -> void:
	super.update_bow()
	if terrain.actor == null or terrain.plane.is_empty() or not is_instance_valid(bow_holder) or not bow_holder.visible:
		return
	var vertices: PackedVector3Array = bow_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var normal: Vector3 = terrain.plane.normal
	var gap := terrain.piece_step_gap(vertices, bow_mesh.global_transform, terrain.plane) if terrain.split \
		else bow_floor_gap(vertices, bow_mesh.global_transform, normal, -normal.dot(terrain.plane.position))
	var lift := maxf(0.0, (.003 - gap) / (1.0 if terrain.split else normal.y))
	if lift > 0.0 and is_finite(lift):
		var before := model.position
		var displayed_bow := bow_holder.global_position
		model.global_position.y += lift
		bow_holder.global_position = displayed_bow + Vector3.UP * lift
		if not dead:
			terrain.live_lift += lift
		else:
			terrain.shift += model.position - before


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	terrain.split = source.terrain.split
	var previous: RefCounted = source.terrain
	if not source.dead:
		model.transform = source.model.transform
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	return terrain.begin_from_source(self, source, previous, false)


func corpse_snapshot_floor() -> float:
	var floor := terrain.snapshot_floor(self)
	if is_instance_valid(bow_holder) and bow_holder.visible:
		var local := global_transform.affine_inverse() * bow_mesh.global_transform
		for point: Vector3 in bow_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			floor = minf(floor, (local * point).y)
	return floor
