# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceScaledCreatureVisual.gd"

const CombatRest := "BruteCombatRest"
const QuietRest := "BruteQuietRest"
const PeaceWalk := "BrutePeaceWalk"
const Ready := "BruteLowReady"
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var flags := -1
var alternate_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()


func _ready() -> void:
	super._ready()
	var spines := model.find_child("BruteSpines", true, false) as MeshInstance3D
	assert(spines != null)
	var body := model.find_child("Body", true, false) as MeshInstance3D
	assert(body != null and body.skin == spines.skin)
	var spike_skin := Ground.skin_points(spines, skeleton)
	control_skin = with_spines(Ground.skin_points(body, skeleton), spike_skin)
	alternate_fall.skin = control_skin
	animator.mixer_applied.connect(settle_fall)


func with_spines(body: Dictionary, spines: Dictionary) -> Dictionary:
	assert(body.bones == spines.bones and body.bind_poses == spines.bind_poses)
	var skin := body.duplicate()
	skin.surfaces = body.surfaces + spines.surfaces
	return skin


func set_native_combat_flags(value: int) -> void:
	var entering := flags >= 0 and (flags & 64) == 0 and (value & 64) != 0
	flags = value
	if not entering or dead or action_remaining > 0.0:
		return
	current_clip = Ready
	contact.enabled = true
	animator.speed_scale = 1.0
	action_remaining = animator.get_animation(Ready).length
	play(Ready, .12)


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
	if source.dead and source.current_clip in ["Death", "Death2"]:
		dead = true
		contact.enabled = false
		return alternate_fall.begin_from_source(self, source, source.alternate_fall, false)
	var length := super.begin_death_from(source)
	pose_entry.skin = alternate_fall.skin
	var floor := alternate_fall.floor_under(source)
	pose_entry.plane_origin = floor.position
	pose_entry.plane_normal = floor.normal
	return length


func corpse_snapshot_floor() -> float:
	if current_clip in ["Death", "Death2"] and not alternate_fall.plane.is_empty() and not pose_entry.active:
		return alternate_fall.snapshot_floor(self)
	return INF
