# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedGiantRatVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(.95, 1.35))
	fitted_fall = terrain


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	if not contact.enabled:
		support_fit()


func support_fit() -> void:
	if not dead:
		terrain.settle_live(.0005)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	return terrain.begin_collapse(source)
