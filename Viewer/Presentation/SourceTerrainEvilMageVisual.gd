# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedEvilMageVisual.gd"

const Manifest := "EvilMageManifest"
const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd").new()
var terrain_fall := preload("res://Presentation/CougarTerrainFall.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.05, 1.4))
	terrain_fall.skin = terrain.skin
	fitted_fall = terrain_fall
	contact.modification_processed.disconnect(support_fit)
	contact.modification_processed.connect(settle_contact)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	if not contact.enabled:
		support_fit()


func update_fitted_pose() -> void:
	if dead:
		terrain_fall.settle(self)
		update_landmarks()
		return
	terrain.release_live()
	var recovering := growth.apply(self, Manifest)
	if terrain.split or recovering or current_clip in entry.get("archive_grounded_gestures", []):
		# Each foot uses its own tread. Use one stable body height before the full-skin correction.
		model.position.y = source_model_position.y
		contact.base_model_y = model.position.y
	else:
		apply_blend_ground()
	support_fit()


func settle_contact() -> void:
	if not contact.enabled:
		return
	# SourceMageSupport has already restored its own model height.
	terrain.live_lift = 0.0
	support_fit()


func support_fit(_recovering := false) -> void:
	if not dead:
		terrain.settle_live(.0005)
		update_landmarks()


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip == Manifest:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain_fall.split = terrain.split
		terrain_fall.remember_floor(self, terrain.plane if not terrain.plane.is_empty() else terrain_fall.floor_under(self))
	return true


func begin_death_from(source: Node3D) -> float:
	terrain_fall.split = source.terrain.split
	var previous: RefCounted = source.fitted_fall
	if not source.dead:
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
		previous.shift = source.global_basis.inverse() * Vector3.UP * source.terrain.live_lift
	return terrain_fall.begin_from_source(self, source, previous, false)
