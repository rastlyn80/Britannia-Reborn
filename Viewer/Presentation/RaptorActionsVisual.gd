extends "res://Presentation/SourcePreservingCreatureVisual.gd"

const Variants := preload("res://Presentation/CreatureModeZeroVariants.gd")
var fall := preload("res://Presentation/CreatureFallPlayback.gd").new()
var gait := preload("res://Presentation/UopMonsterGait.gd").new()

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(fall.settle.bind(self))

func set_native_combat_flags(flags: int) -> void:
	gait.set_flags(flags)

func play_gait(moving: bool, speed: float) -> void:
	if not gait.play(self, moving, speed, "RaptorPeaceWalk"):
		super.play_gait(moving, speed)

func receive_action(request: Dictionary) -> bool:
	var base := entry
	if request.get("protocol") == "new" and int(request.get("type", -1)) == 5 and int(request.get("variation", 0)) == 1:
		entry = entry.merged({"new_action_categories": {"5": "RaptorLowerHead"}}, true)
	else:
		entry = Variants.entry_for_packet(entry, request)
	var handled := super.receive_action(request)
	entry = base
	if handled:
		fall.accept_action(self)
	return handled

func support_control_plane() -> void:
	if not dead:
		super.support_control_plane()

func begin_death_from(source: Node3D) -> float:
	# The transition has already copied the displayed model placement, including
	# the stance-foot lift. Preserve it when blending out of a living pose.
	var duration := fall.begin_from(self, source, source.fall)
	if not source.dead:
		fall.blend_length = minf(0.08, duration)
		for bone in source.skeleton.get_bone_count():
			fall.blend_pose.append(source.skeleton.get_bone_pose(bone))
		fall.settle(self)
	return duration

func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self)
