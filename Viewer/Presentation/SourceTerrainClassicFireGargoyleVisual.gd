# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/FireGargoyleUopVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
const Breath := "fire_gargoyle/FireBreath"
const BreathLength := 1.55
const MouthOffset := Vector3(0.0, .067, .163)
const BreathTimes := [0.0, .35, .68, 1.03, 1.30, BreathLength]
const BreathPacket := {"protocol": "classic", "action": 12, "frames": 5, "repeat_count": 1,
	"reverse": false, "repeat": false, "delay": 0}
const Pitch := {
	"bip01 spine1": [0.0, -.18, -.15, .05, .12, 0.0],
	"bip01 spine2": [0.0, -.14, -.10, .10, .17, 0.0],
	"bip01 neck": [0.0, -.11, -.05, .17, .23, 0.0],
	"bip01 head": [0.0, -.08, .04, -.18, -.31, 0.0],
}
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.7, 1.8))
	animator.mixer_applied.disconnect(fall.settle.bind(self))
	animator.mixer_applied.connect(settle_pose)
	contact.modification_processed.connect(settle_pose)
	prepare_breath()


func prepare_breath() -> void:
	var relative := skeleton.global_basis.inverse() * global_basis
	var idle := animator.get_animation("Idle")
	var motion := idle.duplicate() as Animation
	motion.length = BreathLength
	motion.loop_mode = Animation.LOOP_NONE
	for track in idle.get_track_count():
		var path := idle.track_get_path(track)
		if idle.track_get_type(track) != Animation.TYPE_ROTATION_3D or path.get_subname_count() != 1:
			continue
		var joint := path.get_subname(0)
		if not Pitch.has(joint):
			continue
		var rest := skeleton.get_bone_global_rest(skeleton.find_bone(joint))
		var right := (rest.basis.inverse() * relative.x).normalized()
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		for sample in BreathTimes.size():
			var at: float = BreathTimes[sample]
			var pose := idle.rotation_track_interpolate(track, at / BreathLength * idle.length)
			motion.rotation_track_insert_key(track, at, pose * Quaternion(right, Pitch[joint][sample]))
		motion.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	var library := AnimationLibrary.new()
	library.add_animation("FireBreath", motion)
	animator.add_animation_library("fire_gargoyle", library)
	var grounded: Array = entry.get("archive_grounded_gestures", [])
	entry = entry.merged({"archive_grounded_gestures": grounded + [Breath]}, true)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	settle_pose()


func settle_pose() -> void:
	if terrain.plane.is_empty():
		return
	if not dead:
		terrain.settle_live(.0005)
	elif animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
		terrain.settle(self)


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
	if not dead and BreathPacket.keys().all(func(key: String) -> bool:
			return request.get(key) == BreathPacket[key]):
		var original := entry
		var categories: Dictionary = original.classic_action_categories
		entry = original.merged({"classic_action_categories": categories.merged({"12": Breath}, true)}, true)
		var accepted := super.receive_action(request)
		entry = original
		if accepted:
			animator.speed_scale = action_remaining / BreathLength
			action_remaining = BreathLength
		return accepted
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func fire_breath_origin() -> Variant:
	if dead or current_clip != Breath or action_remaining <= 0.0:
		return null
	return mouth_position(self)


static func mouth_position(actor: Node3D) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	var head := rig.find_bone("bip01 head")
	var rest := rig.get_bone_global_rest(head)
	var relative := rig.global_basis.inverse() * actor.global_basis
	var offset := rest.basis.inverse() * (relative * MouthOffset)
	return rig.to_global(rig.get_bone_global_pose(head) * offset)


func begin_death_from(source: Node3D) -> float:
	terrain.split = source.terrain.split
	var previous: RefCounted = source.terrain
	if not source.dead:
		model.transform = source.model.transform
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	return terrain.begin_from_source(self, source, previous, false)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
