# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SlithUopGaitVisual.gd"

const Breath := "SlithFireBreath"
const Quiet := "SlithQuietCoast"
var muzzle_head := -1
var muzzle_offset := Vector3.ZERO


func _ready() -> void:
	var gestures: Array = entry.get("archive_grounded_gestures", [])
	entry = entry.merged({"grounded_gestures": entry.grounded_gestures + gestures + [Breath]}, true)
	super._ready()
	animator.get_animation(Quiet).loop_mode = Animation.LOOP_LINEAR
	muzzle_head = skeleton.find_bone("bip01 head")
	var head := skeleton.get_bone_global_rest(muzzle_head)
	var neck := skeleton.get_bone_global_rest(skeleton.find_bone("bip01 neck1"))
	var jaw := skeleton.get_bone_global_rest(skeleton.find_bone("bip01 ponytail1"))
	var forward := (head.origin - neck.origin).normalized()
	muzzle_offset = head.affine_inverse() * (head.origin.lerp(jaw.origin, .35) + forward * .15)


func receive_action(request: Dictionary) -> bool:
	if request.get("protocol") != "classic" or request.get("action") != 12 \
			or request.get("frames") != 5 or request.get("repeat_count") != 1 \
			or request.get("reverse") != false or request.get("repeat") != false or request.get("delay") != 0:
		return super.receive_action(request)
	# The stock cast sends its projectile 1.3 seconds after the five-frame windup.
	var original := entry
	var categories: Dictionary = entry.classic_action_categories
	entry = entry.merged({"classic_action_categories": categories.merged({"12": Breath}, true)}, true)
	var accepted := super.receive_action(request)
	entry = original
	if accepted:
		var length := animator.get_animation(Breath).length
		animator.speed_scale = action_remaining / length
		action_remaining = length
	return accepted


func fire_breath_origin() -> Variant:
	if dead or current_clip != Breath or action_remaining <= 0.0:
		return null
	return skeleton.to_global(skeleton.get_bone_global_pose(muzzle_head) * muzzle_offset)


func begin_death_from(source: Node3D) -> float:
	if source.current_clip == Breath or source.current_clip in source.entry.get("archive_grounded_gestures", []):
		global_transform = source.global_transform
		model.transform = source.model.transform
	return super.begin_death_from(source)


func alternate_clip(request: Dictionary) -> String:
	if request.get("protocol") == "new" and int(request.get("type", -1)) == 5:
		var selected: String = entry.get("new_action_categories", {}).get("5", "")
		if selected in entry.get("archive_grounded_gestures", []):
			return ""
	return super.alternate_clip(request)


func play_gait(moving: bool, speed: float) -> void:
	if moving or not gait.known or gait.combat:
		super.play_gait(moving, speed)
	elif not dead and action_remaining <= 0.0 and current_clip != "LieDown":
		if current_clip != Quiet:
			current_clip = Quiet
			play(Quiet, .18)
		animator.speed_scale = 1.0
	if current_clip in entry.get("archive_grounded_gestures", []):
		contact.enabled = false
