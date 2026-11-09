extends "res://Presentation/TerathanActionsVisual.gd"
## Keep a flying Gargoyle's displayed pose when its recovered air fall takes over.

func begin_death_from(source: Node3D) -> float:
	if source.dead or source.current_clip not in Fall.FLIGHT:
		return super.begin_death_from(source)

	# The shared airborne path already captures a full pose. Only adjust
	# its root for movement on SourceSpace before the fall starts.
	var duration := fall.begin_from(self, source, source.fall)
	if not fall.blend_pose.is_empty():
		var root := skeleton.find_bone("__root")
		assert(root >= 0 and skeleton.get_bone_parent(root) < 0)
		var pose: Transform3D = fall.blend_pose[root]
		var target_space := skeleton.global_position - global_basis * fall.shift
		var source_space: Vector3 = source.skeleton.global_position - source.global_basis * source.fall.shift
		pose.origin += skeleton.global_basis.inverse() * (source_space - target_space)
		fall.blend_pose[root] = pose
		fall.settle(self)
	return duration
