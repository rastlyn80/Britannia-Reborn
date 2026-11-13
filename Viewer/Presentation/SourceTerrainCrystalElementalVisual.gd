# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedCrystalElementalVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.4, 2.4))
	contact.modification_processed.connect(settle_pose)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	release_fitted()
	terrain.sample()
	super._physics_process(delta)
	settle_pose()


func settle_fitted() -> void:
	if current_clip == FragmentFall:
		return
	if terrain.plane.is_empty():
		super.settle_fitted()
		return
	if is_fitted():
		var scattered := current_clip == Assembly and animator.assigned_animation == Assembly \
			and animator.current_animation_position < animator.current_animation_length * Join
		show_fragments(scattered)
	settle_pose()


func settle_pose() -> void:
	if terrain.plane.is_empty() or current_clip == FragmentFall:
		return
	if not dead and not fragments.visible:
		terrain.settle_live(.0005)
	elif not dead:
		terrain.release_live()
		var gap := fragment_floor_gap()
		if is_finite(gap):
			terrain.live_lift = maxf(0.0, (.003 - gap) / (1.0 if terrain.split else float(terrain.plane.normal.y)))
			model.global_position.y += terrain.live_lift
	elif animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
		terrain.settle(self)


func fragment_floor_gap() -> float:
	if not terrain.split:
		return fragment_gap(terrain.plane.position, terrain.plane.normal)
	var gap := INF
	for part: MeshInstance3D in fragment_points:
		gap = minf(gap, terrain.piece_step_gap(fragment_points[part], part.global_transform, terrain.plane))
	return gap


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	terrain.split = source.terrain.split
	terrain.plane = source.terrain.plane
	if source.current_clip == Assembly and source.fragments.visible:
		return super.begin_death_from(source)
	return terrain.begin_collapse(source)


func settle_fragment_fall(phase: float) -> void:
	if not terrain.split:
		super.settle_fragment_fall(phase)
		return
	var blend := smoothstep(0.0, 1.0, phase)
	for part: MeshInstance3D in fragment_starts:
		var from: Transform3D = fragment_starts[part]
		var turn := .24 * sin(float(part.get_index()) * 2.4)
		var target := Transform3D(Basis(Vector3.UP, turn) * from.basis, from.origin)
		target.origin += (from.origin - global_position).slide(Vector3.UP).normalized() * .16
		part.global_transform = from.interpolate_with(target, blend)
		var gap := terrain.piece_step_gap(fragment_points[part], part.global_transform, terrain.plane)
		if is_finite(gap):
			var lift := .003 - gap
			part.global_position.y += minf(lift, 0.0) * blend + maxf(lift, 0.0)


func corpse_snapshot_floor() -> float:
	if current_clip == FragmentFall:
		return super.corpse_snapshot_floor()
	return terrain.snapshot_floor(self)
