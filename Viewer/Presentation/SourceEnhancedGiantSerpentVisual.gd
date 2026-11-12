# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SmallSnakeVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Timing := preload("res://Presentation/HumanActions.gd")
const Surface := "SerpentSurface"
const Groups := {
	0: "SerpentCombatSlither", 1: "Idle", 2: "Death2", 3: "Death", 4: "SerpentUncoilStrike", 10: "Hit",
	11: "Pillage", 15: "LowNeckRecoil", 22: "Walk", 23: Surface, 24: "Run",
	25: "SerpentQuietIdle", 26: "SerpentLowWatch", 27: "SerpentRaisedCoil", 28: "SerpentCoilAlert",
}
const IdleGestures := ["Fidget", "TailRipple", "SerpentLowWatch", "SerpentRaisedCoil", "SerpentCoilAlert"]
var flags := -1
var fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var living_floor: Dictionary = {}
var fitted_actions := false


func _ready() -> void:
	super._ready()
	# A prepared scene can retain the manual clock used by its baker.
	if animator.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	fitted_actions = animator.has_animation(Groups[25])
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	fall.skin = Ground.skin_points(mesh, skeleton)
	# The belly and tail bear weight along the full skinned surface.
	contact.active = false
	animator.mixer_applied.connect(settle)


func set_native_combat_flags(value: int) -> void:
	var entering := flags >= 0 and (flags & 0x40) == 0 and (value & 0x40) != 0
	flags = value
	if fitted_actions and entering and not dead and action_remaining <= 0.:
		start_clip(Groups[28], {})


func play_gait(moving: bool, speed: float) -> void:
	if not fitted_actions:
		if moving and current_clip in IdleGestures:
			action_remaining = 0.0
		super.play_gait(moving, speed)
		return
	if dead:
		return
	if action_remaining > 0.:
		if not moving or current_clip not in IdleGestures:
			return
		action_remaining = 0.
	var gait: Dictionary = entry.get("locomotion", {})
	var combat := flags >= 0 and (flags & 0x40) != 0
	var running := moving and speed > float(gait.get("run_threshold_mps", 3.6))
	var group := 24 if running else (0 if combat else 22) if moving else (1 if combat else 25)
	var clip: String = Groups[group]
	if current_clip != clip:
		current_clip = clip
		play(clip, .18)
	var cadence := float(gait.get("run_reference_mps", 5.5) if running else gait.get("walk_reference_mps", 1.8))
	animator.speed_scale = clampf(speed / maxf(.01, cadence), float(gait.get("rate_min", .65)),
		float(gait.get("rate_max", 1.65))) if moving else 1.


static func group_for(type: int, variation: int, war: bool) -> int:
	if variation < 0 or variation > 127:
		return -1
	match type:
		0, 11:
			return 4
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
		14:
			return 11
		15:
			return 23
	return -1


func receive_enhanced_action(request: Dictionary, wire_flags: int) -> bool:
	if not fitted_actions or dead or wire_flags < 0 or request.get("protocol") != "new" or int(request.get("body", 0)) != native_body:
		return false
	var group := group_for(int(request.get("type", -1)), int(request.get("variation", -1)), (wire_flags & 0x40) != 0)
	if not Groups.has(group):
		return false
	start_clip(Groups[group], request)
	if group in [2, 3]:
		fall.accept_action(self)
	return true


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip in ["Death", "Death2"]:
		fall.accept_action(self)
	return true


func start_clip(clip: String, request: Dictionary) -> void:
	current_clip = clip
	var length := animator.get_animation(clip).length
	action_remaining = Timing.duration(request, length)
	animator.speed_scale = 1.
	animator.play(clip, .10, length / action_remaining)
	animator.seek(0., false)
	if not request.is_empty():
		set_meta("native_action", request.duplicate(true))


func _physics_process(_delta: float) -> void:
	if not dead:
		living_floor = fall.floor_under(self)


func settle() -> void:
	if dead:
		fall.settle(self)
	else:
		model.position -= fall.shift
		fall.shift = Vector3.ZERO
		if living_floor.has("collider"):
			skeleton.force_update_all_bone_transforms()
			var normal: Vector3 = living_floor.normal
			var gap := Ground.minimum_plane_gap(fall.skin, skeleton, skeleton.global_transform, living_floor.position, normal)
			var depth := 0.
			if current_clip == Surface:
				var phase := animator.current_animation_position / maxf(.01, animator.current_animation_length)
				depth = .67 * (1. - smoothstep(.03, .85, phase))
			var before := model.position
			model.global_position.y += maxf(0., .002 - depth - gap) / normal.y
			fall.shift = model.position - before
	update_landmarks()


func begin_death_from(source: Node3D) -> float:
	dead = true
	contact.enabled = false
	return fall.begin_from_source(self, source, source.fall, false, source.current_clip == Surface)


func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self) if not fall.plane.is_empty() else INF
