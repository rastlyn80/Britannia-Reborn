extends "res://Presentation/SourceGroundedGestureVisual.gd"

var fall := preload("res://Presentation/SourceSpaceFallPlayback.gd").new()

func _ready() -> void:
	super._ready()
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	reference_skin = Ground.skin_points(mesh, skeleton)
	animator.mixer_applied.connect(settle_fall)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	release_gesture_lift()
	fall.accept_action(self)
	return true

func begin_death_from(source: Node3D) -> float:
	return fall.begin_from_source(self, source, source.fall)

func settle_fall() -> void:
	if dead and not fall.plane.is_empty():
		fall.settle(self)

func corpse_snapshot_floor() -> float:
	return INF if fall.plane.is_empty() else fall.snapshot_floor(self)
