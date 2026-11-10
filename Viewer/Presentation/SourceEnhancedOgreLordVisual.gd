# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/OgreLordActionsVisual.gd"

const BoneClub := preload("OgreLordBoneClub.gd")
const ClubClips := ["OgreLordDownwardClub", "OgreLordCrouchRise", "OgreLordClubCheck",
	"OgreLordOverheadGuard", "OgreLordClubLift"]
var club: MeshInstance3D
var right_grasp := -1
var right_wrist := -1
var right_elbow := -1
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var unposed_transform := Transform3D.IDENTITY
var fitted_support := false


func _ready() -> void:
	super._ready()
	fitted_fall.skin = gesture.skin
	club = BoneClub.new()
	add_child(club)
	club.hide()
	right_grasp = skeleton.find_bone("cp_grasp_rhand")
	right_wrist = skeleton.find_bone("bip01 r hand")
	right_elbow = skeleton.find_bone("bip01 r forearm")
	assert(mini(right_grasp, mini(right_wrist, right_elbow)) >= 0)
	animator.mixer_applied.connect(settle_fitted)


func is_fitted() -> bool:
	return current_clip in ClubClips


func receive_action(request: Dictionary) -> bool:
	release_fitted()
	if not super.receive_action(request):
		return false
	if is_fitted():
		contact.enabled = false
	return true


func _physics_process(delta: float) -> void:
	if is_fitted():
		settle_fitted()
	elif fitted_fall.plane.is_empty():
		super._physics_process(delta)


func release_fitted() -> void:
	if fitted_support:
		model.transform = unposed_transform
		fitted_support = false


func settle_fitted() -> void:
	release_fitted()
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
	elif is_fitted() and not dead:
		var plane := fitted_fall.floor_under(self)
		var normal: Vector3 = plane.normal
		unposed_transform = model.transform
		fitted_support = true
		var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (slope * source_model_basis).scaled_local(unposed_transform.basis.get_scale())
		skeleton.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(fitted_fall.skin, skeleton, skeleton.global_transform, plane.position, normal)
		model.global_position.y += (.003 - gap) / normal.y
	sync_club()


func sync_club() -> void:
	club.visible = not dead and current_clip in ClubClips
	if not club.visible:
		return
	var phase := animator.current_animation_position / maxf(.001, animator.current_animation_length)
	var axis := Vector3(-.40, .25, .88)
	match current_clip:
		"OgreLordDownwardClub":
			var drop := smoothstep(.27, .52, phase) * (1.0 - smoothstep(.62, .94, phase))
			axis = Vector3(-.55, .60, .50).lerp(Vector3(-.25, -.46, .83), drop)
		"OgreLordCrouchRise":
			axis = Vector3(-.46, .04, .89)
		"OgreLordClubCheck":
			axis = Vector3(-.48, .37, .80)
		"OgreLordOverheadGuard", "OgreLordClubLift":
			axis = Vector3(-.44, .80, .27)
	var elbow := skeleton.to_global(skeleton.get_bone_global_pose(right_elbow).origin)
	var wrist := skeleton.to_global(skeleton.get_bone_global_pose(right_wrist).origin)
	var arm := (wrist - elbow).normalized()
	var direction := ((global_basis * axis).normalized() * .82 + arm * .18).normalized()
	var grasp := skeleton.to_global(skeleton.get_bone_global_pose(right_grasp).origin)
	var support := fitted_fall.floor_under(self)
	var normal: Vector3 = support.normal
	var clearance := maxf(.0, normal.dot(grasp - Vector3(support.position)) - .115)
	var tilt := clampf(direction.dot(normal), -minf(.96, clearance / .78), minf(.96, clearance / .225))
	var planar := direction.slide(normal).normalized()
	direction = planar * sqrt(1.0 - tilt * tilt) + normal * tilt
	club.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, direction)), grasp)


func begin_death_from(source: Node3D) -> float:
	if source.current_clip in ClubClips:
		club.hide()
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	if fitted_fall.plane.is_empty():
		return super.corpse_snapshot_floor()
	return fitted_fall.snapshot_floor(self)

