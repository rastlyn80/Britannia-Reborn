extends "res://Presentation/SourceLavaSerpentVisual.gd"
## Preserve the visible pose of the newly routed alternate collapse.

var fall := preload("res://Presentation/CreatureFallPlayback.gd").new()

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip == "Death2":
		fall.accept_action(self)
	elif not fall.plane.is_empty():
		model.position -= fall.shift
		fall.shift = Vector3.ZERO
		fall.plane.clear()
		fall.blend_pose.clear()
	return true

func apply_ground() -> void:
	if fall.plane.is_empty():
		super.apply_ground()
		return
	fall.settle(self)
	update_landmarks()

func begin_death_from(source: Node3D) -> float:
	if not source.dead or source.current_clip != "Death2":
		return super.begin_death_from(source)
	var remaining := fall.begin_from(self, source, source.fall)
	if not fall.blend_pose.is_empty():
		# The donor collapse animates SourceSpace separately from the root bone.
		var root := skeleton.find_bone("__root")
		assert(root >= 0 and skeleton.get_bone_parent(root) < 0)
		var pose: Transform3D = fall.blend_pose[root]
		var unshifted := skeleton.global_position - global_basis * fall.shift
		var source_unshifted: Vector3 = source.skeleton.global_position - source.global_basis * source.fall.shift
		pose.origin += skeleton.global_basis.inverse() * (source_unshifted - unshifted)
		fall.blend_pose[root] = pose
		fall.settle(self)
	return remaining

func corpse_snapshot_floor() -> float:
	# The original death still hands off to its registered static model.
	return INF if fall.plane.is_empty() else fall.snapshot_floor(self)
