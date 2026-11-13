# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/WraithActionsVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	animator.mixer_applied.disconnect(fall.settle.bind(self))
	terrain.bind(self, Vector2(1.2, 1.35))
	animator.mixer_applied.connect(terrain.settle.bind(self))
	contact.modification_processed.connect(terrain.settle_live.bind(.0005))


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
