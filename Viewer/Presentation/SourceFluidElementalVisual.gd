extends "res://Presentation/SourceElementalVisual.gd"
## Original Acid/Poison rigs share the measured elemental terrain support.
var fluid_clock:=0.
var fluid_materials: Array[ShaderMaterial]=[]
func set_hue(value: int) -> void:
	super.set_hue(value);fluid_materials.clear()
	if model==null or treatment!="modern":return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source==null:continue
			var material:=preload("res://Presentation/SourceFluidElementalMaterial.gd").build(source,entry,value,fluid_clock);mesh.set_surface_override_material(surface,material);fluid_materials.append(material)
func _process(delta: float) -> void:
	super._process(delta)
	if fluid_materials.is_empty() or dead and action_remaining<=0.:return
	# Explicit material time freezes with a finished death. Static cadavers
	# inherit the final value; the shader never reads the global TIME clock.
	fluid_clock+=delta
	for material in fluid_materials:material.set_shader_parameter("fluid_time",fluid_clock)
