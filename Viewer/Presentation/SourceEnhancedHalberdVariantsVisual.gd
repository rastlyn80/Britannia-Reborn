# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourcePreservingCreatureVisual.gd"

const FittedFall := preload("res://Presentation/FittedCreatureFallVariants.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.0, 1.0))
	animator.mixer_applied.connect(settle_terrain)
	contact.modification_processed.connect(settle_terrain)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	settle_terrain()


func receive_action(request: Dictionary) -> bool:
	if FittedFall.consume(self, request):
		return true
	if not dead:
		terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func settle_terrain() -> void:
	if terrain.plane.is_empty():
		return
	if dead:
		if animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
			terrain.settle(self)
	elif current_clip in entry.get("archive_grounded_gestures", []):
		release_clearance()
		terrain.settle_live(.001)


func begin_death_from(source: Node3D) -> float:
	if source.dead and source.current_clip in source.entry.get("enhanced_variant_falls", []):
		return FittedFall.handoff(self, source)
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
