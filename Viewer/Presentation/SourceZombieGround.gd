# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceSkeletonGround.gd"

const GraveRise := "ZombieGraveRise"
const RestingGestures := ["Fidget", "LookUp", "ZombieQuietSway", "ZombieSlumpedWatch", "ZombieTwistedGuard"]


static func attach_zombie(actor: Node3D) -> void:
	var ground := new()
	var mesh: MeshInstance3D = actor.contact.surface
	actor.contact.free()
	actor.contact = ground
	actor.skeleton.add_child(ground)
	ground.bind(actor, mesh, null)


func resume_gait(moving: bool) -> void:
	if moving and visual.current_clip in RestingGestures:
		visual.action_remaining = 0.0


func _process_modification_with_delta(delta: float) -> void:
	if visual.current_clip != GraveRise:
		super._process_modification_with_delta(delta)


func settle() -> void:
	if visual.current_clip != GraveRise:
		super.settle()
		return
	if visual.dead or ground.is_empty():
		return
	release()
	var phase: float = visual.animator.current_animation_position / maxf(.001, visual.animator.current_animation_length)
	# Keep the original emergence below ground and support its final standing pose.
	var standing := smoothstep(.78, .99, phase)
	if standing > 0.0:
		lift = body_lift(false) * standing
		visual.model.global_position.y += lift
