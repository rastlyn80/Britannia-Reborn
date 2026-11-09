extends "res://Presentation/ArchiveGestureVisual.gd"

const Variants := preload("res://Presentation/CreatureModeZeroVariants.gd")
var gait := preload("res://Presentation/UopMonsterGait.gd").new()
var fall := preload("res://Presentation/SourceSpaceFallPlayback.gd").new()

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(fall.settle.bind(self))

func set_native_combat_flags(flags: int) -> void:
	gait.set_flags(flags)

func play_gait(moving: bool, speed: float) -> void:
	if not gait.play(self, moving, speed, "FireGargoylePeaceWalk"):
		super.play_gait(moving, speed)

func receive_action(request: Dictionary) -> bool:
	var base := entry
	if request.get("protocol") == "new" and int(request.get("type", -1)) == 5 and int(request.get("variation", 0)) == 1:
		entry = entry.merged({"new_action_categories": {"5": "FireGargoyleFlare"}}, true)
	else:
		entry = Variants.entry_for_packet(entry, request)
	var accepted := super.receive_action(request)
	entry = base
	if accepted:
		fall.accept_action(self)
	return accepted

func begin_death_from(source: Node3D) -> float:
	return fall.begin_from_source(self, source, source.fall)

func corpse_snapshot_floor() -> float:
	return INF if fall.plane.is_empty() else fall.snapshot_floor(self)
