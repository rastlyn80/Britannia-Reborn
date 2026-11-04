extends "res://Presentation/SourceDragonBreathVisual.gd"

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
	return fall.begin_from(self, source, source.fall)

func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self)
