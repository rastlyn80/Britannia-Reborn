# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Visual := preload("res://Presentation/CreatureVisual.gd")
const Body := 150
const Kind := "sea_serpents_sea_serpent_classic"
const Library := "sea_serpent"
const Motion := "FireBreath"
const Clip := Library + "/" + Motion
const Duration := 1.55
const Head := "bip01 head"
const Jaw := "serpent jaw"
# In the bind rig both jaws meet at the snout. Fit the point just beyond the teeth.
const RestMuzzle := Vector3(0.40, -8.21, 0.02)
const ActionTimes := [0.0, 0.50, 1.30, 1.42, Duration]
const AttackPhases := [0.0, 0.22, 0.55, 0.77, 1.0]


static func dispatch(visual: Node3D, request: Dictionary) -> bool:
	if not visual is Visual or visual.native_body != Body or visual.kind != Kind or request.get("body") != Body:
		return false
	if is_melee(request) and playing(visual):
		return true
	if not is_windup(request) or visual.dead or not prepare(visual):
		return false
	var entry: Dictionary = visual.entry
	var groups: Dictionary = entry.get("classic_action_categories", {})
	visual.entry = entry.merged({"classic_action_categories": groups.merged({"12": Clip}, true)}, true)
	var accepted: bool = visual.receive_action(request)
	visual.entry = entry
	if accepted:
		visual.animator.speed_scale *= visual.action_remaining / Duration
		visual.action_remaining = Duration
	return accepted


static func is_windup(request: Dictionary) -> bool:
	return request.get("protocol") == "classic" and request.get("action") == 12 and request.get("frames") == 5 \
		and request.get("repeat_count") == 1 and request.get("reverse") == false \
		and request.get("repeat") == false and request.get("delay") == 0


static func is_melee(request: Dictionary) -> bool:
	return (request.get("protocol") == "classic" and request.get("action") in [5, 6]) \
		or (request.get("protocol") == "new" and request.get("type") == 0)


static func prepare(visual: Visual) -> bool:
	var animator := visual.animator
	if animator.has_animation(Clip):
		return true
	if animator.has_animation_library(Library) or not animator.has_animation("Attack2") \
			or visual.skeleton.find_bone(Head) < 0 or visual.skeleton.find_bone(Jaw) < 0:
		return false
	# Both client profiles retain the jaw-opening Classic second attack.
	var motion := animator.get_animation("Attack2").duplicate() as Animation
	var original_length := motion.length
	motion.length = Duration
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			var phase := motion.track_get_key_time(track, key) / original_length
			motion.track_set_key_time(track, key, breath_time(phase))
	var library := AnimationLibrary.new()
	return library.add_animation(Motion, motion) == OK and animator.add_animation_library(Library, library) == OK


static func breath_time(phase: float) -> float:
	for index in range(1, AttackPhases.size()):
		if phase <= AttackPhases[index]:
			var blend := inverse_lerp(AttackPhases[index - 1], AttackPhases[index], phase)
			return lerpf(ActionTimes[index - 1], ActionTimes[index], blend)
	return Duration


static func playing(actor: Node3D) -> bool:
	return is_instance_valid(actor) and actor.current_clip == Clip and not actor.dead and actor.action_remaining > 0.0


static func origin(actor: Node3D) -> Variant:
	if not actor is Visual or not playing(actor):
		return null
	var rig: Skeleton3D = actor.skeleton
	var head := rig.find_bone(Head)
	var jaw := rig.find_bone(Jaw)
	# Follow the centre of the opening between the upper and lower jaws.
	var upper := rig.get_bone_global_pose(head) * (rig.get_bone_global_rest(head).affine_inverse() * RestMuzzle)
	var lower := rig.get_bone_global_pose(jaw) * (rig.get_bone_global_rest(jaw).affine_inverse() * RestMuzzle)
	return rig.to_global(upper.lerp(lower, 0.5))
