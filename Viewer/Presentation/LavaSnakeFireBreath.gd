# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Body := 52
const Hues := [0x647, 0x650, 0x659, 0x662, 0x66b, 0x674]
const Library := "lava_snake"
const Motion := "FireBreath"
const Clip := Library + "/" + Motion
const Duration := 1.58
const SourcePhases := [0.0, 0.20, 0.32, 0.40, 0.78, 1.0]
const BreathTimes := [0.0, 0.32, 1.20, 1.34, 1.49, Duration]
const Head := "bip01 head"
# The front edge of the skin weighted to the head, in the small snake's bind pose.
const Snout := Vector3(-1.40, -0.99, 0.36)


static func dispatch(actor: Node3D, request: Dictionary) -> bool:
	if int(request.get("body", 0)) != Body or not is_instance_valid(actor) \
			or actor.kind != "small_snakes" or actor.dead:
		return false
	var classic: bool = request.get("protocol") == "classic"
	var group := int(request.get("action", -1))
	var breath_cue: bool = classic and group == 12 and request.get("frames") == 5 and request.get("repeat_count") == 1 \
			and not request.get("reverse") and not request.get("repeat") and request.get("delay") == 0
	if breath_cue and (actor.native_hue & 0x3fff) in Hues and prepare(actor):
		var entry: Dictionary = actor.entry
		var groups: Dictionary = entry.get("classic_action_categories", {})
		actor.entry = entry.merged({"classic_action_categories": groups.merged({"12": Clip}, true)}, true)
		var accepted: bool = actor.receive_action(request)
		actor.entry = entry
		if accepted:
			actor.animator.speed_scale *= actor.action_remaining / Duration
			actor.action_remaining = Duration
		return accepted
	var attacking: bool = (classic and group in [5, 6]) or (request.get("protocol") == "new" and request.get("type") == 0)
	return attacking and actor.current_clip == Clip and actor.action_remaining > 0.0


static func prepare(actor: Node3D) -> bool:
	var animator: AnimationPlayer = actor.animator
	if animator.has_animation(Clip):
		return true
	if animator.has_animation_library(Library) or not animator.has_animation("Attack") or actor.skeleton.find_bone(Head) < 0:
		return false
	var motion := animator.get_animation("Attack").duplicate() as Animation
	var source_length := motion.length
	motion.length = Duration
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			var phase := motion.track_get_key_time(track, key) / source_length
			motion.track_set_key_time(track, key, breath_time(phase))
	var library := AnimationLibrary.new()
	return library.add_animation(Motion, motion) == OK and animator.add_animation_library(Library, library) == OK


static func breath_time(phase: float) -> float:
	for index in range(1, SourcePhases.size()):
		if phase <= SourcePhases[index]:
			var blend := inverse_lerp(SourcePhases[index - 1], SourcePhases[index], phase)
			return lerpf(BreathTimes[index - 1], BreathTimes[index], blend)
	return Duration


static func origin(actor: Node3D) -> Variant:
	if not is_instance_valid(actor) or actor.dead or actor.current_clip != Clip or actor.action_remaining <= 0.0:
		return null
	var rig: Skeleton3D = actor.skeleton
	var head := rig.find_bone(Head)
	return rig.to_global(rig.get_bone_global_pose(head) * (rig.get_bone_global_rest(head).affine_inverse() * Snout))
