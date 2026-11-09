extends "res://Presentation/SourcePreservingCreatureVisual.gd"

const Fall := preload("res://Presentation/SourceSpaceFallPlayback.gd")
var fall := Fall.new()

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(settle_collapse)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	fall.accept_action(self)
	return true

func begin_death_from(source: Node3D) -> float:
	return fall.begin_from_source(self, source, source.fall, source.clearance_lift)

func settle_collapse() -> void:
	if not fall.plane.is_empty():
		fall.settle(self)
		update_landmarks()

func corpse_snapshot_floor() -> float:
	return INF if fall.plane.is_empty() else fall.snapshot_floor(self)
