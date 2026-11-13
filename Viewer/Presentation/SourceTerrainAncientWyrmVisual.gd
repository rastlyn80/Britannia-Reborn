# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceTerrainShadowWyrmVisual.gd"

var ground_gesture := preload("res://Presentation/ArchiveGestureGround.gd").new()


func _ready() -> void:
	super._ready()
	ground_gesture.bind(self)
	contact.modification_processed.disconnect(settle_pose)
	contact.modification_processed.connect(settle_pose)


func _physics_process(delta: float) -> void:
	if not dead:
		terrain.release_live()
		ground_gesture.release(self)
	super._physics_process(delta)


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
		ground_gesture.release(self)
	if not super.receive_action(request):
		return false
	if breathing:
		# Match the source clip duration to the stock delayed projectile.
		animator.speed_scale *= animator.get_animation(BreathMotion).length / (action_remaining * animator.get_playing_speed())
	return true
