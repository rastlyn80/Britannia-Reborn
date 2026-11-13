# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedYomotsuWarriorVisual.gd"

class WarriorTerrain extends "res://Presentation/SourceCreatureTreadTerrain.gd":
	var blade: MeshInstance3D
	var blade_points := PackedVector3Array()
	var blade_skin: Dictionary

	func bind(visual: Node3D, footprint: Vector2) -> void:
		super.bind(visual, footprint)
		blade = visual.blade
		if blade.skin != null:
			blade_skin = Ground.skin_points(blade, actor.skeleton)
			return
		for surface in blade.mesh.get_surface_count():
			blade_points.append_array(blade.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])

	func blade_gap() -> float:
		if not blade.visible:
			return INF
		if not blade_skin.is_empty():
			var rig: Skeleton3D = actor.skeleton
			if split:
				var body_skin := skin
				skin = blade_skin
				var depth := step_gap(rig)
				skin = body_skin
				return depth
			return Ground.minimum_plane_gap(blade_skin, rig, rig.global_transform, plane.position, plane.normal)
		if split:
			return piece_step_gap(blade_points, blade.global_transform, plane)
		var gap := INF
		for point in blade_points:
			gap = minf(gap, plane.normal.dot(blade.to_global(point) - plane.position))
		return gap

	func settle_live(allowed_depth := 0.0) -> void:
		super.settle_live(allowed_depth)
		var lift := maxf(0.0, (.003 - allowed_depth - blade_gap()) / (1.0 if split else float(plane.normal.y)))
		actor.model.global_position.y += lift
		live_lift += lift

	func settle(visual: Node3D) -> void:
		super.settle(visual)
		if plane.is_empty():
			return
		var lift := maxf(0.0, (.002 - blade_gap()) / (1.0 if split else float(plane.normal.y)))
		var before: Vector3 = visual.model.position
		visual.model.global_position.y += lift
		shift += visual.model.position - before

	func snapshot_floor(visual: Node3D) -> float:
		var floor := super.snapshot_floor(visual)
		if blade.visible and not blade_skin.is_empty():
			var rig: Skeleton3D = visual.skeleton
			var local_rig := visual.global_transform.affine_inverse() * rig.global_transform
			floor = minf(floor, Ground.minimum_plane_gap(blade_skin, rig, local_rig, Vector3.ZERO, Vector3.UP))
		elif blade.visible:
			for point in blade_points:
				floor = minf(floor, visual.to_local(blade.to_global(point)).y)
		return floor


var terrain := WarriorTerrain.new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.8, 1.6))
	animator.mixer_applied.connect(settle_pose)
	contact.modification_processed.connect(settle_pose)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	settle_pose()


func settle_pose() -> void:
	if terrain.plane.is_empty():
		return
	if not dead:
		terrain.settle_live(.0005)
	elif animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
		terrain.settle(self)


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	unarmed_fall = source.is_fitted()
	blade.visible = not unarmed_fall
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
