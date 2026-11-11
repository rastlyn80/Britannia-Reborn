# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourcePreservingCreatureVisual.gd"

const CombatIdle := "TreefellowCombatIdle"
const QuietIdle := "TreefellowQuietIdle"
const QuietWalk := "TreefellowQuietWalk"
const Ready := "TreefellowRootReady"
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Bark := preload("TreefellowBark.gdshader")
const Hue := preload("res://Presentation/HumanHue.gd")

var flags := -1
var fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()


func set_hue(value: int) -> void:
	if treatment != "modern" or model == null:
		super.set_hue(value)
		return
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var source := mesh.mesh.surface_get_material(0) as BaseMaterial3D
	var previous := mesh.get_surface_override_material(0) as ShaderMaterial
	if value == hue and previous != null and previous.shader == Bark:
		return
	hue = value
	var material := ShaderMaterial.new()
	material.shader = Bark
	material.set_shader_parameter("albedo_texture", source.albedo_texture)
	var palette := Hue.palette(value)
	material.set_shader_parameter("hue_palette", palette)
	material.set_shader_parameter("use_hue", palette != null)
	material.set_shader_parameter("partial_hue", (value & 0x8000) != 0)
	mesh.set_surface_override_material(0, material)


func _ready() -> void:
	super._ready()
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	fall.skin = Ground.skin_points(mesh, skeleton)
	animator.mixer_applied.connect(settle_fall)


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
	var clip := QuietWalk if moving else CombatIdle if combat else QuietIdle
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
	if dead:
		fall.accept_action(self)
	return true


func settle_fall() -> void:
	if dead and not pose_entry.active:
		fall.settle(self)


func begin_death_from(source: Node3D) -> float:
	if source.dead and source.current_clip in ["Death", "Death2"]:
		dead = true
		contact.enabled = false
		return fall.begin_from_source(self, source, source.fall, false)
	global_transform = source.global_transform
	model.transform = source.model.transform
	var duration := super.begin_death_from(source)
	pose_entry.skin = fall.skin
	var floor := fall.floor_under(source)
	pose_entry.plane_origin = floor.position
	pose_entry.plane_normal = floor.normal
	return duration


func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self) if not fall.plane.is_empty() else INF
