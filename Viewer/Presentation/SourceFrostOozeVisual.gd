extends "res://Presentation/SourcePreservingCreatureVisual.gd"
## Baked source skin and ice-coloured gel; no second runtime subdivision.
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null or treatment!="modern":return
	var surface_entry:={"source_atlas_texture":entry.source_alpha_texture,"amorphous_surface":"slime"}
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if not mesh.visible:continue
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source==null:continue
			var material:=preload("res://Presentation/SourceAmorphousMaterial.gd").build(source,surface_entry,value)
			material.set_shader_parameter("gel_strength",0.)
			mesh.set_surface_override_material(surface,material)
