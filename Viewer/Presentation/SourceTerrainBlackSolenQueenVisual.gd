# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceSolenQueenActionsVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.05, 2.15))
	animator.mixer_applied.connect(update_terrain)
	contact.modification_processed.connect(update_terrain)


func apply_warrior_ground() -> void:
	if terrain.actor != null:
		terrain.release_live()
	super.apply_warrior_ground()


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	update_terrain()


func update_terrain() -> void:
	if terrain.plane.is_empty():
		return
	if not dead:
		terrain.settle_live(.0005)
	elif animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
		terrain.settle(self)
	update_landmarks()


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
