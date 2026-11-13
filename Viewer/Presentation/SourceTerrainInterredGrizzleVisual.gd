# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedGrizzleChangelingVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.6, 1.75))
	contact.modification_processed.connect(settle_living)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	if not is_fitted():
		settle_living()


func support_control_plane() -> void:
	if terrain.actor == null or terrain.plane.is_empty():
		super.support_control_plane()


func place_fitted_pose() -> void:
	if terrain.actor == null or terrain.plane.is_empty():
		super.place_fitted_pose()
		return
	terrain.release_live()
	var normal := (global_basis.inverse() * Vector3(terrain.plane.normal)).normalized()
	model.basis = (Basis(Quaternion(Vector3.UP, normal)) * source_model_basis).scaled_local(model.scale)
	settle_living()


func settle_action() -> void:
	if terrain.actor == null:
		super.settle_action()
	elif dead:
		if animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
			terrain.settle(self)
	else:
		terrain.release_live()
		super.settle_action()
		settle_living()


func settle_living() -> void:
	if not dead:
		terrain.settle_live(.0005)
		update_landmarks()


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
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
