# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SmallSnakeVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var gait := preload("res://Presentation/UopMonsterGait.gd").new()


func _ready() -> void:
	super._ready()
	contact.active = false
	terrain.bind(self, Vector2(1.4, 1.4))
	animator.mixer_applied.connect(settle_pose)


func _physics_process(_delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	if not terrain.plane.is_empty():
		var normal: Vector3 = terrain.plane.normal
		var up := (global_basis.inverse() * normal).normalized()
		model.basis = (Basis(Quaternion(Vector3.UP, up)) * source_model_basis).scaled_local(model.scale)
	settle_pose()


func set_native_combat_flags(flags: int) -> void:
	var was_peaceful := gait.known and not gait.combat
	gait.set_flags(flags)
	if was_peaceful and gait.combat and not dead and action_remaining <= 0.0:
		current_clip = entry.classic_action_categories["28"]
		action_remaining = animator.get_animation(current_clip).length
		animator.speed_scale = 1.0
		play(current_clip, .12)


func play_gait(moving: bool, speed: float) -> void:
	if not gait.play(self, moving, speed, entry.classic_action_categories["22"]):
		super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func settle_pose() -> void:
	if terrain.plane.is_empty():
		return
	if dead:
		if animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
			terrain.settle(self)
	else:
		terrain.settle_live(.0005)
	update_landmarks()


func begin_death_from(source: Node3D) -> float:
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
