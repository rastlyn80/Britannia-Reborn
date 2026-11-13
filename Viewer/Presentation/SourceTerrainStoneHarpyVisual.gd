# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedStoneHarpyVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.3, 1.7))
	contact.modification_processed.connect(settle_living)


func _physics_process(delta: float) -> void:
	if not dead:
		terrain.release_live()
		terrain.sample()
	super._physics_process(delta)
	settle_living()


func update_fitted_support() -> void:
	if terrain.actor != null:
		terrain.release_live()
	super.update_fitted_support()
	settle_living()


func settle_living() -> void:
	if terrain.actor != null and not dead:
		terrain.settle_live(.0005)


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		collapse_plane = {}
		terrain.prepare_collapse()
	return true


func settle_collapse() -> void:
	if terrain.actor == null:
		super.settle_collapse()
	elif dead and (animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty()):
		terrain.settle(self)


func begin_death_from(source: Node3D) -> float:
	var airborne: bool = source.current_clip in AIRBORNE
	if source.is_fitted(source.current_clip):
		airborne = (source.native_flags & 4) != 0 or source.measured_gap(terrain.floor_under(source)) > .18
	var previous: RefCounted = source.terrain
	terrain.split = previous.split
	if not source.dead:
		model.transform = source.model.transform
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
		previous.shift = source.global_basis.inverse() * Vector3.UP * source.terrain.live_lift
	return terrain.begin_from_source(self, source, previous, airborne)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)