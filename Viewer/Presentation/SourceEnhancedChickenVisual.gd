# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/ChickenActionsVisual.gd"

var gesture_shift := Vector3.ZERO

func _ready() -> void:
	super._ready()
	remember_support({})
	animator.mixer_applied.connect(release_gesture)
	contact.modification_processed.connect(support_gesture)

func _physics_process(delta: float) -> void:
	release_gesture()
	super._physics_process(delta)

func release_gesture() -> void:
	model.position -= gesture_shift
	gesture_shift = Vector3.ZERO

func support_gesture() -> void:
	if dead or current_clip not in entry.get("archive_grounded_gestures", []):
		return
	release_gesture()
	var plane := support_plane()
	var gap := skin_gap(skeleton.global_transform, plane.position, plane.normal)
	if gap >= .0025:
		return
	var before := model.position
	model.global_position.y += (.0025 - gap) / float(plane.normal.y)
	gesture_shift = model.position - before
	update_landmarks()

func begin_death_from(source: Node3D) -> float:
	if source.current_clip not in entry.get("archive_grounded_gestures", []):
		return super.begin_death_from(source)
	global_transform = source.global_transform
	var duration := super.begin_death_from(source)
	entry_start = 0.0
	entry_span = minf(.12, duration)
	entry_root = source.motion_root.position
	for bone in source.skeleton.get_bone_count():
		entry_pose.append(source.skeleton.get_bone_pose(bone))
	settle_collapse()
	return duration
