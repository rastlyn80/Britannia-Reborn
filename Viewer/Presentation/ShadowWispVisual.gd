extends "res://Presentation/WispVisual.gd"
## Shared owned rig/actions; body165 has an intrinsic shadow surface at hue0.
func _ready() -> void:
	super._ready()
	model.scale*=.85;default_model_scale=model.scale
	update_energy_pose()
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null:return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var material:=mesh.get_surface_override_material(surface) as ShaderMaterial
			if material!=null:material.shader=preload("res://Presentation/ShadowWispSurface.gdshader")
