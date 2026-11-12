# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceSilverSerpentVisual.gd"

const Giant := preload("res://Presentation/SourceEnhancedGiantSerpentVisual.gd")
const Timing := preload("res://Presentation/HumanActions.gd")
const Added := ["SerpentCombatSlither", "SerpentQuietIdle", "SerpentUncoilStrike", "SerpentSurface",
	"SerpentLowWatch", "SerpentRaisedCoil", "SerpentCoilAlert", "LowNeckRecoil", "Death2"]
var flags := -1
var fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var living_floor: Dictionary = {}


func _ready() -> void:
	super._ready()
	# A prepared scene can retain the manual clock used by its baker.
	if animator.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE


func set_native_combat_flags(value: int) -> void:
	var entering := flags >= 0 and (flags & 0x40) == 0 and (value & 0x40) != 0
	flags = value
	if entering and not dead and action_remaining <= 0.:
		start_clip(Giant.Groups[28], {})


func play_gait(moving: bool, speed: float) -> void:
	if dead:
		return
	if action_remaining > 0.:
		if not moving or current_clip not in Giant.IdleGestures:
			return
		action_remaining = 0.
	var combat := flags >= 0 and (flags & 0x40) != 0
	var gait: Dictionary = entry.get("locomotion", {})
	var running := moving and speed > float(gait.get("run_threshold_mps", 3.6))
	var group := 24 if running else (0 if combat else 22) if moving else (1 if combat else 25)
	var clip: String = Giant.Groups[group]
	if current_clip != clip:
		current_clip = clip
		play(clip, .18)
	var cadence := float(gait.get("run_reference_mps", 5.5) if running else gait.get("walk_reference_mps", 1.8))
	animator.speed_scale = clampf(speed / maxf(.01, cadence), float(gait.get("rate_min", .65)),
		float(gait.get("rate_max", 1.65))) if moving else 1.


func receive_enhanced_action(request: Dictionary, wire_flags: int) -> bool:
	if dead or wire_flags < 0 or request.get("protocol") != "new" or int(request.get("body", 0)) != native_body:
		return false
	var group := Giant.group_for(int(request.get("type", -1)), int(request.get("variation", -1)), (wire_flags & 0x40) != 0)
	if not Giant.Groups.has(group):
		return false
	start_clip(Giant.Groups[group], request)
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


func _physics_process(delta: float) -> void:
	if dead:
		return
	living_floor = fall.floor_under(self)
	if animator.assigned_animation not in Added:
		super._physics_process(delta)


func apply_ground() -> void:
	if dead and not fall.plane.is_empty():
		fall.settle(self)
		update_landmarks()
		return
	model.position -= fall.shift
	fall.shift = Vector3.ZERO
	if animator.assigned_animation not in Added:
		super.apply_ground()
		if not living_floor.has("collider"):
			return
	else:
		model.position.y = source_position.y
	skeleton.force_update_all_bone_transforms()
	var support := living_floor if living_floor.has("collider") else {"position": global_position, "normal": Vector3.UP}
	var normal: Vector3 = support.normal
	var gap := Ground.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, support.position, normal)
	var depth := 0.
	if current_clip == Giant.Surface:
		var phase := animator.current_animation_position / maxf(.01, animator.current_animation_length)
		depth = .73 * (1. - smoothstep(.03, .85, phase))
	var before := model.position
	model.global_position.y += maxf(0., .002 - depth - gap) / normal.y
	fall.shift = model.position - before
	update_landmarks()


func begin_death_from(source: Node3D) -> float:
	dead = true
	contact.enabled = false
	return fall.begin_from_source(self, source, source.fall, false, source.current_clip == Giant.Surface)


func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self) if not fall.plane.is_empty() else INF
