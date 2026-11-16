# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/ArchiveGestureVisual.gd"

const Breath := "hydra/FireBreath"
const BreathLength := 1.55
const MouthInSourceRig := Vector3(29.0, -5127.0, 10099.0)
const BreathTimes := [0.0, 0.24, 0.62, 1.30, BreathLength]
const NeckPitch := {
	"bip01 neck": 0.31, "bip01 neck1": 0.47, "bip01 neck2": 0.32,
	"bip01 neck3": -0.22, "bip01 head": -0.43, "bip01 jaw middle head": 0.63,
}
const BreathPacket := {"protocol": "classic", "action": 12, "frames": 5, "repeat_count": 1,
	"reverse": false, "repeat": false, "delay": 0}
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(4.1, 4.1))
	animator.mixer_applied.connect(settle_pose)
	contact.modification_processed.connect(settle_pose)
	prepare_breath()


func prepare_breath() -> void:
	var idle := animator.get_animation("Idle")
	var motion := idle.duplicate() as Animation
	motion.length = BreathLength
	motion.loop_mode = Animation.LOOP_NONE
	for track in idle.get_track_count():
		var channel := idle.track_get_path(track)
		if idle.track_get_type(track) != Animation.TYPE_ROTATION_3D or channel.get_subname_count() != 1:
			continue
		var joint := channel.get_subname(0)
		if not NeckPitch.has(joint):
			continue
		var rest := skeleton.get_bone_global_rest(skeleton.find_bone(joint))
		var right := (rest.basis.inverse() * (skeleton.global_basis.inverse() * global_basis.x)).normalized()
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		for sample in BreathTimes.size():
			var at: float = BreathTimes[sample]
			var pulse: float = [0.0, 0.15, 0.80, 1.0, 0.0][sample]
			var rotation := idle.rotation_track_interpolate(track, at / BreathLength * idle.length)
			motion.rotation_track_insert_key(track, at, rotation * Quaternion(right, pulse * NeckPitch[joint]))
		motion.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	var library := AnimationLibrary.new()
	library.add_animation("FireBreath", motion)
	animator.add_animation_library("hydra", library)
	var supported: Array = entry.get("archive_grounded_gestures", [])
	entry = entry.merged({"archive_grounded_gestures": supported + [Breath]}, true)


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
			contact.enabled = false
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
	var head_rest := rig.get_bone_global_rest(head)
	return rig.to_global(rig.get_bone_global_pose(head) * (head_rest.affine_inverse() * MouthInSourceRig))


func begin_death_from(source: Node3D) -> float:
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
