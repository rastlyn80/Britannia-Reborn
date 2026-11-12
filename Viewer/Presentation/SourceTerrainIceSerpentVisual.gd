# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedIceSerpentVisual.gd"

const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const Belly := preload("res://Presentation/SourceSerpentTreadContact.gd")
const Collapse := preload("res://Presentation/SourceCorpserEmergenceFall.gd")
var terrain := Terrain.new()
var belly := Belly.new()
var collapse := Collapse.new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.65, 2.05))
	collapse.skin = terrain.skin
	skeleton.add_child(belly)
	belly.active = false
	belly.bind(terrain.skin)
	contact.modification_processed.disconnect(update_fitted_ground)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	if terrain.plane.is_empty():
		super._physics_process(delta)
		return
	var up: Vector3 = (global_basis.inverse() * terrain.plane.normal).normalized()
	model.basis = (Basis(Quaternion(Vector3.UP, up)) * source_model_basis).scaled_local(model.scale)
	apply_ground()


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["Fidget", "Fidget2"]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	var accepted := super.receive_action(request)
	if accepted and dead and not terrain.plane.is_empty():
		collapse.split = terrain.split
		collapse.remember_floor(self, terrain.plane)
	return accepted


func apply_ground() -> void:
	if dead and not collapse.plane.is_empty():
		collapse.settle(self)
		return
	if dead or terrain.plane.is_empty():
		super.apply_ground()
		return
	var depth := 0.0
	if current_clip == EMERGE:
		var phase := animator.current_animation_position / maxf(.01, animator.current_animation_length)
		depth = .39 * (1.0 - smoothstep(.04, .82, phase))
	terrain.release_live()
	if depth < .005:
		if terrain.split:
			belly.clear_treads(float(terrain.plane.position.y))
		elif float(terrain.plane.normal.y) < .998:
			belly.clear_slope(terrain.plane)
	terrain.settle_live(depth)
	update_landmarks()


func begin_death_from(source: Node3D) -> float:
	dead = true
	contact.enabled = false
	if source.current_clip == EMERGE:
		return collapse.begin_emergence(self, source)
	collapse.split = source.terrain.split
	return collapse.begin_from_source(self, source, source.collapse, false)


func corpse_snapshot_floor() -> float:
	return NAN if collapse.plane.is_empty() else collapse.snapshot_floor(self)
