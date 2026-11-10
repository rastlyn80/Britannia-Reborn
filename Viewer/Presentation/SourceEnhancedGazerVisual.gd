# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/GazerActionsVisual.gd"

const Hover := ["GazerTentacleSurvey", "GazerEyeFan", "GazerTiltRecoil", "GazerUnfurl",
	"GazerHoverScan", "GazerOrbitFeint", "GazerRaisedEyeAlert"]
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var fitted_skin := {}
var floor_shift := Vector3.ZERO

func _ready() -> void:
	super._ready()
	fitted_skin = Ground.skin_points(model.find_child("Body", true, false), skeleton)
	animator.mixer_applied.connect(adjust_hover)
	animator.mixer_applied.connect(fitted_fall.settle.bind(self))

func receive_action(request: Dictionary) -> bool:
	model.position -= floor_shift
	floor_shift = Vector3.ZERO
	if not super.receive_action(request):
		return false
	if current_clip in Hover:
		contact.enabled = false
	return true

func adjust_hover() -> void:
	model.position -= floor_shift
	floor_shift = Vector3.ZERO
	if dead or current_clip not in Hover:
		return
	var support := fitted_fall.floor_under(self)
	if not support.has("collider"):
		return
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(fitted_skin, skeleton, skeleton.global_transform, support.position, support.normal)
	if gap < .002:
		var prior := model.position
		model.global_position += Vector3.UP * ((.002 - gap) / support.normal.y)
		floor_shift = model.position - prior

func begin_death_from(source: Node3D) -> float:
	if source.current_clip in Hover:
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)

func corpse_snapshot_floor() -> float:
	if not fitted_fall.plane.is_empty():
		return fitted_fall.snapshot_floor(self)
	return super.corpse_snapshot_floor()
