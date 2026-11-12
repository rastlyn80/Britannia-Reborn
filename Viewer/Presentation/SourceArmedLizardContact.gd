# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceMountContact.gd"

const SoleClearance := .003
const FootContact := preload("res://Presentation/FootContact.gd")
var plane: Dictionary
var use_local_planes := false
var floor_query := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.DOWN, 1)
var support_appendages: Callable


func _process_modification_with_delta(delta: float) -> void:
	if plane.is_empty() and not use_local_planes:
		super._process_modification_with_delta(delta)
		return
	errors.clear()
	stance_gaps.clear()
	if not enabled:
		return
	for index in feet.size():
		var hit: Dictionary = contacts.get(index, {}) if use_local_planes else plane
		if hit.is_empty():
			continue
		var foot: Dictionary = feet[index]
		var sole := sample_sole(foot, hit)
		if sole.is_empty() or sole.gap > .02:
			continue
		for iteration in 6:
			if absf(sole.gap - SoleClearance) < .001 or (use_local_planes and sole.gap > SoleClearance):
				break
			if use_local_planes and sole.gap < -.025:
				lift_foot(foot, (SoleClearance - sole.gap) / float(sole.normal.y))
				var revised := sample_sole(foot, hit)
				if revised.is_empty():
					break
				sole = revised
				continue
			for joint: int in [foot.c, foot.b, foot.a]:
				if use_local_planes and sole.gap > SoleClearance:
					break
				rotate_toward_surface(joint, sole.point, sole.normal, SoleClearance - sole.gap)
				var revised := sample_sole(foot, hit)
				if revised.is_empty():
					break
				sole = revised
		stance_gaps.append(sole.gap)
		errors.append(absf(sole.gap))
	if use_local_planes and support_appendages.is_valid():
		support_appendages.call()


func lift_foot(foot: Dictionary, height: float) -> void:
	var rig := get_skeleton()
	var hip := rig.get_bone_global_pose(foot.a).origin
	var knee := rig.get_bone_global_pose(foot.b).origin
	var ankle := rig.get_bone_global_pose(foot.c)
	var target := ankle.origin + rig.global_basis.inverse() * Vector3.UP * minf(height, .24)
	aim(foot.a, foot.b, FootContact.knee_target(hip, knee, ankle.origin, target))
	aim(foot.b, foot.c, target)
	ankle.origin = rig.get_bone_global_pose(foot.c).origin
	rig.set_bone_global_pose(foot.c, ankle)


func rotate_toward_surface(joint: int, point: Vector3, normal: Vector3, offset: float) -> void:
	var rig := get_skeleton()
	var pose := rig.get_bone_global_pose(joint)
	var arm := point - rig.to_global(pose.origin)
	var axis := arm.cross(normal)
	var lever := axis.length()
	if lever < .001:
		return
	var angle := clampf(offset / lever, -.065, .065)
	var local_axis := (rig.global_basis.inverse() * (axis / lever)).normalized()
	pose.basis = Basis(Quaternion(local_axis, angle)) * pose.basis
	rig.set_bone_global_pose(joint, pose)


func sample_sole(foot: Dictionary, plane_hit: Dictionary) -> Dictionary:
	var rig := get_skeleton()
	var matrices: Array[Transform3D] = []
	for index in surface.skin.get_bind_count():
		var joint := surface.skin.get_bind_bone(index)
		if joint < 0:
			joint = rig.find_bone(surface.skin.get_bind_name(index))
		matrices.append(rig.global_transform * rig.get_bone_global_pose(joint) * surface.skin.get_bind_pose(index))
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var lowest := {}
	var minimum_gap := INF
	var world := surface.get_world_3d().direct_space_state if use_local_planes else null
	for vertex: int in foot.vertices:
		var point := Vector3.ZERO
		for slot in 4:
			var index := vertex * 4 + slot
			if weights[index] > 0.0:
				point += (matrices[bones[index]] * vertices[vertex]) * weights[index]
		var hit := plane_hit
		if use_local_planes:
			if point.y > origin_y + .65:
				continue
			floor_query.from = Vector3(point.x, origin_y + .65, point.z)
			floor_query.to = Vector3(point.x, origin_y - .65, point.z)
			hit = world.intersect_ray(floor_query)
			if hit.is_empty() or hit.normal.y < .8:
				continue
		var normal: Vector3 = hit.normal
		var gap := normal.dot(point - hit.position)
		if gap < minimum_gap:
			minimum_gap = gap
			lowest = {"point": point, "normal": normal, "gap": gap}
	return lowest


func step_conflict(root_floor: float, query: PhysicsRayQueryParameters3D, skins: Array[Dictionary]) -> Dictionary:
	# A nearby riser can be under the body or weapon while the center ray
	# is still on the lower surface. Only probe vertices below the local ceiling.
	var skeleton := get_skeleton()
	var lift := 0.0
	var conflict := {}
	var ceiling := root_floor + .65
	var world := get_world_3d().direct_space_state
	for skin in skins:
		var transforms: Array[Transform3D] = []
		for i in skin.bones.size():
			transforms.append(skeleton.global_transform * skeleton.get_bone_global_pose(skin.bones[i]) * skin.bind_poses[i])
		for surface: Dictionary in skin.surfaces:
			var points: PackedVector3Array = surface.points
			var bindings: PackedInt32Array = surface.bindings
			var weights: PackedFloat32Array = surface.weights
			var stride: int = surface.stride
			for vertex in points.size():
				var point := Vector3.ZERO
				for slot in stride:
					var index := vertex * stride + slot
					var weight := weights[index]
					if weight > 0.0:
						point += (transforms[bindings[index]] * points[vertex]) * weight
				if point.y + lift >= ceiling + SoleClearance:
					continue
				query.from = Vector3(point.x, ceiling, point.z)
				query.to = Vector3(point.x, root_floor - .65, point.z)
				var hit := world.intersect_ray(query)
				if not hit.is_empty() and hit.normal.y >= 0.8:
					var needed := float(hit.position.y) + SoleClearance / float(hit.normal.y) - point.y
					if needed > lift:
						lift = needed
						conflict = {"lift": lift, "normal": hit.normal, "point": point}
	return conflict
