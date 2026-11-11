# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceArmoredGargoyleFlightVisual.gd"

const PeaceWalk := "GargoylePeaceWalk"
const Quiet := "GargoyleQuietHover"
const Hatchet := "DestroyerHatchetCounter"
const Sweep := "EnforcerTurningSweep"
const FlagFlight := 4
const FlagCombat := 64

var alternate_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var native_flags := -1
var counter_hand := -1


func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(settle_alternate_fall)
	animator.get_animation(Quiet).loop_mode = Animation.LOOP_LINEAR
	animator.get_animation("Fly").loop_mode = Animation.LOOP_LINEAR
	counter_hand = skeleton.find_bone("cp_grasp_rhand")
	if counter_hand < 0:
		counter_hand = skeleton.find_bone("bip01 r hand")
	assert(counter_hand >= 0)


func set_native_combat_flags(flags: int) -> void:
	native_flags = flags


func play_gait(moving: bool, speed: float) -> void:
	if dead or action_remaining > 0.0:
		return
	if is_flying():
		set_loop("Fly", false)
	elif native_flags >= 0 and (native_flags & FlagCombat) == 0:
		var locomotion: Dictionary = entry.get("locomotion", {})
		if not moving:
			set_loop(Quiet, true)
		elif speed <= float(locomotion.get("run_threshold_mps", 3.6)):
			set_loop(PeaceWalk, true)
			var reference := maxf(.01, float(locomotion.get("walk_reference_mps", 1.8)))
			animator.speed_scale = clampf(speed / reference, float(locomotion.get("rate_min", .65)), float(locomotion.get("rate_max", 1.65)))
		else:
			super.play_gait(moving, speed)
	else:
		super.play_gait(moving, speed)


func is_flying() -> bool:
	return native_flags >= 0 and (native_flags & FlagFlight) != 0


func set_loop(clip: String, grounded: bool) -> void:
	contact.enabled = grounded
	if current_clip != clip:
		current_clip = clip
		animator.speed_scale = 1.0
		play(clip, .15)


func receive_action(request: Dictionary) -> bool:
	# The stock whirlwind applies another melee swing to each secondary target.
	if current_clip == Sweep and action_remaining > animator.get_animation(Sweep).length - .14 \
			and request.get("protocol") == "classic" and int(request.get("action", -1)) in [4, 5, 6]:
		set_meta("native_action", request.duplicate(true))
		return true
	var base := entry
	# Archive flight mode 3 inherits mode 1 before the combat defaults.
	if is_flying() and request.get("protocol") == "new" and request.get("type") == 5:
		var chosen: Dictionary = entry.get("new_action_categories", {})
		if chosen.get("5") == "GargoyleWingThreat":
			entry = entry.merged({"new_action_categories": chosen.merged({"5": "GargoyleNearGlance"}, true)}, true)
	var accepted := super.receive_action(request)
	entry = base
	if accepted:
		if current_clip == "Death2":
			alternate_fall.accept_action(self)
		else:
			alternate_fall.plane.clear()
		if is_flying():
			contact.enabled = false
	return accepted


func settle_alternate_fall() -> void:
	if current_clip == "Death2":
		alternate_fall.settle(self)


func begin_death_from(source: Node3D) -> float:
	if source.current_clip != "Death2" or not source.dead:
		return super.begin_death_from(source)
	dead = true
	contact.enabled = false
	return alternate_fall.begin_from_source(self, source, source.alternate_fall, source.is_flying())


func corpse_snapshot_floor() -> float:
	if current_clip == "Death2" and not alternate_fall.plane.is_empty():
		return alternate_fall.snapshot_floor(self)
	return INF


func start_hatchet_counter() -> Variant:
	if native_body != 755 or dead:
		return null
	start_stock_effect_motion(Hatchet)
	skeleton.force_update_all_bone_transforms()
	return skeleton.to_global(skeleton.get_bone_global_pose(counter_hand).origin)


func start_turning_sweep() -> void:
	if native_body == 754 and not dead:
		start_stock_effect_motion(Sweep)


func start_stock_effect_motion(clip: String) -> void:
	current_clip = clip
	animator.speed_scale = 1.0
	contact.enabled = not is_flying()
	action_remaining = animator.get_animation(clip).length
	animator.play(clip, .045)
	animator.seek(0.0, false)
