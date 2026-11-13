# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedWraithVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	animator.mixer_applied.disconnect(fall.settle.bind(self))
	animator.mixer_applied.disconnect(displayed_fall.settle.bind(self))
	terrain.bind(self, Vector2(1.2, 1.35))
	animator.mixer_applied.connect(terrain.settle.bind(self))
	contact.modification_processed.connect(settle_living_treads)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	settle_living_treads()


func adjust_display() -> void:
	terrain.release_live()
	super.adjust_display()
	settle_living_treads()


func settle_living_treads() -> void:
	if dead or terrain.plane.is_empty():
		return
	if not pieces.visible:
		terrain.settle_live(.0005)
	elif terrain.split:
		terrain.release_live()
		var gap := INF
		for part: MeshInstance3D in piece_points:
			if part.is_visible_in_tree():
				gap = minf(gap, terrain.piece_step_gap(piece_points[part], part.global_transform, terrain.plane))
		if is_finite(gap):
			terrain.live_lift = maxf(0.0, .002 - gap)
			model.global_position.y += terrain.live_lift


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	if source.current_clip == Assembly and source.pieces.visible:
		terrain.split = source.terrain.split
		return begin_scatter_from(source)
	return terrain.begin_collapse(source, source.display_lift)


func advance_scatter(progress: float) -> void:
	if not terrain.split:
		super.advance_scatter(progress)
		return
	var blend := smoothstep(0.0, 1.0, progress)
	for part: MeshInstance3D in falling_parts:
		var poses: Array = falling_parts[part]
		part.transform = poses[0].interpolate_with(poses[1], blend)
		var gap := terrain.piece_step_gap(piece_points[part], part.global_transform, fall_plane)
		if is_finite(gap):
			var lift := .002 - gap
			if lift < 0.0:
				lift *= smoothstep(.68, 1.0, progress)
			part.global_position.y += lift


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if current_clip == Scatter else terrain.snapshot_floor(self)
