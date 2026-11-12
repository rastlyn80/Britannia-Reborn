# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/MongbatActionsVisual.gd"

const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const Wings := preload("res://Presentation/SourceMongbatWingClearance.gd")
const Ascent := "MongbatUnfoldAndRise"
const WingActions := ["TakeOff", "Fly", "Land", "MongbatDivingSwoop",
	"MongbatWingAlert", "MongbatHoverRebalance", "MongbatQuietHover", Ascent]
const ClassicIdleGroups := [1, 17, 18]
const IdleClips := ["Idle", "Fidget", "Fidget2", "MongbatArmLift"]
var terrain := Terrain.new()
var wings := Wings.new()
var moving_for_gait := false


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.65, 1.48))
	skeleton.add_child(wings)
	wings.active = false
	wings.bind(terrain.skin)
	contact.modification_processed.connect(terrain.settle_live)


func play_gait(moving: bool, speed: float) -> void:
	moving_for_gait = moving
	if moving and not dead and current_clip in IdleClips:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not dead and moving_for_gait and request.get("protocol") == "classic" and request.get("action") in ClassicIdleGroups:
		return true
	return super.receive_action(request)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	super._physics_process(delta)
	terrain.sample()
	terrain.settle_live()


func remember_plane(plane: Dictionary) -> void:
	super.remember_plane(plane)
	if terrain.actor != null:
		terrain.remember_floor(self, plane)
		terrain.split = terrain.spans_treads(plane)


func settle_collapse() -> void:
	if dead:
		terrain.settle(self)
	else:
		var sloping := not terrain.split and not terrain.plane.is_empty() and float(terrain.plane.normal.y) < .998
		if sloping and animator.assigned_animation in WingActions:
			terrain.release_live()
			wings.clear_slope(terrain.plane)
		terrain.settle_live()


func begin_death_from(source: Node3D) -> float:
	var airborne: bool = source.current_clip in AIRBORNE
	if source.current_clip in source.entry.get("archive_grounded_gestures", []):
		airborne = source.current_clip != Ascent or source.animator.current_animation_position > .36
	terrain.split = source.terrain.split
	return terrain.begin_from_source(self, source, source.terrain, airborne)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
