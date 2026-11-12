# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedDrakeVisual.gd"

const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const Wings := preload("res://Presentation/SourceDrakeWingClearance.gd")
const Collapse := preload("res://Presentation/CougarTerrainFall.gd")
const IdleGestures := ["Fidget", "Fidget2", "WingLift", "DrakeTailScan"]
var terrain := Terrain.new()
var wings := Wings.new()
var flight_margin := 0.0


func _init() -> void:
	fall = Collapse.new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.8, 2.55))
	fall.skin = terrain.skin
	skeleton.add_child(wings)
	wings.active = false
	wings.bind(terrain.skin)
	animator.mixer_applied.disconnect(apply_fitted_pose)
	contact.modification_processed.disconnect(apply_gesture_support)
	contact.modification_processed.connect(settle_live)
	contact.align_skinned_soles = true
	contact.iterations = 5


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in IdleGestures and not airborne_fit:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	var accepted := super.receive_action(request)
	if accepted and dead:
		fall.split = terrain.split
		if not terrain.plane.is_empty():
			fall.remember_floor(self, terrain.plane)
	return accepted


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	if terrain.plane.is_empty():
		super._physics_process(delta)
		return
	var flight := current_clip in FlyingClips or (is_fitted(current_clip) and airborne_fit)
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
		apply_gesture_support()
		return
	terrain.release_live()
	var target := clearance()
	# Keep a stable altitude through a wingbeat over the upper tread.
	var margin := flight_margin * smoothstep(.003, .42, target)
	if current_clip == "Land":
		var phase := animator.current_animation_position / maxf(.01, animator.current_animation_length)
		# Lower the body along a continuous descent. The remaining correction
		# is only for contact, so a low wing cannot pull the whole flight path up.
		margin = (.36 + flight_margin) * (1.0 - smoothstep(.03, .96, phase))
	model.global_position.y += margin
	if terrain.split:
		wings.clear_treads(float(terrain.plane.position.y))
	elif float(terrain.plane.normal.y) < .998:
		wings.clear_slope(terrain.plane)
	terrain.settle_live(.003 - target)
	terrain.live_lift += margin


func clearance() -> float:
	if current_clip == "Fly":
		return .42
	if is_fitted(current_clip) and airborne_fit:
		return lerpf(starting_clearance, maxf(starting_clearance, AirClearance),
			smoothstep(0.0, .16, animator.current_animation_position))
	return .003


func begin_death_from(source: Node3D) -> float:
	var flight: bool = source.current_clip in FlyingClips or (is_fitted(source.current_clip) and source.airborne_fit)
	fall.split = source.terrain.split
	return fall.begin_from_source(self, source, source.fall, flight)
