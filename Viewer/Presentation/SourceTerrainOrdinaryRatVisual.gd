# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedOrdinaryRatVisual.gd"

const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const TerrainFall := preload("res://Presentation/CougarTerrainFall.gd")
const DisplayedFall := preload("res://Presentation/DisplayedCreatureFallPlayback.gd")
var terrain := Terrain.new()
var terrain_fall := TerrainFall.new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(.28, .42))
	fall = terrain_fall
	terrain_fall.skin = terrain.skin
	animator.mixer_applied.disconnect(settle_collapse)
	contact.modification_processed.disconnect(gesture.support.bind(self))
	# Keep the living clearance within half a millimetre of the corpse floor.
	contact.modification_processed.connect(terrain.settle_live.bind(.0005))


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["Fidget", "Fidget2", "Alert"]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		terrain.release_live()
		terrain_fall.split = terrain.split
		terrain_fall.remember_floor(self, terrain.plane if not terrain.plane.is_empty() else fall.floor_under(self))
	return true


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	dead = true
	contact.enabled = false
	terrain_fall.split = source.terrain.split
	var previous: RefCounted = source.fall
	if not source.dead:
		previous = DisplayedFall.new()
		previous.plane = source.terrain.plane
		previous.shift = global_basis.inverse() * Vector3.UP * source.terrain.live_lift
	var duration: float = fall.begin_from_display(self, source, previous, source.current_clip, false)
	if fall.blend_pose.is_empty() and not source.dead and duration > 0.0:
		fall.blend_length = minf(.12, duration)
		for joint in source.skeleton.get_bone_count():
			fall.blend_pose.append(source.skeleton.get_bone_pose(joint))
		fall.settle(self)
	return duration
