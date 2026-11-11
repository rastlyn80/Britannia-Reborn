# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourcePreservingCreatureVisual.gd"

const CombatRest := "MolochCombatRest"
const QuietRest := "MolochQuietRest"
const PeaceWalk := "MolochPeaceWalk"
var flags := -1
var alternate_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()


func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(settle_fall)


func set_native_combat_flags(value: int) -> void:
	flags = value


func play_gait(moving: bool, speed: float) -> void:
	if dead or action_remaining > 0.0:
		return
	var locomotion: Dictionary = entry.get("locomotion", {})
	var combat := (flags & 64) != 0
	if flags < 0 or moving and (combat or speed > float(locomotion.get("run_threshold_mps", 3.6))):
		super.play_gait(moving, speed)
		return
	var clip := PeaceWalk if moving else CombatRest if combat else QuietRest
	contact.enabled = true
	if current_clip != clip:
		current_clip = clip
		play(clip, .18)
	var reference := maxf(.01, float(locomotion.get("walk_reference_mps", 1.8)))
	animator.speed_scale = clampf(speed / reference, float(locomotion.get("rate_min", .65)),
		float(locomotion.get("rate_max", 1.65))) if moving else 1.0


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip in ["Death", "Death2"]:
		alternate_fall.accept_action(self)
	else:
		alternate_fall.plane.clear()
	return true


func settle_fall() -> void:
	if current_clip in ["Death", "Death2"] and not pose_entry.active:
		alternate_fall.settle(self)


func begin_death_from(source: Node3D) -> float:
	if source.current_clip == "Death2" and source.dead:
		dead = true
		contact.enabled = false
		return alternate_fall.begin_from_source(self, source, source.alternate_fall, false)
	var length := super.begin_death_from(source)
	var floor := alternate_fall.floor_under(source)
	pose_entry.plane_origin = floor.position
	pose_entry.plane_normal = floor.normal
	return length


func corpse_snapshot_floor() -> float:
	if current_clip == "Death2" and not alternate_fall.plane.is_empty():
		return alternate_fall.snapshot_floor(self)
	return INF
