extends "res://Presentation/SourceMageVisual.gd"
## Carry the visible source robe and pose into the ordinary death animation.

var fall := preload("res://Presentation/SourceSpaceFallPlayback.gd").new()

func apply_blend_ground() -> void:
	if fall.plane.is_empty():
		super.apply_blend_ground()
	else:
		fall.settle(self)
		update_landmarks()

func begin_death_from(source: Node3D) -> float:
	return fall.begin_from_source(self, source, source.fall)

func corpse_snapshot_floor() -> float:
	return INF if fall.plane.is_empty() else fall.snapshot_floor(self)
