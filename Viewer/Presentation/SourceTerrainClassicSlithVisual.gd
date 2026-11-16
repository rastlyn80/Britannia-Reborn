# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SlithUopGaitVisual.gd"

const Breath := "slith/FireBreath"
const BreathLength := 1.64
const SnoutInRestPose := Vector3(0.028, -1.120, 0.398)
const BreathPacket := {"protocol": "classic", "action": 12, "frames": 5, "repeat_count": 1,
	"reverse": false, "repeat": false, "delay": 0}
const BreathTimes := [0.0, 0.28, 0.72, 1.04, 1.30, 1.49, BreathLength]
const BreathJoints := {
	"bip01 spine1": [0.0, -0.03, -0.14, -0.06, 0.07, 0.03, 0.0],
	"bip01 neck": [0.0, -0.02, -0.19, -0.07, 0.11, 0.05, 0.0],
	"bip01 head": [0.0, -0.02, -0.09, -0.04, 0.07, 0.03, 0.0],
	"bip01 ponytail1": [0.0, 0.0, 0.03, 0.19, 0.29, 0.12, 0.0],
}
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var muzzle_head := -1


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.2, 2.1))
	terrain.skin = skin
	animator.mixer_applied.connect(settle_pose)
	contact.modification_processed.connect(settle_pose)
	prepare_breath()


func prepare_breath() -> void:
	muzzle_head = skeleton.find_bone("bip01 head")
	var jaw := skeleton.find_bone("bip01 ponytail1")
	if muzzle_head < 0 or jaw < 0:
		return
	var idle := animator.get_animation("Idle")
	var motion := idle.duplicate() as Animation
	motion.length = BreathLength
	motion.loop_mode = Animation.LOOP_NONE
	for track in idle.get_track_count():
		var path := idle.track_get_path(track)
		if idle.track_get_type(track) != Animation.TYPE_ROTATION_3D or path.get_subname_count() != 1:
			continue
		var joint := path.get_subname(0)
		if BreathJoints.has(joint):
			fit_breath_track(idle, motion, track, skeleton.find_bone(joint), BreathJoints[joint])
	var library := AnimationLibrary.new()
	library.add_animation("FireBreath", motion)
	animator.add_animation_library("slith", library)
	entry = entry.merged({"grounded_gestures": entry.grounded_gestures + [Breath]}, true)


func fit_breath_track(source: Animation, target: Animation, track: int, bone: int, angles: Array) -> void:
	var rest := skeleton.get_bone_global_rest(bone)
	var right := (rest.basis.inverse() * (skeleton.global_basis.inverse() * global_basis.x)).normalized()
	for key in range(target.track_get_key_count(track) - 1, -1, -1):
		target.track_remove_key(track, key)
	for sample in BreathTimes.size():
		var at: float = BreathTimes[sample]
		var pose := source.rotation_track_interpolate(track, at / BreathLength * source.length)
		target.rotation_track_insert_key(track, at, pose * Quaternion(right, angles[sample]))
	target.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	restore_gesture()
	release_walk_clearance()
	terrain.sample()
	super._physics_process(delta)
	settle_pose()


func settle() -> void:
	if terrain.actor == null or terrain.plane.is_empty():
		super.settle()


func support_peaceful_walk() -> void:
	if terrain.plane.is_empty():
		super.support_peaceful_walk()


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
	if not dead and animator.has_animation(Breath) and BreathPacket.keys().all(func(key: String) -> bool:
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
		fall.plane = {}
		terrain.prepare_collapse()
	return true


func fire_breath_origin() -> Variant:
	if dead or current_clip != Breath or action_remaining <= 0.0 or muzzle_head < 0:
		return null
	return muzzle_point(self)


static func muzzle_point(actor: Node3D) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	var head := rig.find_bone("bip01 head")
	var offset := rig.get_bone_global_rest(head).affine_inverse() * SnoutInRestPose
	return rig.to_global(rig.get_bone_global_pose(head) * offset)


func begin_death_from(source: Node3D) -> float:
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
