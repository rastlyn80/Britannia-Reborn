# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedGiantSerpentVisual.gd"

const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const Belly := preload("res://Presentation/SourceSerpentTreadContact.gd")
const Emergence := preload("res://Presentation/SourceCorpserEmergenceFall.gd")
var terrain := Terrain.new()
var belly := Belly.new()
var collapse := Emergence.new()
var moving_for_gait := false


func _init() -> void:
	fall = collapse


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(3.15, 1.85))
	skeleton.add_child(belly)
	belly.active = false
	belly.bind(terrain.skin)


func play_gait(moving: bool, speed: float) -> void:
	moving_for_gait = moving
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not dead and moving_for_gait and request.get("protocol") == "classic" and request.get("action") in [1, 17, 18]:
		return true
	var accepted := super.receive_action(request)
	if accepted and dead:
		collapse.split = terrain.split
	return accepted


func receive_enhanced_action(request: Dictionary, wire_flags: int) -> bool:
	var accepted := super.receive_enhanced_action(request, wire_flags)
	if accepted and dead:
		collapse.split = terrain.split
	return accepted


func _physics_process(_delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	if not terrain.plane.is_empty():
		var up: Vector3 = (global_basis.inverse() * terrain.plane.normal).normalized()
		model.basis = (Basis(Quaternion(Vector3.UP, up)) * source_model_basis).scaled_local(model.scale)
	terrain.settle_live(surface_depth())


func settle() -> void:
	if dead:
		fall.settle(self)
	elif not terrain.plane.is_empty():
		terrain.release_live()
		var depth := surface_depth()
		if depth < .005:
			if terrain.split:
				belly.clear_treads(float(terrain.plane.position.y))
			elif float(terrain.plane.normal.y) < .998:
				belly.clear_slope(terrain.plane)
		terrain.settle_live(depth)
	update_landmarks()


func surface_depth() -> float:
	if current_clip != Surface:
		return 0.0
	var phase := animator.current_animation_position / maxf(.01, animator.current_animation_length)
	return .67 * (1.0 - smoothstep(.03, .85, phase))


func begin_death_from(source: Node3D) -> float:
	dead = true
	contact.enabled = false
	if source.current_clip == Surface:
		var duration := collapse.begin_emergence(self, source)
		collapse.blend_length = minf(.24, duration)
		collapse.settle(self)
		return duration
	collapse.split = source.terrain.split
	return fall.begin_from_source(self, source, source.fall, false)
