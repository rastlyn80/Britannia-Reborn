# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedGamanVisual.gd"

const IdleGestures := ["Fidget", "Alert", "Eat", "GamanLowWatch", "GamanHeadAlert", "GamanLowGuard"]
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.7, 2.25))
	contact.modification_processed.connect(settle_living)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	if not contact.enabled:
		settle_living()


func settle_living() -> void:
	if not dead:
		terrain.settle_live(.0005)
		update_landmarks()


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in IdleGestures:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	model.transform = source.model.transform
	terrain.split = source.terrain.split
	if source.dead:
		return terrain.begin_from_source(self, source, source.terrain, false)
	terrain.remember_floor(self, source.terrain.plane if not source.terrain.plane.is_empty() else terrain.floor_under(self))
	return super.begin_death_from(source)


func apply_variant_entry() -> void:
	if pose_entry.active:
		# The source entry sets the model position from its retained curves.
		terrain.shift = Vector3.ZERO
		super.apply_variant_entry()
	if dead and terrain.actor != null and animator.current_animation_position > 0.0:
		terrain.settle(self)
		update_landmarks()


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
