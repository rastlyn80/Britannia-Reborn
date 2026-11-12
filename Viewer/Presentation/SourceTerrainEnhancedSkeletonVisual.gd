# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedSkeletonVisual.gd"

const Footing := preload("res://Presentation/SourceSkeletonGround.gd")
var join_at := -1.0


func _ready() -> void:
	super._ready()
	Footing.attach(self, pieces)


func _physics_process(_delta: float) -> void:
	if not dead:
		contact.sample(get_world_3d().direct_space_state, global_position)


func _process(delta: float) -> void:
	if finishing_assembly():
		contact.settle()
		if animator.current_animation_position >= join_at and living_mesh.visible:
			join_at = -1.0
			contact.death.enter(self, self)
		return
	super._process(delta)


func play_gait(moving: bool, speed: float) -> void:
	contact.resume_gait(moving)
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	var accepted := super.receive_action(request)
	if not accepted:
		return false
	if current_clip == Assembly:
		# The time-zero visibility keys must take effect before the first
		# displayed frame. Blending with a standing clip can skip them.
		animator.stop()
		animator.play(Assembly, 0.0)
		animator.advance(0.0)
		animator.seek(0.0, true)
	elif dead:
		contact.prepare_death()
	return true


func begin_death_from(source: Node3D) -> float:
	if source.current_clip == Assembly and source.pieces.visible:
		return gather_before_fall(source)
	return contact.death.enter(self, source)


func gather_before_fall(source: Node3D) -> float:
	global_transform = source.global_transform
	model.global_transform = source.model.global_transform
	model.global_position.y -= source.contact.lift
	contact.ground = source.contact.ground
	contact.use_local_planes = source.contact.use_local_planes
	contact.assembly_rise = source.contact.assembly_rise
	current_clip = Assembly
	var start: float = source.animator.current_animation_position
	join_at = animator.get_animation(Assembly).length * Footing.AssemblyJoin + .0001
	var remaining := maxf(.001, join_at - start)
	var gather_duration := clampf(remaining, .06, .24)
	animator.speed_scale = 1.0
	animator.play(Assembly, 0.0, remaining / gather_duration)
	animator.advance(0.0)
	animator.seek(start, true)
	contact.settle()
	return gather_duration + animator.get_animation("Death").length


func finishing_assembly() -> bool:
	return join_at >= 0.0


func corpse_snapshot_floor() -> float:
	return contact.death.snapshot_floor(self)
