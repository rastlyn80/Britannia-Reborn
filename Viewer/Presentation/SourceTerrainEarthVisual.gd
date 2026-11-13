# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/EarthAssemblyActionsVisual.gd"

var terrain := preload("res://Presentation/SourceEarthTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.25, 1.65))
	contact.modification_processed.connect(terrain.settle_body)


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
	if source.current_clip == "Assemble":
		return super.begin_death_from(source)
	return terrain.begin_collapse(source)


func settle_collapse() -> void:
	if terrain.plane.is_empty():
		super.settle_collapse()
	else:
		terrain.settle(self)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if terrain.plane.is_empty() else terrain.snapshot_floor(self)
