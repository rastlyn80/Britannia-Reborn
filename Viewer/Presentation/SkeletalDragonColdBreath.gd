# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Body := 104
const Hue := 0x480
const Library := "skeletal_dragon"
const Motion := "ColdBreath"
const Clip := Library + "/" + Motion
const Duration := 1.58
const Head := "bip01 head"
const Jaw := "box14"
# Bind-space points at the upper and lower ends of the original skinned snout.
const UpperTip := Vector3(0.0, -4.98, 1.71)
const LowerTip := Vector3(0.0, -4.85, 1.49)
const SourcePhases := [0.0, 0.20, 0.35, 0.43, 0.80, 1.0]
const BreathTimes := [0.0, 0.29, 0.66, 1.31, 1.48, Duration]


static func dispatch(actor: Node3D, request: Dictionary) -> bool:
	if int(request.get("body", 0)) != Body or not is_instance_valid(actor) \
			or actor.kind != "dragons_dragon_skeletal" or actor.dead:
		return false
	var classic: bool = request.get("protocol") == "classic"
	var group := int(request.get("action", -1))
	if actor.current_clip == Clip and actor.action_remaining > 0.0:
		if (classic and group in [4, 5, 6]) or (request.get("protocol") == "new" and request.get("type") == 0):
			return true
	if not classic or group != 12 or request.get("frames") != 5 or request.get("repeat_count") != 1 \
			or request.get("reverse") or request.get("repeat") or request.get("delay") != 0 or not prepare(actor):
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
	if animator.has_animation_library(Library) or not animator.has_animation("Attack2") \
			or actor.skeleton.find_bone(Head) < 0 or actor.skeleton.find_bone(Jaw) < 0:
		return false
	var motion := animator.get_animation("Attack2").duplicate() as Animation
	var source_length := motion.length
	motion.length = Duration
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			var phase := motion.track_get_key_time(track, key) / source_length
			motion.track_set_key_time(track, key, breath_time(phase))
	var library := AnimationLibrary.new()
	if library.add_animation(Motion, motion) != OK or animator.add_animation_library(Library, library) != OK:
		return false
	var grounded: Array = actor.entry.get("archive_grounded_gestures", [])
	actor.entry = actor.entry.merged({"archive_grounded_gestures": grounded + [Clip]}, true)
	return true


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
	var jaw := rig.find_bone(Jaw)
	var upper := posed_point(rig, head, UpperTip)
	var lower := posed_point(rig, jaw, LowerTip)
	var forward := (upper - rig.get_bone_global_pose(head).origin).normalized()
	return rig.to_global(upper.lerp(lower, 0.40) + forward * 0.15)


static func posed_point(rig: Skeleton3D, bone: int, bind_point: Vector3) -> Vector3:
	return rig.get_bone_global_pose(bone) * (rig.get_bone_global_rest(bone).affine_inverse() * bind_point)
