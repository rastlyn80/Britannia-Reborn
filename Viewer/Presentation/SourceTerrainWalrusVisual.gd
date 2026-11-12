# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedWalrusVisual.gd"

const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const Flippers := preload("res://Presentation/SourceWalrusFlipperClearance.gd")
const Collapse := preload("res://Presentation/CougarTerrainFall.gd")
const Gaits := preload("res://Presentation/SourceCreatureGaitLoop.gd")
const IdleGestures := ["Fidget", "WalrusStillWatch", "WalrusNoseScan"]
var terrain := Terrain.new()
var flippers := Flippers.new()
var fall := Collapse.new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.28, 1.50))
	fall.skin = terrain.skin
	skeleton.add_child(flippers)
	flippers.active = false
	flippers.bind(terrain.skin)
	Gaits.close_gaits(animator)
	contact.modification_processed.disconnect(support_fitted_gesture)
	contact.modification_processed.connect(settle_live)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in IdleGestures:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	var accepted := super.receive_action(request)
	if accepted and dead and not terrain.plane.is_empty():
		fall.split = terrain.split
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
	# The source walrus slides on its belly and four articulated flippers.
	contact.enabled = false
	var up: Vector3 = (global_basis.inverse() * terrain.plane.normal).normalized()
	model.basis = (Basis(Quaternion(Vector3.UP, up)) * source_model_basis).scaled_local(model.scale)


func settle_live() -> void:
	if dead:
		return
	if terrain.plane.is_empty():
		support_fitted_gesture()
		return
	release_fitted_lift()
	terrain.release_live()
	if terrain.split:
		flippers.clear_treads(float(terrain.plane.position.y))
	elif float(terrain.plane.normal.y) < .998:
		flippers.clear_slope(terrain.plane)
	terrain.settle_live()


func settle_collapse() -> void:
	if fall.plane.is_empty():
		super.settle_collapse()
	else:
		fall.settle(self)


func begin_death_from(source: Node3D) -> float:
	fall.split = source.terrain.split
	return fall.begin_from_source(self, source, source.fall, false)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fall.plane.is_empty() else fall.snapshot_floor(self)
