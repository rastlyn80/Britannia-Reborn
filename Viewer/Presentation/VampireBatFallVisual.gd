extends "res://Presentation/CreatureVisual.gd"

var fall := preload("res://Presentation/CreatureFallPlayback.gd").new()

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(fall.settle.bind(self))

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	fall.accept_action(self)
	return true

func begin_death_from(source: Node3D) -> float:
	var remaining := fall.begin_from(self, source, source.fall)
	if not fall.blend_pose.is_empty():
		# Third Dawn stores a separate vertical translation on SourceSpace.
		# Keep that displayed offset in the blended root while entering the fall.
		var rig_root := skeleton.find_bone("__root")
		assert(rig_root >= 0 and skeleton.get_bone_parent(rig_root) < 0)
		var root_pose: Transform3D = fall.blend_pose[rig_root]
		var display_origin: Vector3 = source.skeleton.global_position
		var unshifted_origin := skeleton.global_position - global_basis * fall.shift
		root_pose.origin += skeleton.global_basis.inverse() * (display_origin - unshifted_origin)
		fall.blend_pose[rig_root] = root_pose
		fall.settle(self)
	return remaining

func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self)

