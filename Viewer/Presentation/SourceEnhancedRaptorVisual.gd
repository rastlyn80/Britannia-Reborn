# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/RaptorActionsVisual.gd"

const Floor := preload("res://Presentation/SourceGroundLookup.gd")
const Quiet := "RaptorQuietWatch"
var archive_pose := Transform3D.IDENTITY
var archive_supported := false


func _ready() -> void:
	super._ready()
	animator.get_animation(Quiet).loop_mode = Animation.LOOP_LINEAR
	var mesh := model.find_child("Velociraptor", true, false) as MeshInstance3D
	fall.skin = Floor.skin_points(mesh, skeleton)
	animator.mixer_applied.connect(settle_archive_gesture)


func play_gait(moving: bool, speed: float) -> void:
	if moving or not gait.known or gait.combat:
		super.play_gait(moving, speed)
	elif not dead and action_remaining <= 0.0 and current_clip != "LieDown":
		if current_clip != Quiet:
			current_clip = Quiet
			play(Quiet, .18)
		animator.speed_scale = 1.0
	if archive_gesture():
		contact.enabled = false


func receive_action(request: Dictionary) -> bool:
	var selected: String = entry.get("new_action_categories", {}).get("5", "")
	var playback := request
	if request.get("protocol") == "new" and request.get("type") == 5 and request.get("variation") == 1 \
			and selected in entry.get("archive_grounded_gestures", []):
		# The Classic-compatible renderer otherwise substitutes its own variant one.
		playback = request.merged({"variation": 0}, true)
	if not super.receive_action(playback):
		return false
	restore_archive_gesture()
	if archive_gesture():
		contact.enabled = false
	if playback != request:
		set_meta("native_action", request.duplicate(true))
	return true


func support_control_plane() -> void:
	if not archive_gesture():
		super.support_control_plane()


func _physics_process(delta: float) -> void:
	if archive_gesture():
		settle_archive_gesture()
	else:
		super._physics_process(delta)


func archive_gesture() -> bool:
	return not dead and current_clip in entry.get("archive_grounded_gestures", [])


func restore_archive_gesture() -> void:
	if archive_supported:
		model.transform = archive_pose
		archive_supported = false


func settle_archive_gesture() -> void:
	restore_archive_gesture()
	if not archive_gesture():
		return
	var support := fall.floor_under(self)
	var normal: Vector3 = support.normal
	archive_pose = model.transform
	archive_supported = true
	var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
	model.basis = (slope * source_model_basis).scaled_local(archive_pose.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
	var gap := Floor.minimum_plane_gap(fall.skin, skeleton, skeleton.global_transform, support.position, normal)
	model.global_position.y += (.003 - gap) / normal.y
	update_landmarks()


func begin_death_from(source: Node3D) -> float:
	if source.archive_gesture():
		global_transform = source.global_transform
		model.transform = source.model.transform
	return super.begin_death_from(source)
