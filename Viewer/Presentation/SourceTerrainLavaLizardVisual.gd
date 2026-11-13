# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
const Breath := "lava_lizard/FireBreath"
const BreathLength := 2.05
const BreathPacket := {"protocol": "classic", "action": 12, "frames": 5, "repeat_count": 1,
	"reverse": false, "repeat": false, "delay": 0}

var muzzle := -1
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.5, 2.2))
	contact.modification_processed.connect(settle_living)
	animator.mixer_applied.connect(settle_fall)
	muzzle = skeleton.find_bone("cp_emit_mouth")
	assert(muzzle >= 0)
	var idle := animator.get_animation("Idle")
	var breath := idle.duplicate() as Animation
	breath.length = BreathLength
	breath.loop_mode = Animation.LOOP_NONE
	var times := PackedFloat32Array([0.0, .35, .76, 1.12, 1.30, 1.58, 2.05])
	pitch_track(idle, breath, "bip01 neck1", times, PackedFloat32Array([0.0, -.05, -.13, -.12, .08, .05, 0.0]))
	pitch_track(idle, breath, "bip01 head", times, PackedFloat32Array([0.0, -.04, -.15, -.07, .19, .10, 0.0]))
	var library := AnimationLibrary.new()
	library.add_animation("FireBreath", breath)
	animator.add_animation_library("lava_lizard", library)


func pitch_track(source: Animation, target: Animation, name: String, times: PackedFloat32Array,
		angles: PackedFloat32Array) -> void:
	var bone := skeleton.find_bone(name)
	assert(bone >= 0)
	var track := -1
	for index in source.get_track_count():
		if source.track_get_type(index) == Animation.TYPE_ROTATION_3D and str(source.track_get_path(index)).ends_with(":" + name):
			track = index
			break
	assert(track >= 0)
	var rest := skeleton.get_bone_global_rest(bone)
	var right := (rest.basis.inverse() * (skeleton.global_basis.inverse() * global_basis.x)).normalized()
	for key in range(target.track_get_key_count(track) - 1, -1, -1):
		target.track_remove_key(track, key)
	for index in times.size():
		var pose := source.rotation_track_interpolate(track, times[index] / BreathLength * source.length)
		target.rotation_track_insert_key(track, times[index], pose * Quaternion(right, angles[index]))
	target.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)


func receive_action(request: Dictionary) -> bool:
	if dead or not BreathPacket.keys().all(func(key: String) -> bool: return request.get(key) == BreathPacket[key]):
		if not super.receive_action(request):
			return false
		if dead:
			terrain.prepare_collapse()
		return true
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
	return skeleton.to_global(skeleton.get_bone_global_pose(muzzle).origin)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	contact.enabled = not terrain.split
	super._physics_process(delta)
	if terrain.split:
		var up: Vector3 = (global_basis.inverse() * terrain.plane.normal).normalized()
		model.basis = (Basis(Quaternion(Vector3.UP, up)) * source_model_basis).scaled_local(model.scale)
		settle_living()


func settle_living() -> void:
	terrain.settle_live(.0005)


func settle_fall() -> void:
	if dead:
		terrain.settle(self)


func begin_death_from(source: Node3D) -> float:
	var previous: RefCounted = source.terrain
	terrain.split = previous.split
	if not source.dead:
		model.transform = source.model.transform
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	return terrain.begin_from_source(self, source, previous, false)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
