# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/ChickenActionsVisual.gd"

const Terrain := preload("res://Presentation/SourceTerrainMotion.gd")
const IdleGestures := ["Fidget", "SourceIdle2", "ChickenSettledWatch"]
var terrain := Terrain.new()


func _ready() -> void:
	super._ready()
	remember_support({})
	terrain.actor = self
	terrain.extent = Vector2(.52, .61)
	terrain.skin = Terrain.combine_skins(collapse_skin)
	animator.mixer_applied.disconnect(settle_collapse)
	animator.mixer_applied.connect(settle_pose)


func _physics_process(_delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	if not terrain.plane.is_empty():
		var up: Vector3 = (global_basis.inverse() * terrain.plane.normal).normalized()
		model.basis = (Basis(Quaternion(Vector3.UP, up)) * source_model_basis).scaled_local(model.scale)
	contact.sample(get_world_3d().direct_space_state, global_position)
	settle_pose()


func settle_pose() -> void:
	if dead:
		terrain.settle(self)
	else:
		terrain.settle_live()
	update_landmarks()


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in IdleGestures:
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
