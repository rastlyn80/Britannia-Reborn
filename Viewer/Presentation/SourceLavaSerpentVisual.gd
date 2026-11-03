extends "res://Presentation/SourceSilverSerpentVisual.gd"
## Same proved serpent skin/rig/support, with the original lava atlas retained.
signal landmarks_changed
var pose_entry:=preload("res://Presentation/SourceVariantPoseEntry.gd").new()
func _capture_variant_frame() -> void:pose_entry.capture_frame(self)
func _ready() -> void:
	super._ready()
	pose_entry.configure(self,source_position)
func update_landmarks() -> void:
	super.update_landmarks()
	if not influence_bounds.is_empty():landmarks_changed.emit()
func apply_ground() -> void:
	if pose_entry.active:pose_entry.support(self)
	else:super.apply_ground()
func begin_death_from(source: Node3D) -> float:return pose_entry.begin(self,source)
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null or treatment!="modern":return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var material:=mesh.get_surface_override_material(surface) as ShaderMaterial
			if material==null:continue
			material.shader=preload("res://Presentation/SourceLavaSerpentSurface.gdshader")
			material.set_shader_parameter("darken_authored_eyes",false)
			material.set_shader_parameter("albedo_gain",.85)
