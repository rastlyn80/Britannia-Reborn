# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.7, 1.7))
	animator.mixer_applied.connect(settle_pose)
	contact.modification_processed.connect(settle_pose)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	settle_pose()


func settle_pose() -> void:
	if not terrain.plane.is_empty():
		if not dead:
			terrain.settle_live(.0005)
		elif animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
			terrain.settle(self)


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
