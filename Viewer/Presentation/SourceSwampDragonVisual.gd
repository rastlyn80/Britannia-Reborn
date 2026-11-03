extends "res://Presentation/SourceRigMountVisual.gd"
## Original Swamp Dragon design, with authored modern fit and barding material.
func mount_fittings() -> Dictionary:
	return {"proportions":Vector3(.45,.65,.65),"saddle":Vector3(0.,1.73,-.35),"mouth":Vector3(0.,1.20,3.55),"seat_bone":"spine1","mouth_bone":"head","stirrup":Vector3(.40,-.60,.12)}
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null or treatment!="modern":return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if not mesh.visible:continue
		for surface in mesh.mesh.get_surface_count():
			var material:=mesh.get_active_material(surface) as ShaderMaterial
			if material!=null:material.set_shader_parameter("metallic_strength",.75 if kind=="swamp_dragon_armor" else 0.)
