extends "res://Presentation/SourcePreservingCreatureVisual.gd"
## Original construct atlas with brushed metal on its neutral iron regions.
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null or treatment!="modern":return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if not mesh.visible:continue
		for surface in mesh.mesh.get_surface_count():
			var previous:=mesh.get_surface_override_material(surface) as ShaderMaterial
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if previous==null or source==null:continue
			var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/CreatureCutoutSurface.gdshader")
			for parameter in ["albedo_texture","hue_palette","use_hue","partial_hue","detail_strength"]:
				material.set_shader_parameter(parameter,previous.get_shader_parameter(parameter))
			material.set_shader_parameter("source_alpha_texture",source.albedo_texture)
			material.set_shader_parameter("metallic_strength",.85)
			mesh.set_surface_override_material(surface,material)
