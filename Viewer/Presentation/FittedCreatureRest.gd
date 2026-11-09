# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const FITTED := "FittedRest"
const REST := "LieDown"

static func install(actor: Node3D) -> void:
	var clips: AnimationLibrary = actor.animator.get_animation_library("")
	assert(clips.has_animation(FITTED))
	clips.remove_animation(REST)
	clips.rename_animation(FITTED, REST)

static func use_ground_support(actor: Node3D, accepted: bool) -> bool:
	if accepted and actor.current_clip == REST:
		actor.contact.enabled = true
	return accepted
