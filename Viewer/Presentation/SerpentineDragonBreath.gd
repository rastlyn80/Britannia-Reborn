# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Body := 103
const Kind := "dragons_dragon_asian"
const Library := "serpentine"
const Motion := "FireBreath"
const Clip := Library + "/" + Motion
const Duration := 1.55
const MuzzleBone := "box02"
# The narrow skin strip weighted to box02 reaches the centre of the snout.
const MuzzleInBindPose := Vector3(0.53, -6.17, 2.39)
const SourcePhases := [0.0, 0.20, 0.43, 0.65, 0.76, 1.0]
const BreathTimes := [0.0, 0.29, 0.67, 1.30, 1.39, Duration]


static func play(actor: Node3D, request: Dictionary) -> bool:
	if actor.kind != Kind or actor.dead or not prepare(actor):
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
	if animator.has_animation_library(Library) or not animator.has_animation("Attack") \
			or actor.skeleton.find_bone(MuzzleBone) < 0:
		return false
	var motion := animator.get_animation("Attack").duplicate() as Animation
	var source_length := motion.length
	motion.length = Duration
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		# Retiming moves keys later. Start at the end to keep later keys intact.
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
	if not is_instance_valid(actor) or actor.current_clip != Clip or actor.dead or actor.action_remaining <= 0.0:
		return null
	var rig: Skeleton3D = actor.skeleton
	var bone := rig.find_bone(MuzzleBone)
	if bone < 0:
		return null
	var offset := rig.get_bone_global_rest(bone).affine_inverse() * MuzzleInBindPose
	return rig.to_global(rig.get_bone_global_pose(bone) * offset)
