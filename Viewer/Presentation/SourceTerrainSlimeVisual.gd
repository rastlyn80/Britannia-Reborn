# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceAmorphousVisual.gd"

const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const Collapse := preload("res://Presentation/CougarTerrainFall.gd")
var terrain := Terrain.new()
var fall := Collapse.new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(.65, .80))
	fall.skin = terrain.skin
	contact.modification_processed.connect(settle_live)
	animator.mixer_applied.connect(settle_fall)


func _physics_process(_delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	if terrain.plane.is_empty():
		return
	var local_normal := (global_basis.inverse() * Vector3(terrain.plane.normal)).normalized()
	model.basis = (Basis(Quaternion(Vector3.UP, local_normal)) * source_model_basis).scaled_local(model.scale)


func settle_live() -> void:
	# The source gel has no stance feet. Preserve its positive authored bounce.
	terrain.settle_live(.0005)
	update_landmarks()


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		terrain.release_live()
		blend_remaining = 0.0
		fall.split = terrain.split
		fall.remember_floor(self, terrain.plane if not terrain.plane.is_empty() else fall.floor_under(self))
	return true


func begin_death_from(source: Node3D) -> float:
	dead = true
	contact.enabled = false
	fall.split = source.terrain.split
	var previous: RefCounted = source.fall
	if not source.dead:
		previous = Collapse.new()
		previous.plane = source.terrain.plane
		previous.shift = source.global_basis.inverse() * Vector3.UP * source.terrain.live_lift
	return fall.begin_from_source(self, source, previous, false)


func settle_fall() -> void:
	if dead and not fall.plane.is_empty():
		fall.settle(self)
		update_landmarks()


func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self) if not fall.plane.is_empty() else INF
