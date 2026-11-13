# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedEarthVisual.gd"

var terrain := preload("res://Presentation/SourceEarthTerrain.gd").new()
var formation_tread_lift := 0.0


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.25, 1.65))
	contact.modification_processed.disconnect(gesture_ground.support.bind(self))
	contact.modification_processed.connect(settle_body)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)


func settle_body() -> void:
	if current_clip != Formation:
		terrain.settle_body()


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	release_formation_tread()
	if dead:
		terrain.prepare_collapse()
	return true


func release_formation_tread() -> void:
	model.global_position.y -= formation_tread_lift
	formation_tread_lift = 0.0


func adjust_formation() -> void:
	release_formation_tread()
	super.adjust_formation()
	if current_clip != Formation or dead or not terrain.split or terrain.plane.is_empty():
		return
	var gap := INF
	for piece: MeshInstance3D in piece_points:
		if piece.is_visible_in_tree():
			gap = minf(gap, terrain.piece_step_gap(piece_points[piece], piece.global_transform, terrain.plane))
	if is_finite(gap):
		formation_tread_lift = maxf(0.0, .002 - gap)
		model.global_position.y += formation_tread_lift


func begin_death_from(source: Node3D) -> float:
	if source.current_clip == Formation and source.pieces.visible:
		terrain.split = source.terrain.split
		return super.begin_death_from(source)
	if source.current_clip == "Assemble":
		return super.begin_death_from(source)
	return terrain.begin_collapse(source)


func advance_stone_fall(weight: float) -> void:
	if not terrain.split:
		super.advance_stone_fall(weight)
		return
	var blend := smoothstep(0.0, 1.0, weight)
	for piece: MeshInstance3D in falling_pieces:
		var poses: Array = falling_pieces[piece]
		piece.transform = poses[0].interpolate_with(poses[1], blend)
		var gap := terrain.piece_step_gap(piece_points[piece], piece.global_transform, fall_plane)
		if is_finite(gap):
			var lift := .002 - gap
			if lift < 0.0:
				lift *= smoothstep(.69, 1.0, weight)
			piece.global_position.y += lift


func settle_collapse() -> void:
	if terrain.plane.is_empty() or current_clip == StoneFall:
		super.settle_collapse()
	else:
		terrain.settle(self)


func corpse_snapshot_floor() -> float:
	if current_clip == StoneFall or terrain.plane.is_empty():
		return super.corpse_snapshot_floor()
	return terrain.snapshot_floor(self)
