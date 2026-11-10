# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/DisplayedCreatureFallPlayback.gd"
## Transfer the pose across animations with different SourceSpace transforms.

var initial_depth := 0.0

func begin_from_source(actor: Node3D, source: Node3D, previous: RefCounted,
		in_flight: bool, surfacing := false) -> float:
	# The avatar may still be turning towards the server's latest direction.
	actor.global_transform = source.global_transform
	if surfacing:
		var support := floor_under(source)
		var rig: Skeleton3D = source.skeleton
		var mesh := source.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(Ground.skin_points(mesh, rig), rig, rig.global_transform,
			support.position, support.normal)
		initial_depth = maxf(0.0, 0.002 - gap)
	var duration := begin_from_display(actor, source, previous, source.animator.assigned_animation, in_flight)
	if blend_pose.is_empty():
		blend_length = minf(0.24 if surfacing else 0.12, duration)
		if blend_length <= 0.0:
			return duration
		for bone in source.skeleton.get_bone_count():
			blend_pose.append(source.skeleton.get_bone_pose(bone))
	var rig: Skeleton3D = actor.skeleton
	var root := rig.find_bone("__root")
	assert(root >= 0 and rig.get_bone_parent(root) < 0)
	var pose := blend_pose[root]
	var target_space := rig.global_position - actor.global_basis * shift
	var source_space: Vector3 = source.skeleton.global_position - source.global_basis * previous.shift
	pose.origin += rig.global_basis.inverse() * (source_space - target_space)
	blend_pose[root] = pose
	settle(actor)
	return duration

func settle(actor: Node3D) -> void:
	if initial_depth <= 0.0 or plane.is_empty():
		super.settle(actor)
		return
	# Finish surfacing during the pose blend instead of lifting the first frame abruptly.
	var floor_position: Vector3 = plane.position
	var progress := smoothstep(0.0, blend_length, actor.animator.current_animation_position) if blend_length > 0.0 else 0.0
	plane.position = floor_position - plane.normal * initial_depth * (1.0 - progress)
	super.settle(actor)
	plane.position = floor_position
