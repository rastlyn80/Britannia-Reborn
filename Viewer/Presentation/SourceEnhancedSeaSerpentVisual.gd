# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureVisual.gd"

const Timing := preload("res://Presentation/HumanActions.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Groups := {
	0: "SeaCombatSwim", 1: "SeaCombatIdle", 2: "Death", 3: "Death2", 4: "SeaSnap", 5: "SeaDiveStrike",
	10: "SeaRecoil", 15: "SeaGuard", 22: "Walk", 24: "Run", 25: "SeaQuietIdle", 26: "SeaQuietFidget",
	27: "SeaDeepFidget", 28: "SeaAlert",
}
const Falls := ["Death", "Death2"]
var combat := false
var flags_known := false
var use_side_fall := false
var classic_death: Animation
var transfer_pose: Array[Transform3D] = []
var transfer_start := 0.
var transfer_duration := 0.


func _ready() -> void:
	super._ready()
	# A prepared scene can retain the manual clock used by its baker.
	if animator.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	classic_death = animator.get_animation("Death")
	var library := animator.get_animation_library("")
	library.add_animation("Death2", library.get_animation("SeaRollFall"))
	animator.mixer_applied.connect(apply_transfer)


func set_native_combat_flags(flags: int) -> void:
	var entering := flags_known and not combat and (flags & 0x40) != 0
	flags_known = flags >= 0
	combat = flags_known and (flags & 0x40) != 0
	if entering and not dead and action_remaining <= 0.:
		start_clip(Groups[28], {})


func play_gait(moving: bool, speed: float) -> void:
	if dead or action_remaining > 0.:
		return
	var locomotion: Dictionary = entry.get("locomotion", {})
	var running := moving and speed > float(locomotion.get("run_threshold_mps", 3.6))
	var group := 24 if running else (0 if combat else 22) if moving else (1 if combat else 25)
	var clip: String = Groups[group]
	if current_clip != clip:
		current_clip = clip
		play(clip, .18)
	var cadence := float(locomotion.get("run_reference_mps", 5.5) if running else locomotion.get("walk_reference_mps", 1.8))
	animator.speed_scale = clampf(speed / maxf(.01, cadence), .65, 1.65) if moving else 1.


static func group_for(type: int, subaction: int, variation: int, war: bool) -> int:
	if variation < 0 or variation > 127:
		return -1
	match type:
		0:
			if subaction in [1, 2, 9]:
				return 4
			var choices := [4, 5, 4] if subaction == 0 else [4, 5, 4, 4, 4, 4]
			return choices[variation % choices.size()]
		2:
			return 15
		3:
			return 2 + variation % 2
		4:
			return 10
		5:
			return 27 if war and variation % 2 == 1 else 26
		8:
			return 28
		11:
			return 4
		14, 15:
			return 25
	return -1


func receive_enhanced_action(request: Dictionary, flags: int) -> bool:
	if dead or flags < 0 or request.get("protocol") != "new" or int(request.get("body", 0)) != native_body:
		return false
	var group := group_for(int(request.get("type", -1)), int(request.get("subaction", -1)),
		int(request.get("variation", -1)), (flags & 0x40) != 0)
	if not Groups.has(group):
		return false
	if group in [2, 3]:
		select_side_fall(group == 2)
		dead = true
	start_clip(Groups[group], request)
	return true


func start_clip(clip: String, request: Dictionary) -> void:
	current_clip = clip
	contact.enabled = false
	var length := animator.get_animation(clip).length
	action_remaining = Timing.duration(request, length)
	animator.speed_scale = 1.
	animator.play(clip, .10, length / action_remaining)
	animator.seek(0., false)
	if not request.is_empty():
		set_meta("native_action", request.duplicate(true))


func select_side_fall(enabled: bool) -> void:
	if use_side_fall == enabled:
		return
	var library := animator.get_animation_library("")
	var selected := library.get_animation("SeaSideFall") if enabled else classic_death
	library.remove_animation("Death")
	library.add_animation("Death", selected)
	use_side_fall = enabled


func begin_death_from(source: Node3D) -> float:
	var continuing: bool = source.dead and source.current_clip in Falls
	select_side_fall(continuing and source.use_side_fall)
	current_clip = source.current_clip if continuing else "Death"
	var time: float = source.animator.current_animation_position if continuing else 0.
	var speed: float = absf(source.animator.get_playing_speed()) if continuing else 1.
	if is_zero_approx(speed):
		speed = 1.
	global_transform = source.global_transform
	animator.play(current_clip, 0., speed)
	animator.advance(0.)
	var length := animator.current_animation_length
	transfer_start = clampf(time, 0., length)
	transfer_duration = minf(.08 * speed, length - transfer_start)
	if transfer_duration > 0.:
		for bone in source.skeleton.get_bone_count():
			transfer_pose.append(source.skeleton.get_bone_pose(bone))
	animator.seek(transfer_start, true)
	action_remaining = (length - transfer_start) / speed
	return action_remaining


func apply_transfer() -> void:
	if transfer_pose.is_empty():
		return
	var phase := clampf((animator.current_animation_position - transfer_start) / transfer_duration, 0., 1.)
	if phase >= 1.:
		transfer_pose.clear()
		return
	for bone in transfer_pose.size():
		skeleton.set_bone_pose(bone, transfer_pose[bone].interpolate_with(skeleton.get_bone_pose(bone), phase))
	skeleton.force_update_all_bone_transforms()


func corpse_snapshot_floor() -> float:
	return corpse_waterline_offset()


func corpse_waterline_offset() -> float:
	var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var skin := Ground.skin_points(mesh, skeleton)
	return Ground.minimum_plane_gap(skin, skeleton, global_transform.affine_inverse() * skeleton.global_transform,
		Vector3.ZERO, Vector3.UP)
