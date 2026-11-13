# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedBloodElementalVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.35, 1.55))
	terrain.skin = support_skin
	contact.modification_processed.connect(settle_living)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	restore_fitted_pose()
	terrain.sample()
	super._physics_process(delta)
	if is_fitted() or growth.active:
		support_death_blend()
	else:
		settle_living()


func support_death_blend() -> void:
	if terrain.actor == null:
		super.support_death_blend()
		return
	terrain.release_live()
	if dead:
		if pool != null:
			pool.visible = false
		if animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
			terrain.settle(self)
		update_landmarks()
	else:
		super.support_death_blend()
		settle_living()


func settle_living() -> void:
	if not dead:
		terrain.settle_live(.0005)
		update_landmarks()


func refresh_growth_floor() -> void:
	if terrain.actor != null and not dead and growth.active and not is_fitted():
		terrain.release_live()
		super.refresh_growth_floor()
		settle_living()


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip == Rise:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	fluid_clock = source.fluid_clock
	for material: ShaderMaterial in fluid_materials:
		material.set_shader_parameter("fluid_time", fluid_clock)
	var previous: RefCounted = source.terrain
	terrain.split = previous.split
	if not source.dead:
		model.transform = source.model.transform
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	return terrain.begin_from_source(self, source, previous, false)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
