# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedEfreetVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var carpet_probes := PackedVector3Array()
var lamp_probes := PackedVector3Array()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.6, 1.7))
	# The rug shader can lower the edge by .026 m and curl it back by .61 m.
	for x: float in [-.76, -.38, 0.0, .38, .76]:
		for z: float in [-.55, -.275, 0.0, .275, .55]:
			carpet_probes.append(Vector3(x, -.026, z))
	for x: float in [-.20, -.10, 0.0, .12, .24]:
		for z: float in [-.08, 0.0, .08]:
			lamp_probes.append(Vector3(x, -.058, z))
	contact.modification_processed.connect(settle)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	settle()


func settle() -> void:
	if terrain.actor == null or terrain.plane.is_empty():
		super.settle()
		return
	if dead:
		clear_props()
		if animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
			terrain.settle(self)
		return
	terrain.release_live()
	super.settle()
	terrain.settle_live(.0005)
	if props.carpet.visible:
		var lift := terrain.live_lift
		props.carpet.global_position.y += lift
		lift_carpet_on_treads()
	if terrain.split and props.lamp.visible:
		var gap := terrain.piece_step_gap(lamp_probes, props.lamp.global_transform, terrain.plane)
		var lift := maxf(0.0, .003 - gap)
		props.lamp.global_position.y += lift
		for wisp: MeshInstance3D in props.wisps:
			if wisp.visible:
				wisp.global_position.y += lift


func lift_carpet_on_treads() -> void:
	if not terrain.split:
		return
	var rug_space: Transform3D = props.carpet.global_transform
	var roll := float(props.fabric.get_shader_parameter("roll"))
	rug_space.basis.z *= 1.0 - roll * (.61 / 1.10)
	rug_space.origin -= props.carpet.global_basis.z * (.305 * roll)
	var gap := terrain.piece_step_gap(carpet_probes, rug_space, terrain.plane)
	var lift := maxf(0.0, .003 - gap)
	model.global_position.y += lift
	props.carpet.global_position.y += lift
	terrain.live_lift += lift


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip == Arrival:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		fall.plane = {}
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	var previous: RefCounted = source.terrain
	terrain.split = previous.split
	if not source.dead:
		model.transform = source.model.transform
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	return terrain.begin_from_source(self, source, previous, false)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
