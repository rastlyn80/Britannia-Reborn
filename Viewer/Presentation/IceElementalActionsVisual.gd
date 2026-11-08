extends "res://Presentation/SourceIceElementalVisual.gd"

var fall := preload("res://Presentation/SourceSpaceFallPlayback.gd").new()

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	fall.accept_action(self)
	return true

func begin_death_from(source: Node3D) -> float:
	if source.dead and not source.fall.plane.is_empty():
		return fall.begin_from_source(self, source, source.fall)
	var remaining := super.begin_death_from(source)
	fall.remember_floor(self, fall.floor_under(self))
	fall.settle(self)
	return remaining

func apply_ice_ground() -> void:
	if fall.shift != Vector3.ZERO:
		model.position -= fall.shift
		fall.shift = Vector3.ZERO
	super.apply_ice_ground()
	if dead and not fall.plane.is_empty():
		fall.settle(self)

func corpse_snapshot_floor() -> float:
	var space := global_transform.affine_inverse() * skeleton.global_transform
	return Ground.minimum_plane_gap(support_skin, skeleton, space, Vector3.ZERO, Vector3.UP)
