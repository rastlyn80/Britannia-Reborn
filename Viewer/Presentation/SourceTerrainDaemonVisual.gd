# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedWingedVisual.gd"

const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const AppendageSupport := preload("res://Presentation/SourceWingSlopeClearance.gd")
const Wings := preload("res://Presentation/SourceDaemonWingClearance.gd")
const Collapse := preload("res://Presentation/CougarTerrainFall.gd")
const IdleGestures := ["Fidget", "TailPause", "DaemonTailWatch"]
var terrain := Terrain.new()
var wings: AppendageSupport = Wings.new()
var support_extent := Vector2(2.6, 2.45)
var flight_clearance := .98
var landing_lift := .52
var interruptible_gestures: Array = IdleGestures
var fall := Collapse.new()
var flight_margin := 0.0


func _ready() -> void:
	super._ready()
	terrain.bind(self, support_extent)
	fall.skin = terrain.skin
	skeleton.add_child(wings)
	wings.active = false
	wings.bind(terrain.skin)
	animator.mixer_applied.disconnect(settle_collapse)
	animator.mixer_applied.disconnect(apply_fitted_pose)
	animator.mixer_applied.connect(fall.settle.bind(self))
	contact.modification_processed.disconnect(clear_gesture_ground)
	contact.modification_processed.disconnect(apply_gesture_support)
	contact.modification_processed.connect(settle_live)
	contact.align_skinned_soles = true


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in interruptible_gestures and not airborne_fit:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	var accepted := super.receive_action(request)
	if accepted and dead:
		fall.split = terrain.split
		fall.remember_floor(self, terrain.plane if not terrain.plane.is_empty() else support_plane(self))
	return accepted


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	if terrain.plane.is_empty():
		super._physics_process(delta)
		return
	var flight := current_clip in AIRBORNE or (is_fitted(current_clip) and airborne_fit)
	contact.enabled = not flight
	contact.sample(get_world_3d().direct_space_state, global_position)
	var up: Vector3 = (global_basis.inverse() * terrain.plane.normal).normalized()
	model.basis = (Basis(Quaternion(Vector3.UP, up)) * source_model_basis).scaled_local(model.scale)
	flight_margin = upper_tread_rise() if flight and terrain.split else 0.0


func upper_tread_rise() -> float:
	var space := get_world_3d().direct_space_state
	var floor_height: float = terrain.plane.position.y
	var rise := 0.0
	for x: float in [-terrain.extent.x, 0.0, terrain.extent.x]:
		for z: float in [-terrain.extent.y, 0.0, terrain.extent.y]:
			var point := to_global(Vector3(x, 0.0, z))
			terrain.ground_ray.from = Vector3(point.x, floor_height + .65, point.z)
			terrain.ground_ray.to = Vector3(point.x, floor_height - .65, point.z)
			var hit := space.intersect_ray(terrain.ground_ray)
			if not hit.is_empty() and hit.normal.y > .75:
				rise = maxf(rise, float(hit.position.y) - floor_height)
	return rise


func settle_live() -> void:
	if dead:
		return
	if terrain.plane.is_empty():
		clear_gesture_ground()
		apply_gesture_support()
		return
	release_gesture_lift()
	release_gesture_shift()
	terrain.release_live()
	var target := .003
	var margin := 0.0
	var phase := animator.current_animation_position / maxf(.01, animator.current_animation_length)
	match current_clip:
		"Fly":
			target = flight_clearance
			margin = flight_margin
		"TakeOff":
			margin = flight_margin * smoothstep(.08, .88, phase)
		"Land":
			margin = (landing_lift + flight_margin) * (1.0 - smoothstep(.03, .96, phase))
		_:
			if is_fitted(current_clip) and airborne_fit:
				target = lerpf(starting_clearance, maxf(starting_clearance, AirClearance),
					smoothstep(0.0, .16, animator.current_animation_position))
				margin = flight_margin * smoothstep(.003, AirClearance, target)
	model.global_position.y += margin
	if terrain.split:
		wings.clear_treads(float(terrain.plane.position.y))
	elif float(terrain.plane.normal.y) < .998:
		wings.clear_slope(terrain.plane)
	terrain.settle_live(.003 - target)
	terrain.live_lift += margin


func begin_death_from(source: Node3D) -> float:
	var flight: bool = source.current_clip in AIRBORNE or (is_fitted(source.current_clip) and source.airborne_fit)
	fall.split = source.terrain.split
	return fall.begin_from_source(self, source, source.fall, flight)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fall.plane.is_empty() else fall.snapshot_floor(self)
