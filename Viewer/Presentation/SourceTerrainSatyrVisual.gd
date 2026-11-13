# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/ArchiveOccurrenceGestureVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.2, 2.2))
	contact.modification_processed.disconnect(ground_gesture.support.bind(self))
	contact.modification_processed.connect(support_archive_gesture)
	animator.mixer_applied.connect(settle_pose)
	contact.modification_processed.connect(settle_pose)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	ground_gesture.release(self)
	terrain.sample()
	super._physics_process(delta)
	settle_pose()


func support_archive_gesture() -> void:
	if terrain.plane.is_empty():
		ground_gesture.support(self)


func settle_pose() -> void:
	if not terrain.plane.is_empty():
		if not dead:
			terrain.settle_live(.0005)
		elif animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
			terrain.settle(self)


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
		ground_gesture.release(self)
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)


func cue_bard_song() -> void:
	if dead or not animator.has_animation("SatyrLean"):
		return
	if current_clip == "SatyrLean" and action_remaining > 0.0:
		return
	current_clip = "SatyrLean"
	contact.enabled = true
	animator.speed_scale = 1.0
	action_remaining = animator.get_animation(current_clip).length
	play(current_clip, .12)
	animator.seek(0.0, false)
