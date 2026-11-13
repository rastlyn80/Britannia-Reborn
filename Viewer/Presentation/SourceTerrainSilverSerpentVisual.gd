# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceSilverSerpentVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var belly := preload("res://Presentation/SourceSerpentTreadContact.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(3.15, 1.85))
	skeleton.add_child(belly)
	belly.active = false
	belly.bind(terrain.skin)


func _physics_process(_delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	if not terrain.plane.is_empty():
		var normal: Vector3 = terrain.plane.normal
		var up := (global_basis.inverse() * normal).normalized()
		model.basis = (Basis(Quaternion(Vector3.UP, up)) * source_model_basis).scaled_local(model.scale)
		terrain.settle_live(.0005)


func apply_ground() -> void:
	if terrain.actor == null or terrain.plane.is_empty():
		super.apply_ground()
		return
	if dead:
		if animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
			terrain.settle(self)
		return
	terrain.release_live()
	if terrain.split:
		belly.clear_treads(float(terrain.plane.position.y))
	elif float(terrain.plane.normal.y) < .998:
		belly.clear_slope(terrain.plane)
	terrain.settle_live(.0005)
	update_landmarks()


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
