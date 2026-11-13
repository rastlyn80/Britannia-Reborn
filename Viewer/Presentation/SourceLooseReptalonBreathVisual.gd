# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceReptalonActionsVisual.gd"

const Breath := "ReptalonFireBreath"

func _ready() -> void:
	super._ready()
	if animator.has_animation("Attack2"):
		var attack := animator.get_animation("Attack2").duplicate() as Animation
		var library := AnimationLibrary.new()
		library.add_animation(Breath, attack)
		animator.add_animation_library("reptalon", library)

func receive_action(request: Dictionary) -> bool:
	if (not dead and native_body == 276 and not get_meta("native_mount_item", 0)
			and request.get("protocol") == "classic" and request.get("action") == 12
			and request.get("frames") == 5 and request.get("repeat_count") == 1
			and request.get("reverse") == false and request.get("repeat") == false and request.get("delay") == 0):
		var breath := "reptalon/" + Breath
		if animator.has_animation(breath):
			current_clip = breath
			contact.enabled = true
			action_remaining = 2.05
			animator.speed_scale = 1.0
			animator.play(breath, .12, animator.get_animation(breath).length / action_remaining)
			animator.seek(0.0, false)
			set_meta("native_action", request.duplicate(true))
			return true
	return super.receive_action(request)


func fire_breath_origin() -> Variant:
	if dead or current_clip != "reptalon/" + Breath or action_remaining <= 0.0:
		return null
	skeleton.force_update_all_bone_transforms()
	return socket("mouth").origin
