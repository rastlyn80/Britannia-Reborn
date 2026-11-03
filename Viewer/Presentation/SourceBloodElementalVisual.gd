extends "res://Presentation/SourceFluidElementalVisual.gd"
## Exact Acid source-skin variant; own blood atlas and isolated displayed death.
signal landmarks_changed
var pose_entry:=preload("res://Presentation/SourceVariantPoseEntry.gd").new()
func _capture_variant_frame() -> void:pose_entry.capture_frame(self)
func _ready() -> void:
	super._ready()
	pose_entry.configure(self,model.position)
func update_landmarks() -> void:
	super.update_landmarks()
	if not influence_bounds.is_empty():landmarks_changed.emit()
func support_death_blend() -> void:
	if pose_entry.active:pose_entry.support(self)
	else:super.support_death_blend()
func begin_death_from(source: Node3D) -> float:
	fluid_clock=source.fluid_clock
	for material: ShaderMaterial in fluid_materials:material.set_shader_parameter("fluid_time",fluid_clock)
	return pose_entry.begin(self,source)
