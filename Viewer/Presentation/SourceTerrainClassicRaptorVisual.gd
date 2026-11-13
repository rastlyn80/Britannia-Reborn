# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/RaptorActionsVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.1, 2.1))
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
	if terrain.plane.is_empty():
		return
	if not dead:
		terrain.settle_live(.0005)
		update_landmarks()
	elif animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
		terrain.settle(self)


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		fall.plane = {}
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	terrain.split = source.terrain.split
	var duration := terrain.begin_from_display(self, source, source.terrain, source.current_clip, false)
	if not source.dead and duration > 0.0:
		terrain.blend_length = minf(.12, duration)
		for bone in source.skeleton.get_bone_count():
			terrain.blend_pose.append(source.skeleton.get_bone_pose(bone))
		terrain.settle(self)
	return duration


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
