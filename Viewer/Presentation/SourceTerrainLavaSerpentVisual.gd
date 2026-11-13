# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedLavaSerpentVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd").new()
var belly := preload("res://Presentation/SourceSerpentTreadContact.gd").new()
var collapse := preload("res://Presentation/SourceCorpserEmergenceFall.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(3.15, 1.85))
	skeleton.add_child(belly)
	belly.active = false
	belly.bind(terrain.skin)
	collapse.skin = terrain.skin


func _physics_process(_delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	if not terrain.plane.is_empty():
		var up: Vector3 = (global_basis.inverse() * terrain.plane.normal).normalized()
		model.basis = (Basis(Quaternion(Vector3.UP, up)) * source_model_basis).scaled_local(model.scale)
		terrain.settle_live(surface_depth())


func apply_ground() -> void:
	if dead and not collapse.plane.is_empty():
		collapse.settle(self)
	elif terrain.actor == null or terrain.plane.is_empty():
		super.apply_ground()
	else:
		terrain.release_live()
		var depth := surface_depth()
		if depth < .005:
			if terrain.split:
				belly.clear_treads(float(terrain.plane.position.y))
			elif float(terrain.plane.normal.y) < .998:
				belly.clear_slope(terrain.plane)
		terrain.settle_live(depth)
	update_landmarks()


func update_fitted_ground() -> bool:
	# The parent also calls this through the contact modifier.
	if terrain.actor == null or terrain.plane.is_empty():
		return super.update_fitted_ground()
	return is_fitted(animator.assigned_animation)


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		collapse.split = terrain.split
		collapse.remember_floor(self, terrain.plane if not terrain.plane.is_empty() else collapse.floor_under(self))
	return true


func surface_depth() -> float:
	if current_clip != Emergence:
		return 0.0
	var phase := animator.current_animation_position / maxf(.01, animator.current_animation_length)
	return .63 * (1.0 - smoothstep(.02, .87, phase))


func begin_death_from(source: Node3D) -> float:
	if source.current_clip == Emergence:
		return collapse.begin_emergence(self, source)
	collapse.split = source.terrain.split
	var previous: RefCounted = source.collapse
	if not source.dead:
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	return collapse.begin_from_source(self, source, previous, false)


func corpse_snapshot_floor() -> float:
	return collapse.snapshot_floor(self)
