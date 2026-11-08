extends "res://Presentation/SourceBloodElementalVisual.gd"

const Fall := preload("res://Presentation/SourceSpaceFallPlayback.gd")
var fall := Fall.new()

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	fall.accept_action(self)
	return true

func begin_death_from(source: Node3D) -> float:
	if not source.dead or source.fall.plane.is_empty():
		return super.begin_death_from(source)
	fluid_clock = source.fluid_clock
	for material: ShaderMaterial in fluid_materials:
		material.set_shader_parameter("fluid_time", fluid_clock)
	return fall.begin_from_source(self, source, source.fall)

func support_death_blend() -> void:
	if dead and not fall.plane.is_empty():
		fall.settle(self)
		update_landmarks()
	else:
		super.support_death_blend()

func corpse_snapshot_floor() -> float:
	var local := global_transform.affine_inverse() * skeleton.global_transform
	return Ground.minimum_plane_gap(support_skin, skeleton, local, Vector3.ZERO, Vector3.UP)
