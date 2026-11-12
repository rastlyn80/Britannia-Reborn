# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceQuadrupedStepGround.gd"


func _process_modification_with_delta(delta: float) -> void:
	if enabled and use_local_planes and visual.current_clip in ["Walk", "Run"]:
		prepare_hooves_for_tread()
	super._process_modification_with_delta(delta)


func prepare_hooves_for_tread() -> void:
	var space := get_world_3d().direct_space_state
	var forward := visual.global_basis.z.slide(Vector3.UP).normalized()
	var side := forward.cross(Vector3.UP)
	var directions := [forward, -forward, side, -side]
	var height: float = ground.position.y
	for foot: Dictionary in feet:
		var point := sole(foot)
		if point.y > height + .32:
			continue
		var support := hit_at(space, point, height)
		if support.is_empty():
			continue
		var rise := 0.0
		for distance: float in [.022, .060, .125, .21]:
			var weight := 1.0 - smoothstep(.0, .24, distance)
			for direction: Vector3 in directions:
				var hit := hit_at(space, point + direction * distance, height)
				if hit.is_empty() or float(hit.position.y) - float(support.position.y) < .045:
					continue
				rise = maxf(rise, weight * maxf(0.0, float(hit.position.y) + SoleClearance - point.y))
		if rise > .003:
			lift_foot(foot, rise)


func lift_foot(foot: Dictionary, height: float) -> void:
	var rig := get_skeleton()
	var hip := rig.get_bone_global_pose(foot.a).origin
	var knee := rig.get_bone_global_pose(foot.b).origin
	var ankle := rig.get_bone_global_pose(foot.c).origin
	var ankle_rotation := rig.get_bone_pose_rotation(foot.c)
	var prior_parent := parent_basis(rig, foot.c).orthonormalized().get_rotation_quaternion()
	var target := ankle + rig.global_basis.inverse() * Vector3.UP * minf(height, .24)
	aim(foot.a, foot.b, FootContact.knee_target(hip, knee, ankle, target))
	aim(foot.b, foot.c, target)
	var new_parent := parent_basis(rig, foot.c).orthonormalized().get_rotation_quaternion()
	rig.set_bone_pose_rotation(foot.c, (new_parent.inverse() * prior_parent * ankle_rotation).normalized())


func aim(joint: int, child: int, target: Vector3) -> void:
	var rig := get_skeleton()
	var center := rig.get_bone_global_pose(joint).origin
	var into_parent := parent_basis(rig, joint).inverse()
	var current := into_parent * (rig.get_bone_global_pose(child).origin - center)
	var desired := into_parent * (target - center)
	if minf(current.length_squared(), desired.length_squared()) <= .000001:
		return
	var turn := Quaternion(current.normalized(), desired.normalized())
	rig.set_bone_pose_rotation(joint, (turn * rig.get_bone_pose_rotation(joint)).normalized())


func rotate_toward_surface(joint: int, point: Vector3, normal: Vector3, offset: float) -> void:
	var rig := get_skeleton()
	var center := rig.to_global(rig.get_bone_global_pose(joint).origin)
	var axis := (point - center).cross(normal)
	var lever := axis.length()
	if lever < .001:
		return
	var into_parent := parent_basis(rig, joint).inverse() * rig.global_basis.inverse()
	var angle := clampf(offset / lever, -.065, .065)
	var turn := Quaternion((into_parent * axis).normalized(), angle)
	rig.set_bone_pose_rotation(joint, (turn * rig.get_bone_pose_rotation(joint)).normalized())


func parent_basis(rig: Skeleton3D, joint: int) -> Basis:
	var parent := rig.get_bone_parent(joint)
	return Basis.IDENTITY if parent < 0 else rig.get_bone_global_pose(parent).basis
