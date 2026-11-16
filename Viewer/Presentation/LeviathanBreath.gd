# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Body := 77
const BodyHue := 0x481
const ProjectileHue := 0x1ed
const Library := "leviathan"
const Motion := "ColdBreath"
const Clip := Library + "/" + Motion
const Duration := 1.62
const Neck := "bip01 neck"
const Head := "bip01 head"
# The forward lip below the head's crown spikes in the original skin.
const Muzzle := Vector3(-0.004, 2.87, -0.55)
const MotionTimes := [0.0, 0.35, 0.70, 1.03, 1.30, 1.43, Duration]
const NeckAngles := [0.0, -0.09, -0.19, -0.23, 0.26, 0.12, 0.0]


static func dispatch(actor: Node3D, request: Dictionary) -> bool:
	if int(request.get("body", 0)) != Body or not is_instance_valid(actor) or actor.kind != "krakens_kraken" or actor.dead:
		return false
	var classic: bool = request.get("protocol") == "classic"
	var group := int(request.get("action", -1))
	if actor.current_clip == Clip and actor.action_remaining > 0.0:
		if (classic and group in [4, 5, 6]) or (request.get("protocol") == "new" and request.get("type") == 0):
			return true
	if (actor.native_hue & 0x3fff) != BodyHue or not classic or group != 12 or request.get("frames") != 5 \
			or request.get("repeat_count") != 1 or request.get("reverse") or request.get("repeat") \
			or request.get("delay") != 0 or not prepare(actor):
		return false
	var entry: Dictionary = actor.entry
	var groups: Dictionary = entry.get("classic_action_categories", {})
	actor.entry = entry.merged({"classic_action_categories": groups.merged({"12": Clip}, true)}, true)
	var accepted: bool = actor.receive_action(request)
	actor.entry = entry
	if accepted:
		actor.animator.speed_scale *= actor.action_remaining / Duration
		actor.action_remaining = Duration
	return accepted


static func prepare(actor: Node3D) -> bool:
	var animator: AnimationPlayer = actor.animator
	if animator.has_animation(Clip):
		return true
	if animator.has_animation_library(Library) or not animator.has_animation("Cast"):
		return false
	var rig: Skeleton3D = actor.skeleton
	var neck := rig.find_bone(Neck)
	if neck < 0 or rig.find_bone(Head) < 0:
		return false
	var source := animator.get_animation("Cast")
	var motion := source.duplicate() as Animation
	motion.length = Duration
	motion.loop_mode = Animation.LOOP_NONE
	var axis := (rig.get_bone_global_rest(neck).basis.inverse() * Vector3.RIGHT).normalized()
	for track in motion.get_track_count():
		if motion.track_get_type(track) == Animation.TYPE_ROTATION_3D and str(motion.track_get_path(track)).ends_with(":" + Neck):
			for key in range(motion.track_get_key_count(track) - 1, -1, -1):
				motion.track_remove_key(track, key)
			for key in MotionTimes.size():
				var pose := source.rotation_track_interpolate(track, MotionTimes[key] / Duration * source.length)
				motion.track_insert_key(track, MotionTimes[key], (pose * Quaternion(axis, NeckAngles[key])).normalized())
			motion.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
			var library := AnimationLibrary.new()
			return library.add_animation(Motion, motion) == OK and animator.add_animation_library(Library, library) == OK
	return false


static func origin(actor: Node3D) -> Variant:
	if not is_instance_valid(actor) or actor.dead or actor.current_clip != Clip or actor.action_remaining <= 0.0:
		return null
	var rig: Skeleton3D = actor.skeleton
	var head := rig.find_bone(Head)
	return rig.to_global(rig.get_bone_global_pose(head) * (rig.get_bone_global_rest(head).affine_inverse() * Muzzle))
