# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceLivingStepQuadrupedVisual.gd"

const Breath := "hell_hound/FireBreath"
const BreathLength := 2.05
const BreathPacket := {"protocol": "classic", "action": 12, "frames": 5, "repeat_count": 1,
	"reverse": false, "repeat": false, "delay": 0}

var head := -1
var jaw := -1
var upper_lip := Vector3.ZERO
var lower_lip := Vector3.ZERO


func _ready() -> void:
	super._ready()
	head = skeleton.find_bone("bip01 head")
	jaw = skeleton.find_bone("bip01 jaw")
	# The forward centreline vertices of the recovered upper and lower lips.
	upper_lip = bone_local_point(head, Vector3(0.0, .745, .914))
	lower_lip = bone_local_point(jaw, Vector3(0.0, .713, .908))
	var idle := animator.get_animation("Idle")
	var breath := idle.duplicate() as Animation
	breath.length = BreathLength
	breath.loop_mode = Animation.LOOP_NONE
	# Keep the source idle body and animate its existing jaw and neck chain.
	var times := PackedFloat32Array([0.0, .32, .72, 1.07, 1.30, 1.57, 2.05])
	pitch_track(idle, breath, head, times, PackedFloat32Array([0.0, -.05, -.19, -.12, .10, .07, 0.0]))
	pitch_track(idle, breath, jaw, times, PackedFloat32Array([0.0, .03, .10, .24, .52, .30, 0.0]))
	var library := AnimationLibrary.new()
	library.add_animation("FireBreath", breath)
	animator.add_animation_library("hell_hound", library)


func pitch_track(source: Animation, target: Animation, bone: int, times: PackedFloat32Array,
		angles: PackedFloat32Array) -> void:
	var suffix := ":" + str(skeleton.get_bone_name(bone))
	for track in source.get_track_count():
		if source.track_get_type(track) != Animation.TYPE_ROTATION_3D or not str(source.track_get_path(track)).ends_with(suffix):
			continue
		var rest := skeleton.get_bone_global_rest(bone)
		var right := (rest.basis.inverse() * (skeleton.global_basis.inverse() * global_basis.x)).normalized()
		for key in range(target.track_get_key_count(track) - 1, -1, -1):
			target.track_remove_key(track, key)
		for index in times.size():
			var pose := source.rotation_track_interpolate(track, times[index] / BreathLength * source.length)
			target.rotation_track_insert_key(track, times[index], pose * Quaternion(right, angles[index]))
		target.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		return


func bone_local_point(bone: int, point: Vector3) -> Vector3:
	return skeleton.get_bone_global_rest(bone).affine_inverse() * skeleton.to_local(to_global(point))


func receive_action(request: Dictionary) -> bool:
	if dead or not BreathPacket.keys().all(func(key: String) -> bool: return request.get(key) == BreathPacket[key]):
		return super.receive_action(request)
	current_clip = Breath
	action_remaining = BreathLength
	contact.enabled = true
	animator.speed_scale = 1.0
	animator.play(Breath, .12)
	animator.seek(0.0, false)
	set_meta("native_action", request.duplicate(true))
	return true


func fire_breath_origin() -> Variant:
	if dead or current_clip != Breath or action_remaining <= 0.0:
		return null
	var upper := skeleton.get_bone_global_pose(head) * upper_lip
	var lower := skeleton.get_bone_global_pose(jaw) * lower_lip
	return skeleton.to_global(upper.lerp(lower, .5)) + global_basis.z.normalized() * .025
