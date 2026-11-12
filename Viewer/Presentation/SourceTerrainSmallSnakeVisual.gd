# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SmallSnakeVisual.gd"

const Terrain := preload("res://Presentation/SourceTerrainMotion.gd")
const Belly := preload("res://Presentation/SourceSerpentTreadContact.gd")
var terrain := Terrain.new()
var belly := Belly.new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(.62, .62))
	skeleton.add_child(belly)
	belly.active = false
	belly.bind(terrain.skin)
	animator.mixer_applied.connect(settle_pose)


func _physics_process(_delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	var space := get_world_3d().direct_space_state
	terrain.sample()
	if not terrain.plane.is_empty():
		var normal: Vector3 = global_basis.inverse() * terrain.plane.normal
		var tilt := Basis(Quaternion(Vector3.UP, normal.normalized()))
		model.basis = (tilt * source_model_basis).scaled_local(model.scale)
	contact.sample(space, global_position)
	settle_living()


func settle_pose() -> void:
	if dead:
		terrain.settle(self)
		return
	terrain.release_live()
	if not terrain.plane.is_empty():
		if terrain.split:
			belly.clear_treads(float(terrain.plane.position.y))
		elif float(terrain.plane.normal.y) < .998:
			belly.clear_slope(terrain.plane)
	settle_living()


func settle_living() -> void:
	terrain.settle_live()
	update_landmarks()


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["Fidget", "Alert"]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		terrain.release_live()
		if terrain.plane.is_empty():
			terrain.remember_floor(self, terrain.floor_under(self))
	return true


func begin_death_from(source: Node3D) -> float:
	return terrain.enter_from_display(self, source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
