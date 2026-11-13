# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedSandVortexVisual.gd"

const Tread := preload("res://Presentation/SourceCreatureTreadTerrain.gd")


class SandSupport extends Tread:
	var cloud: MeshInstance3D
	var dust: MeshInstance3D
	var points := PackedVector3Array()

	func settle(visual: Node3D) -> void:
		super.settle(visual)
		if plane.is_empty() or not visual.dead or not dust.visible:
			return
		var gap := footprint_gap()
		if not is_finite(gap):
			return
		var lift := .002 - gap
		if lift < 0.0 and cloud.visible:
			return
		if lift < 0.0:
			var phase: float = visual.animator.current_animation_position / visual.animator.current_animation_length
			lift *= smoothstep(.75, 1.0, phase)
		var prior: Vector3 = visual.model.position
		visual.model.global_position.y += lift / (1.0 if split else float(plane.normal.y))
		shift += visual.model.position - prior

	func footprint_gap() -> float:
		if split:
			return piece_step_gap(points, dust.global_transform, plane)
		var gap := INF
		var normal: Vector3 = plane.normal
		var origin: Vector3 = plane.position
		for point: Vector3 in points:
			gap = minf(gap, normal.dot(dust.to_global(point) - origin))
		return gap

	func snapshot_floor(visual: Node3D) -> float:
		if not dust.visible:
			return super.snapshot_floor(visual)
		var floor := INF
		var relative := visual.global_transform.affine_inverse() * dust.global_transform
		for point: Vector3 in points:
			floor = minf(floor, (relative * point).y)
		return floor


var terrain := SandSupport.new()


func _ready() -> void:
	super._ready()
	terrain.actor = self
	terrain.extent = Vector2(1.7, 1.7)
	terrain.skin = fall.skin
	terrain.cloud = model.find_child("CloudBody", true, false) as MeshInstance3D
	terrain.dust = model.find_child("Dust", true, false) as MeshInstance3D
	terrain.points = terrain.dust.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	restore_support()
	terrain.sample()
	super._physics_process(delta)
	settle_pose()


func update_energy_pose() -> void:
	if terrain.actor == null:
		super.update_energy_pose()
		return
	if not dead:
		terrain.release_live()
	super.update_energy_pose()
	settle_pose()


func settle_pose() -> void:
	if terrain.plane.is_empty():
		return
	if not dead:
		if terrain.split:
			restore_support()
		terrain.settle_live(-.014)
	elif animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
		terrain.settle(self)


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		fall.plane = {}
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	terrain.split = source.terrain.split
	var duration := terrain.begin_from_display(self, source, source.terrain, source.current_clip, false)
	if not source.dead and duration > 0.0:
		terrain.blend_length = minf(.16, duration)
		for bone in source.skeleton.get_bone_count():
			terrain.blend_pose.append(source.skeleton.get_bone_pose(bone))
		terrain.settle(self)
	return duration


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
