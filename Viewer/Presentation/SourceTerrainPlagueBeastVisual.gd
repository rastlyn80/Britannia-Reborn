# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedPlagueBeastVisual.gd"

const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const Collapse := preload("res://Presentation/CougarTerrainFall.gd")
var terrain := Terrain.new()
var terrain_fall := Collapse.new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.6, 1.75))
	terrain_fall.skin = terrain.skin
	fitted_fall = terrain_fall


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	if not terrain.plane.is_empty():
		var normal := (global_basis.inverse() * Vector3(terrain.plane.normal)).normalized()
		model.basis = (Basis(Quaternion(Vector3.UP, normal)) * source_model_basis).scaled_local(model.scale)


func support_fit(_recovering := false) -> void:
	if not dead:
		terrain.settle_live(.0005)
		update_landmarks()


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip == "PlagueBeastHatch":
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		terrain.release_live()
		terrain_fall.split = terrain.split
		terrain_fall.remember_floor(self, terrain.plane if not terrain.plane.is_empty() else terrain_fall.floor_under(self))
	return true


func begin_death_from(source: Node3D) -> float:
	dead = true
	contact.enabled = false
	terrain_fall.split = source.terrain.split
	var previous: RefCounted = source.fitted_fall
	if not source.dead:
		previous = Collapse.new()
		previous.plane = source.terrain.plane
		previous.shift = source.global_basis.inverse() * Vector3.UP * source.terrain.live_lift
	return terrain_fall.begin_from_source(self, source, previous, false)
