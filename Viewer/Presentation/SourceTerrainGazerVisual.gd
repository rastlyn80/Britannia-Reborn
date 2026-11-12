# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedGazerVisual.gd"

const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const Fall := preload("res://Presentation/CougarTerrainFall.gd")
const IdleGestures := ["Fidget", "EyeSpread", "GazerHoverScan", "GazerOrbitFeint"]
var terrain := Terrain.new()


func _init() -> void:
	fitted_fall = Fall.new()


func _ready() -> void:
	super._ready()
	terrain.actor = self
	terrain.extent = Vector2(1.05, .95)
	terrain.skin = fitted_skin
	animator.mixer_applied.disconnect(adjust_hover)


func _physics_process(_delta: float) -> void:
	if not dead:
		terrain.release_live()
		terrain.sample()
		terrain.settle_live()


func update_eye_flashes() -> void:
	terrain.settle_live()
	super.update_eye_flashes()


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in IdleGestures:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		fitted_fall.split = terrain.split
		fitted_fall.remember_floor(self, terrain.plane if not terrain.plane.is_empty() else fitted_fall.floor_under(self))
		collapse_plane = {}
		terrain.live_lift = 0.0
	return true


func begin_death_from(source: Node3D) -> float:
	var previous: RefCounted = source.fitted_fall if source.dead else source.terrain
	fitted_fall.split = previous.split
	return fitted_fall.begin_from_source(self, source, previous, false)
