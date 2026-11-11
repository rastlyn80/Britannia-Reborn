# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/BaseHorseVisual.gd"
## Optional Enhanced actions for ordinary horse bodies on the live saddle rig.

const Motion := preload("res://Presentation/DappleHorseMotion.gd")
const Timing := preload("res://Presentation/HumanActions.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Fall := preload("res://Presentation/CreatureFallPlayback.gd")

static var animations_by_scene: Dictionary = {}
static var enhanced_ordinary_horses := false
var fall := Fall.new()
var fitted_group := -1
var fitted_library := false


func fitted_enabled() -> bool:
	return enhanced_ordinary_horses and visual_path.is_empty() and supports_fitted_identity(native_body, native_mount_item)


static func supports_fitted_identity(body: int, item: int) -> bool:
	return Motion.BODIES.has(body) and (item == 0 or item == int(BODIES[body]))


func install_fitted_library() -> void:
	var path := model.scene_file_path
	var library := animator.get_animation_library("")
	if animations_by_scene.has(path):
		for name: String in animations_by_scene[path]:
			library.add_animation(name, animations_by_scene[path][name])
	else:
		Motion.install(animator, skeleton)
		if not path.is_empty():
			var clips := {}
			for descriptor: Array in Motion.FITS.values():
				clips[descriptor[0]] = library.get_animation(descriptor[0])
			animations_by_scene[path] = clips
	fitted_library = true
	animator.mixer_applied.connect(settle_fitted_action)


func apply_identity(body: int, hue: int, item: int = 0) -> void:
	if model != null and (body != native_body or item != native_mount_item) and fitted_group >= 0:
		clear_fitted_support()
		dead = false
		contact.enabled = true
		action_remaining = 0.
		current_clip = "idle"
		animator.play(current_clip, .12)
	super.apply_identity(body, hue, item)
	if not is_node_ready() or model == null:
		return
	if fitted_enabled():
		if not fitted_library:
			install_fitted_library()
		if not animator.has_animation("Death"):
			var library := animator.get_animation_library("")
			# Static catalogue entry. The lower-case Classic action stays available.
			library.add_animation("Death", library.get_animation(Motion.FITS[2][0]))
	elif fitted_library and animator.has_animation("Death"):
		animator.get_animation_library("").remove_animation("Death")


func receive_enhanced_action(request: Dictionary, flags: int) -> bool:
	if not fitted_enabled():
		return false
	var action := Motion.select_action(request, native_body, flags)
	if action.is_empty() or (dead and not action.death):
		return false
	begin_fitted_action(action.group, action.clip, action.death, request)
	set_meta("native_action", request.duplicate(true))
	return true


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if fitted_group >= 0:
		clear_fitted_support()
	return true


func begin_fitted_action(group: int, clip: String, falling: bool, request: Dictionary) -> void:
	clear_fitted_support()
	fitted_group = group
	current_clip = clip
	dead = falling
	contact.enabled = not Motion.FITS.has(group)
	if not contact.enabled:
		fall.remember_floor(self, fall.floor_under(self))
	var length := animator.get_animation(clip).length
	action_remaining = Timing.duration(request, length)
	animator.speed_scale = 1.
	animator.play(clip, .12, length / action_remaining)
	set_meta("enhanced_horse_group", group)


func clear_fitted_support() -> void:
	model.position -= fall.shift
	fall.shift = Vector3.ZERO
	fall.plane.clear()
	fall.blend_pose.clear()
	fitted_group = -1


func _process(delta: float) -> void:
	if not Motion.FITS.has(fitted_group):
		super._process(delta)
		return
	if action_remaining <= 0.:
		return
	action_remaining = maxf(0., action_remaining - delta)
	if action_remaining > 0.:
		return
	if dead:
		animator.seek(animator.current_animation_length, true)
		animator.pause()
		settle_fitted_action()
	else:
		clear_fitted_support()
		contact.enabled = true


func settle_fitted_action() -> void:
	if fall.plane.is_empty():
		return
	if dead:
		fall.settle(self)
		return
	model.position -= fall.shift
	skeleton.force_update_all_bone_transforms()
	var support := fall.plane
	var gap := Ground.minimum_plane_gap(fall.skin, skeleton, skeleton.global_transform, support.position, support.normal)
	var prior := model.position
	model.global_position += Vector3.UP * (.002 - gap) / float(support.normal.y)
	fall.shift = model.position - prior


func begin_native_fall(source: Node3D) -> float:
	global_transform = source.global_transform
	model.transform = source.model.transform
	model.position -= source.fall.shift
	contact.enabled = false
	reins.visible = false
	var continuing: bool = source.dead and source.fitted_group in [2, 3]
	fitted_group = source.fitted_group if continuing else 2
	current_clip = Motion.FITS[fitted_group][0]
	dead = true
	var support: Dictionary = source.fall.plane if continuing and not source.fall.plane.is_empty() else fall.floor_under(source)
	fall.remember_floor(self, support.duplicate())
	var time: float = source.animator.current_animation_position if continuing else 0.
	var speed: float = absf(source.animator.get_playing_speed()) if continuing else 1.
	if is_zero_approx(speed):
		speed = 1.
	var length := animator.get_animation(current_clip).length
	fall.blend_start = time
	fall.blend_length = minf(.12 * speed, length - time)
	if fall.blend_length > 0.:
		for bone in source.skeleton.get_bone_count():
			fall.blend_pose.append(source.skeleton.get_bone_pose(bone))
		var root_bone := skeleton.find_bone("root")
		var root_pose: Transform3D = fall.blend_pose[root_bone]
		var displayed_shift: Vector3 = source.skeleton.global_position - skeleton.global_position
		root_pose.origin += skeleton.global_basis.inverse() * displayed_shift
		fall.blend_pose[root_bone] = root_pose
	animator.play(current_clip, 0., speed)
	animator.advance(0.)
	animator.seek(time, true)
	settle_fitted_action()
	action_remaining = maxf(0., length - time) / speed
	return action_remaining


func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self) if not fall.plane.is_empty() else INF
