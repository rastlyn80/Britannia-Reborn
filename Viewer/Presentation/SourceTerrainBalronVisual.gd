# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedBalronVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var wings := preload("res://Presentation/SourceDaemonWingClearance.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(4.2, 3.3))
	skeleton.add_child(wings)
	wings.active = false
	wings.bind(terrain.skin)
	animator.mixer_applied.disconnect(fall.settle.bind(self))
	animator.mixer_applied.connect(terrain.settle.bind(self))
	contact.align_skinned_soles = true


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)


func update_fit() -> void:
	if dead:
		return
	if terrain.plane.is_empty():
		super.update_fit()
		return
	release_fit()
	terrain.release_live()
	if terrain.split:
		wings.clear_treads(float(terrain.plane.position.y))
	elif float(terrain.plane.normal.y) < .998:
		wings.clear_slope(terrain.plane)
	var target := .003
	if is_fitted(current_clip) and airborne_fit:
		target = lerpf(starting_clearance, maxf(starting_clearance, AirClearance),
			smoothstep(0.0, .16, animator.current_animation_position))
	terrain.settle_live(.003 - target)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		release_fit()
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	var airborne: bool = source.current_clip in fall.FLIGHT or (is_fitted(source.current_clip) and source.airborne_fit)
	var previous: RefCounted = source.terrain
	terrain.split = previous.split
	if not source.dead:
		# Keep the living model's measured lift through the first fall pose.
		model.transform = source.model.transform
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	return terrain.begin_from_source(self, source, previous, airborne)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
