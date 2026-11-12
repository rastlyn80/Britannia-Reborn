# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CatGroundSupport.gd"

var split := false
var ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.DOWN, 1)
var bind_joints: Array[int] = []
var head_chain: Array[int] = []
var head_vertices: Array[int] = []
var terrain: RefCounted


func configure(mesh: MeshInstance3D, quadruped: bool) -> void:
	super.configure(mesh, quadruped)
	var rig := get_skeleton()
	for bind in mesh.skin.get_bind_count():
		var joint := mesh.skin.get_bind_bone(bind)
		bind_joints.append(joint if joint >= 0 else rig.find_bone(mesh.skin.get_bind_name(bind)))
	for foot: Dictionary in feet:
		foot["step_vertices"] = vertices_under(foot.b, .40)
	for name: String in ["neck", "head"]:
		var joint := bone(name)
		if joint >= 0:
			head_chain.append(joint)
	if not head_chain.is_empty():
		head_vertices = vertices_under(head_chain[0], .50)


func vertices_under(root_joint: int, threshold: float) -> Array[int]:
	var rig := get_skeleton()
	var descendants := {}
	for index in rig.get_bone_count():
		var parent := index
		while parent >= 0:
			if parent == root_joint:
				descendants[index] = true
				break
			parent = rig.get_bone_parent(parent)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var result: Array[int] = []
	var seen := {}
	for index in vertices.size():
		var weight := 0.0
		for influence in stride:
			var slot := index * stride + influence
			if descendants.has(bind_joints[joints[slot]]):
				weight += weights[slot]
		if weight >= threshold and not seen.has(vertices[index]):
			result.append(index)
			seen[vertices[index]] = true
	return result


func _process_modification_with_delta(delta: float) -> void:
	if not split:
		super._process_modification_with_delta(delta)
		return
	errors.clear()
	stance_gaps.clear()
	if not enabled:
		return
	for foot: Dictionary in feet:
		var sample := clearance(foot.step_vertices, true)
		var gap := float(sample.get("gap", INF))
		if not is_finite(gap) or gap > .01:
			continue
		for attempt in 4:
			if gap >= .001:
				break
			lift_paw(foot, sample.point, .0015 - gap)
			sample = clearance(foot.step_vertices, true)
			gap = float(sample.get("gap", INF))
		stance_gaps.append(gap)
		errors.append(absf(gap))
	for attempt in 3:
		for joint: int in head_chain:
			var hit := clearance(head_vertices)
			var gap := float(hit.get("gap", INF))
			if gap >= -.004:
				return
			turn_joint(joint, hit.point, .0015 - gap, .10)


func clearance(sample_vertices: Array[int], anticipatory := false) -> Dictionary:
	var rig := get_skeleton()
	var matrices: Array[Transform3D] = []
	for bind in surface.skin.get_bind_count():
		matrices.append(rig.global_transform * rig.get_bone_global_pose(bind_joints[bind]) * surface.skin.get_bind_pose(bind))
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var space := rig.get_world_3d().direct_space_state
	var gap := INF
	var result := {}
	for index: int in sample_vertices:
		var point := Vector3.ZERO
		for influence in stride:
			var slot := index * stride + influence
			if weights[slot] > 0.0:
				point += (matrices[joints[slot]] * vertices[index]) * weights[slot]
		ray.from = Vector3(point.x, origin_y + .45, point.z)
		ray.to = Vector3(point.x, origin_y - .45, point.z)
		var hit := space.intersect_ray(ray)
		if not hit.is_empty() and hit.normal.y > .8:
			var floor_height := float(terrain.approach_height(point, hit)) if anticipatory else float(hit.position.y)
			var current := point.y - floor_height
			if current < gap:
				gap = current
				result = {"gap": gap, "point": point}
	return result


func turn_joint(joint: int, point: Vector3, height: float, limit: float) -> void:
	var rig := get_skeleton()
	var pose := rig.get_bone_global_pose(joint)
	var arm := point - rig.to_global(pose.origin)
	var axis := arm.cross(Vector3.UP)
	var lever := axis.length()
	if lever < .001:
		return
	var angle := minf(height / lever, limit)
	var local_axis := (rig.global_basis.inverse() * (axis / lever)).normalized()
	pose.basis = Basis(Quaternion(local_axis, angle)) * pose.basis
	rig.set_bone_global_pose(joint, pose)


func lift_paw(foot: Dictionary, point: Vector3, height: float) -> void:
	var rig := get_skeleton()
	var ankle := rig.get_bone_global_pose(foot.c)
	# Bound the bend even if the requested tread is beyond the leg's reach.
	turn_joint(foot.b, point, height, .09)
	turn_joint(foot.a, point, height, .06)
	ankle.origin = rig.get_bone_global_pose(foot.c).origin
	rig.set_bone_global_pose(foot.c, ankle)
