# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedSilverSerpentVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var belly := preload("res://Presentation/SourceSerpentTreadContact.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(3.15, 1.85))
	skeleton.add_child(belly)
	belly.active = false
	belly.bind(terrain.skin)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	if terrain.plane.is_empty():
		super._physics_process(delta)
		return
	var normal: Vector3 = terrain.plane.normal
	var up := (global_basis.inverse() * normal).normalized()
	model.basis = (Basis(Quaternion(Vector3.UP, up)) * source_model_basis).scaled_local(model.scale)
	terrain.settle_live(surface_depth())


func surface_depth() -> float:
	if current_clip != Giant.Surface:
		return .0005
	var phase := animator.current_animation_position / maxf(.01, animator.current_animation_length)
	return .73 * (1.0 - smoothstep(.03, .85, phase))


func apply_ground() -> void:
	if terrain.actor == null or terrain.plane.is_empty():
		super.apply_ground()
		return
	if dead:
		if animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
			terrain.settle(self)
		return
	terrain.release_live()
	var depth := surface_depth()
	if depth < .005:
		if terrain.split:
			belly.clear_treads(float(terrain.plane.position.y))
		elif float(terrain.plane.normal.y) < .998:
			belly.clear_slope(terrain.plane)
	terrain.settle_live(depth)
	update_landmarks()


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func receive_enhanced_action(request: Dictionary, wire_flags: int) -> bool:
	if not super.receive_enhanced_action(request, wire_flags):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	if source.current_clip == Giant.Surface:
		terrain.split = source.terrain.split
		var previous := preload("res://Presentation/CreatureFallPlayback.gd").new()
		previous.plane = source.terrain.plane
		previous.shift = source.global_basis.inverse() * Vector3.UP * source.terrain.live_lift
		return terrain.begin_from_source(self, source, previous, false, true)
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
