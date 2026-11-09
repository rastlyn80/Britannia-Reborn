extends "res://Presentation/ArchiveOccurrenceGestureVisual.gd"

var fall := preload("res://Presentation/SourceSpaceFallPlayback.gd").new()

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(fall.settle.bind(self))

func receive_action(request: Dictionary) -> bool:
	var played := super.receive_action(request)
	if played:
		fall.accept_action(self)
	return played

func begin_death_from(source: Node3D) -> float:
	return fall.begin_from_source(self, source, source.fall)

func corpse_snapshot_floor() -> float:
	return INF if fall.plane.is_empty() else fall.snapshot_floor(self)
