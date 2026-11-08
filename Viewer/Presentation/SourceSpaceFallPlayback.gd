extends "res://Presentation/CreatureFallPlayback.gd"
## Transfer a displayed pose whose animation can move both the rig and SourceSpace.

func begin_from_source(actor: Node3D, source: Node3D, previous: RefCounted,
		source_live_shift := Vector3.ZERO) -> float:
	actor.model.position -= source_live_shift
	var duration := super.begin_from(actor, source, previous)
	if not source.dead:
		blend_length = minf(0.08, duration)
		for bone in source.skeleton.get_bone_count():
			blend_pose.append(source.skeleton.get_bone_pose(bone))
	if not blend_pose.is_empty():
		var rig: Skeleton3D = actor.skeleton
		var root := rig.find_bone("__root")
		assert(root >= 0 and rig.get_bone_parent(root) < 0)
		var pose := blend_pose[root]
		var target_space := rig.global_position - actor.global_basis * shift
		var source_space: Vector3 = source.skeleton.global_position - source.global_basis * (previous.shift + source_live_shift)
		pose.origin += rig.global_basis.inverse() * (source_space - target_space)
		blend_pose[root] = pose
		settle(actor)
	return duration
