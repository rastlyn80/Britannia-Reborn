# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedJukaWarriorVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd").new()
var terrain_fall := preload("res://Presentation/CougarTerrainFall.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.15, 1.5))
	terrain_fall.skin = terrain.skin
	fitted_fall = terrain_fall
	contact.modification_processed.connect(settle_contact)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)


func apply_blend_ground() -> void:
	if dead:
		super.apply_blend_ground()
		return
	terrain.release_live()
	if terrain.split:
		# The original contact modifier can use both treads from this common height.
		model.position.y = source_model_position.y
		contact.base_model_y = model.position.y
		if is_fitted(animator.assigned_animation):
			var normal := (global_basis.inverse() * Vector3(terrain.plane.normal)).normalized()
			model.basis = (Basis(Quaternion(Vector3.UP, normal)) * source_model_basis).scaled_local(model.scale)
	else:
		super.apply_blend_ground()
	settle_living()


func settle_contact() -> void:
	if not contact.enabled:
		return
	# The inherited sole modifier has restored the uncorrected model height.
	terrain.live_lift = 0.0
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
		terrain_fall.split = terrain.split
		terrain_fall.remember_floor(self, terrain.plane if not terrain.plane.is_empty() else terrain_fall.floor_under(self))
	return true


func begin_death_from(source: Node3D) -> float:
	terrain_fall.split = source.terrain.split
	var previous: RefCounted = source.fitted_fall
	if not source.dead:
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
		previous.shift = source.global_basis.inverse() * Vector3.UP * source.terrain.live_lift
	return terrain_fall.begin_from_source(self, source, previous, false)
