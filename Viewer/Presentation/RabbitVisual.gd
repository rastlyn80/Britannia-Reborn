extends "res://Presentation/CreatureVisual.gd"
## Original donor rig, eight-weight body/fur, actual paws and ear-tip anchor.
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null or treatment!="modern":return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source!=null:mesh.set_surface_override_material(surface,preload("res://Presentation/RabbitMaterial.gd").build(source,value))
func _ready() -> void:
	super._ready()
	var body:=model.find_child("Rabbit",true,false) as MeshInstance3D
	assert(body!=null,"Source rabbit body mesh must remain identifiable apart from alpha fur")
	contact.free();contact=preload("res://Presentation/RabbitGroundSupport.gd").new();skeleton.add_child(contact);contact.configure(body,true)
func _process(delta: float) -> void:
	super._process(delta)
	var highest: float=float(get_meta("nameplate_height",.5))
	# Folded ears/head can sit below the back during a genuine bounding hop.
	var ratio:=model.scale.length()/maxf(.0001,default_model_scale.length())
	for name: String in ["Hips","Spine","Spine.001"]:
		var index:=skeleton.find_bone(name)
		if index>=0:highest=maxf(highest,to_local(skeleton.to_global(skeleton.get_bone_global_pose(index).origin)).y+.18*ratio)
	for tip: Dictionary in entry.get("nameplate_tips",[]):
		var index:=skeleton.find_bone(str(tip.bone))
		if index<0:continue
		var offset: Array=tip.local_tip;var point:=skeleton.to_global(skeleton.get_bone_global_pose(index)*Vector3(float(offset[0]),float(offset[1]),float(offset[2])))
		highest=maxf(highest,to_local(point).y+.06)
	set_meta("nameplate_height",highest)
