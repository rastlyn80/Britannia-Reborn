# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Library := "hell_cat"
const Motion := "FireBreath"
const Clip := Library + "/" + Motion
const Duration := 1.58
const Head := "bip01 head"
const Neck := "bip01 neck"
const Cat := preload("res://Presentation/CatActionsVisual.gd")
const CatBody := 201
const PredatorBody := 127
const CatMouth := Vector3(0.0, 1.29, 0.04)
const PredatorMouth := Vector3(0.034, 0.196, 0.0)
const PoseTimes := [0.0, 0.34, 0.69, 1.03, 1.30, 1.42, Duration]
const HeadAngles := [0.0, 0.14, 0.20, 0.22, 0.03, -0.02, 0.0]
const NeckAngles := [0.0, -0.05, -0.15, -0.19, 0.19, 0.10, 0.0]


static func dispatch(actor: Node3D, request: Dictionary) -> bool:
	var body := int(request.get("body", 0))
	if body not in [CatBody, PredatorBody] or not is_instance_valid(actor) or actor.dead:
		return false
	var classic: bool = request.get("protocol") == "classic"
	var group := int(request.get("action", -1))
	# The regular cat's terrain renderer preserves the compatibility Alert rule.
	# Use a separate category for this longer action on the World route.
	if actor.current_clip == Clip and actor.action_remaining > 0.0:
		if (classic and group in [5, 6]) or (request.get("protocol") == "new" and request.get("type") == 0):
			return true
	var hell_cat: bool = (body == CatBody and actor is Cat and (actor.native_hue & 0x3fff) in Cat.HellCatHues) \
		or (body == PredatorBody and actor.kind == "felines_predator_hellcat")
	if not hell_cat or not classic or group != 12 or request.get("frames") != 5 or request.get("repeat_count") != 1 \
			or request.get("reverse") or request.get("repeat") or request.get("delay") != 0 or not prepare(actor, body):
		return false
	var entry: Dictionary = actor.entry
	var groups: Dictionary = entry.get("classic_action_categories", {})
	actor.entry = entry.merged({"classic_action_categories": groups.merged({"4": Clip}, true)}, true)
	var accepted: bool = actor.receive_action(request.merged({"action": 4}, true))
	actor.entry = entry
	if accepted:
		actor.set_meta("native_action", request.duplicate(true))
		actor.animator.speed_scale *= actor.action_remaining / Duration
		actor.action_remaining = Duration
	return accepted


static func prepare(actor: Node3D, body: int) -> bool:
	var animator: AnimationPlayer = actor.animator
	if animator.has_animation(Clip):
		return true
	if animator.has_animation_library(Library) or not animator.has_animation("Idle"):
		return false
	var rig: Skeleton3D = actor.skeleton
	var motion := animator.get_animation("Idle").duplicate() as Animation
	var source_length := motion.length
	motion.length = Duration
	motion.loop_mode = Animation.LOOP_NONE
	var axis := Vector3.BACK if body == CatBody else Vector3.LEFT
	for track in motion.get_track_count():
		var count := motion.track_get_key_count(track)
		var keys := range(count) if source_length > Duration else range(count - 1, -1, -1)
		for key in keys:
			motion.track_set_key_time(track, key, motion.track_get_key_time(track, key) / source_length * Duration)
	for joint: String in [Head, Neck]:
		var bone := rig.find_bone(joint)
		if bone < 0:
			return false
		var track := motion.find_track(NodePath(str(motion.track_get_path(0)).get_slice(":", 0) + ":" + joint),
			Animation.TYPE_ROTATION_3D)
		if track < 0:
			return false
		var local_axis := (rig.get_bone_global_rest(bone).basis.inverse() * axis).normalized()
		var angles := HeadAngles if joint == Head else NeckAngles
		var rotations: Array[Quaternion] = []
		for time: float in PoseTimes:
			rotations.append(motion.rotation_track_interpolate(track, time))
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		for key in PoseTimes.size():
			motion.track_insert_key(track, PoseTimes[key], (rotations[key] * Quaternion(local_axis, angles[key])).normalized())
	var library := AnimationLibrary.new()
	return library.add_animation(Motion, motion) == OK and animator.add_animation_library(Library, library) == OK


static func origin(actor: Node3D) -> Variant:
	if not is_instance_valid(actor) or actor.dead or actor.current_clip != Clip or actor.action_remaining <= 0.0:
		return null
	var rig: Skeleton3D = actor.skeleton
	var head := rig.find_bone(Head)
	var offset := CatMouth if actor.native_body == CatBody else PredatorMouth
	return rig.to_global(rig.get_bone_global_pose(head) * offset)
