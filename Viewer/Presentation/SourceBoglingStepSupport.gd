# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/BoglingSupport.gd"

const FootContact := preload("res://Presentation/FootContact.gd")
const Clearance := .003
var split := false
var floor_ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.DOWN, 1)


func _process_modification_with_delta(delta: float) -> void:
	if not split:
		super._process_modification_with_delta(delta)
		return
	errors.clear()
	stance_gaps.clear()
	if not enabled:
		return
	for foot: Dictionary in feet:
		for attempt in 3:
			var lift := tread_lift(foot)
			if lift < .001:
				break
			raise_foot(foot, lift)


func tread_lift(foot: Dictionary) -> float:
	var rig := get_skeleton()
	var matrices: Array[Transform3D] = []
	for bind in surface.skin.get_bind_count():
		var bone := surface.skin.get_bind_bone(bind)
		if bone < 0:
			bone = rig.find_bone(surface.skin.get_bind_name(bind))
		matrices.append(rig.global_transform * rig.get_bone_global_pose(bone) * surface.skin.get_bind_pose(bind))
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var space := get_world_3d().direct_space_state
	var lift := 0.0
	for vertex: int in foot.vertices:
		var point := Vector3.ZERO
		var first := vertex * stride
		for slot in range(first, first + stride):
			if weights[slot] > 0.0:
				point += (matrices[joints[slot]] * vertices[vertex]) * weights[slot]
		if point.y + lift > origin_y + .45 + Clearance:
			continue
		floor_ray.from = Vector3(point.x, origin_y + .65, point.z)
		floor_ray.to = Vector3(point.x, origin_y - .65, point.z)
		var hit := space.intersect_ray(floor_ray)
		if not hit.is_empty() and hit.normal.y > .8 and absf(hit.position.y - origin_y) < .45:
			lift = maxf(lift, float(hit.position.y) + Clearance - point.y)
	return lift


func raise_foot(foot: Dictionary, height: float) -> void:
	var rig := get_skeleton()
	var hip := rig.get_bone_global_pose(foot.a).origin
	var knee := rig.get_bone_global_pose(foot.b).origin
	var ankle := rig.get_bone_global_pose(foot.c)
	var target := ankle.origin + rig.global_basis.inverse() * Vector3.UP * minf(height, .24)
	aim(foot.a, foot.b, FootContact.knee_target(hip, knee, ankle.origin, target))
	aim(foot.b, foot.c, target)
	ankle.origin = rig.get_bone_global_pose(foot.c).origin
	rig.set_bone_global_pose(foot.c, ankle)
