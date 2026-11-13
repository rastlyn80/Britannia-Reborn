# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/LavaSerpentActionsVisual.gd"

const Emergence := "LavaSerpentThreadEmergence"
const Breath := "LavaSerpentFireBreath"
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var fitted_lift := Vector3.ZERO
var muzzle_head := -1
var muzzle_offset := Vector3.ZERO


func _ready() -> void:
	super._ready()
	fitted_fall.skin = support_skin
	animator.mixer_applied.connect(fitted_fall.settle.bind(self))
	contact.modification_processed.connect(update_fitted_ground)
	muzzle_head = skeleton.find_bone("bip01 head")
	var neck := skeleton.get_bone_global_rest(skeleton.find_bone("bip01 neck4"))
	var head := skeleton.get_bone_global_rest(muzzle_head)
	var jaw := skeleton.get_bone_global_rest(skeleton.find_bone("bip01 ponytail1"))
	var forward := (head.origin - neck.origin).normalized()
	muzzle_offset = head.affine_inverse() * (head.origin.lerp(jaw.origin, .35) + forward * .20)


func receive_action(request: Dictionary) -> bool:
	# The stock ability emits this Classic packet 1.3 seconds before its fireball.
	if (native_body == 90 and not dead and animator.has_animation(Breath) and request.get("protocol") == "classic" and request.get("action") == 12
			and request.get("frames") == 5 and request.get("repeat_count") == 1
			and request.get("reverse") == false and request.get("repeat") == false and request.get("delay") == 0):
		current_clip = Breath
		contact.enabled = true
		action_remaining = animator.get_animation(Breath).length
		animator.speed_scale = 1.0
		play(Breath, .12)
		animator.seek(0.0, false)
		set_meta("native_action", request.duplicate(true))
		return true
	return super.receive_action(request)


func fire_breath_origin() -> Variant:
	if dead or current_clip != Breath or action_remaining <= 0.0:
		return null
	return skeleton.to_global(skeleton.get_bone_global_pose(muzzle_head) * muzzle_offset)


func is_fitted(clip: String) -> bool:
	return clip == Breath or clip in entry.get("archive_grounded_gestures", [])


func apply_ground() -> void:
	if not fitted_fall.plane.is_empty():
		return
	if not update_fitted_ground():
		fitted_lift = Vector3.ZERO
		super.apply_ground()


func update_fitted_ground() -> bool:
	var clip := animator.assigned_animation
	if dead or not is_fitted(clip):
		return false
	model.position.y = source_position.y
	fitted_lift = Vector3.ZERO
	var floor := fitted_fall.floor_under(self)
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, floor.position, floor.normal)
	var phase := animator.current_animation_position / animator.current_animation_length
	var allowed_depth := .63 * (1.0 - smoothstep(.02, .87, phase)) if clip == Emergence else 0.0
	var lift := maxf(0.0, .004 - allowed_depth - gap) / float(floor.normal.y)
	var before := model.position
	model.global_position.y += lift
	fitted_lift = model.position - before
	update_landmarks()
	return true


func begin_death_from(source: Node3D) -> float:
	if not source.is_fitted(source.current_clip):
		return super.begin_death_from(source)
	model.position -= source.fitted_lift
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, false, source.current_clip == Emergence)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
