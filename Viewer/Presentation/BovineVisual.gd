extends "res://Presentation/OstardMount.gd"
## Shared source quadruped adapter; gameplay, milking and taming stay native.
var recovering_tip:=false
func _process(delta: float) -> void:
	super._process(delta)
	if recovering_tip and action_remaining<=0.:
		recovering_tip=false;current_clip="";play_gait(false,0.)
func receive_action(request: Dictionary) -> bool:
	# Cow.Tip uses a death-group animation on a living animal. Corpse requests
	# lack this exact frame/repeat signature and still retain their death state.
	if native_body in [0xd8,0xe7] and str(request.get("protocol",""))=="classic" and int(request.get("action",-1))==8 and int(request.get("frames",-1))==0 and int(request.get("repeat_count",-1))==3:
		var tip:=request.duplicate(true);tip["action"]=11
		var accepted:=super.receive_action(tip);recovering_tip=accepted;set_meta("native_action",request.duplicate(true));return accepted
	recovering_tip=false
	return super.receive_action(request)
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null:return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var material:=mesh.get_surface_override_material(surface) as ShaderMaterial
			if material!=null:material.set_shader_parameter("dark_patches",native_body==0xd8)
