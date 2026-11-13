# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceDragonBreathVisual.gd"

const BreathMotion := "Attack2"
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var breathing := false


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(4.0, 3.6))
	animator.mixer_applied.connect(settle_pose)
	contact.modification_processed.connect(settle_pose)


func play_gait(moving: bool, speed: float) -> void:
	if moving and not dead and current_clip in ["Fidget", "Fidget2"]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


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
	var windup: bool = request.get("protocol") == "classic" and request.get("action") == 12 \
		and request.get("frames") == 5 and request.get("repeat_count") == 1 \
		and request.get("reverse") == false and request.get("repeat") == false and request.get("delay") == 0
	var base := entry
	if windup:
		var groups: Dictionary = entry.get("classic_action_categories", {})
		entry = entry.merged({"classic_action_categories": groups.merged({"12": BreathMotion}, true)}, true)
	var accepted := super.receive_action(request)
	entry = base
	if not accepted:
		return false
	breathing = windup
	if breathing:
		const Duration := 1.55
		animator.speed_scale = animator.get_animation(BreathMotion).length / Duration
		action_remaining = Duration
	if dead:
		terrain.prepare_collapse()
	return true


func fire_breath_origin() -> Variant:
	if not breathing or dead or current_clip != BreathMotion or action_remaining <= 0.0:
		return null
	var muzzle := skeleton.find_bone("box15")
	return skeleton.to_global(skeleton.get_bone_global_pose(muzzle).origin) if muzzle >= 0 else null


func begin_death_from(source: Node3D) -> float:
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
