# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceModeCreatureVisual.gd"

var native_flight := false
var lift_from := 0.0
var flight_lift := 0.0
var flight_transition := 1.0


func set_native_combat_flags(flags: int) -> void:
	var was_flying := native_flight
	native_flight = (flags & 4) != 0
	if was_flying != native_flight:
		lift_from = flight_lift
		flight_transition = 0.0
		gait.set_flags(flags)
		if not dead and action_remaining <= 0.0:
			play_gait(false, 0.0)
		return
	if native_flight:
		gait.set_flags(flags)
	else:
		super.set_native_combat_flags(flags)


func play_gait(moving: bool, speed: float) -> void:
	if not native_flight:
		super.play_gait(moving, speed)
	elif not dead and action_remaining <= 0.0:
		if current_clip != "Fly":
			current_clip = "Fly"
			play(current_clip, .16)
		animator.speed_scale = 1.0


func _physics_process(delta: float) -> void:
	if not dead:
		flight_transition = minf(1.0, flight_transition + delta / .38)
		var goal := .37 if native_flight else 0.0
		flight_lift = lerpf(lift_from, goal, smoothstep(0.0, 1.0, flight_transition))
	super._physics_process(delta)


func settle_pose() -> void:
	if dead or terrain.plane.is_empty():
		super.settle_pose()
		return
	terrain.settle_live(.0005 - flight_lift)
	update_landmarks()


func begin_death_from(source: Node3D) -> float:
	if source.dead or source.flight_lift <= .04:
		return super.begin_death_from(source)
	var displayed := preload("res://Presentation/CreatureFallPlayback.gd").new()
	displayed.plane = source.terrain.plane
	terrain.split = source.terrain.split
	return terrain.begin_from_source(self, source, displayed, true)
