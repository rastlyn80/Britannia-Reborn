extends "res://Presentation/SourceRigMountVisual.gd"
## Original ordinary/Savage/ethereal Ridgeback meshes, not a horse substitution.
func mount_fittings() -> Dictionary:
	return {"proportions":Vector3(.70,.85,.85),"saddle":Vector3(0.,1.72,-.25),"mouth":Vector3(0.,1.60,1.42),"seat_bone":"spine","mouth_bone":"head","stirrup":Vector3(.36,-.58,.12)}
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null or treatment!="modern" or kind!="ridgeback_ridgeback_ethereal":return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if not mesh.visible:continue
		for surface in mesh.mesh.get_surface_count():
			var previous:=mesh.get_active_material(surface) as ShaderMaterial
			var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/OstardEthereal.gdshader")
			for parameter in ["albedo_texture","detail_strength"]:material.set_shader_parameter(parameter,previous.get_shader_parameter(parameter))
			var palette: Texture2D=preload("res://Presentation/HumanHue.gd").palette(value) if value!=0x4001 else null
			material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null);material.set_shader_parameter("partial_hue",(value&0x8000)!=0)
			material.set_shader_parameter("spectral_tint",Color(.70,.87,1.));mesh.set_surface_override_material(surface,material)
