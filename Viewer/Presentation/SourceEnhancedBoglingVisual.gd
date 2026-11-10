# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/BoglingActionsVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var fitted_fall := preload("res://Presentation/DisplayedCreatureFallPlayback.gd").new()
var fitted_lift := Vector3.ZERO

func _ready() -> void:
	super._ready()
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	fitted_fall.skin = Ground.skin_points(mesh, skeleton)
	animator.mixer_applied.connect(apply_fitted_pose)
	contact.modification_processed.connect(support_fit)

func _physics_process(delta: float) -> void:
	release_fit()
	super._physics_process(delta)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip == "BoglingSprout":
		contact.enabled = false
	return true

func release_fit() -> void:
	model.position -= fitted_lift
	fitted_lift = Vector3.ZERO

func apply_fitted_pose() -> void:
	release_fit()
	if dead:
		fitted_fall.settle(self)
	elif current_clip == "BoglingSprout":
		support_fit()

func support_fit() -> void:
	if dead or current_clip not in entry.get("archive_grounded_gestures", []):
		return
	release_fit()
	var floor := fitted_fall.floor_under(self)
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(fitted_fall.skin, skeleton, skeleton.global_transform, floor.position, floor.normal)
	if gap < .003:
		var before := model.position
		model.global_position.y += (.003 - gap) / float(floor.normal.y)
		fitted_lift = model.position - before
	update_landmarks()

func begin_death_from(source: Node3D) -> float:
	if source.current_clip not in entry.get("archive_grounded_gestures", []):
		play("Death", .08)
		return animator.get_animation("Death").length
	global_transform = source.global_transform
	model.position -= source.fitted_lift
	var duration := fitted_fall.begin_from_display(self, source, source.fitted_fall, source.current_clip, false)
	fitted_fall.blend_length = minf(.12, duration)
	if fitted_fall.blend_length <= 0.0:
		return duration
	for joint in skeleton.get_bone_count():
		fitted_fall.blend_pose.append(source.skeleton.get_bone_pose(joint))
	var root := skeleton.find_bone("spine")
	assert(root >= 0 and skeleton.get_bone_parent(root) < 0)
	var prior: Transform3D = fitted_fall.blend_pose[root]
	var target := skeleton.global_position - global_basis * fitted_fall.shift
	prior.origin += skeleton.global_basis.inverse() * (source.skeleton.global_position - target)
	fitted_fall.blend_pose[root] = prior
	fitted_fall.settle(self)
	return duration

func corpse_snapshot_floor() -> float:
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
