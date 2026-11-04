extends "res://Presentation/SourceArmedLizardmanVisual.gd"

func set_hue(value: int) -> void:
	super.set_hue(value)
	if model == null:
		return
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.has_meta("source_visual_prop"):
			for surface in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(surface, null)
