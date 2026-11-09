extends "res://Presentation/SourceSolenVisual.gd"

const Fall := preload("res://Presentation/SourceSpaceFallPlayback.gd")
var fall := Fall.new()

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(settle_worker_fall)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		# The terrain-aware fall handles clearance from the first blended pose.
		blend_remaining = 0.0
	fall.accept_action(self)
	return true

func begin_death_from(source: Node3D) -> float:
	return fall.begin_from_source(self, source, source.fall, source.death_lift)

func settle_worker_fall() -> void:
	if not fall.plane.is_empty():
		fall.settle(self)
		update_landmarks()

func corpse_snapshot_floor() -> float:
	return INF if fall.plane.is_empty() else fall.snapshot_floor(self)
