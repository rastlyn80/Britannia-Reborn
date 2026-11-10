# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/HarpyActionsVisual.gd"

const Fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd")
const Loft := ["HarpyDoubleWingbeat", "HarpyGlideSettle", "HarpyBank"]
var fit_support := preload("res://Presentation/ArchiveGestureGround.gd").new()
var fitted_fall := Fall.new()

func _ready() -> void:
	super._ready()
	fit_support.bind(self)
	animator.mixer_applied.connect(func(): fitted_fall.settle(self))

func _physics_process(delta: float) -> void:
	fit_support.release(self)
	super._physics_process(delta)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip in Loft:
		contact.enabled = false
	return true

func begin_death_from(source: Node3D) -> float:
	if source.current_clip in Loft:
		var hip := int(source.skeleton.find_bone("bip01 pelvis"))
		var torso: Vector3 = source.skeleton.to_global(source.skeleton.get_bone_global_pose(hip).origin)
		var height := (torso - source.global_position).dot(source.global_basis.y.normalized())
		if height > 1.26:
			return fitted_fall.begin_from_source(self, source, source.fitted_fall, true)
	return super.begin_death_from(source)

func corpse_snapshot_floor() -> float:
	if not fitted_fall.plane.is_empty():
		return fitted_fall.snapshot_floor(self)
	return super.corpse_snapshot_floor()
