extends "res://Presentation/CreatureVisual.gd"
## Opt-in short-lift source limbs and conservative weighted-skin bounds.
var influence_bounds: Dictionary={}
func _ready() -> void:
	super._ready()
	contact.free();contact=preload("res://Presentation/BoglingSupport.gd").new();skeleton.add_child(contact)
	contact.include_toe_descendants=true
	contact.model_root=model;contact.flat_basis=source_model_basis.scaled_local(default_model_scale)
	contact.configure(model.find_children("*","MeshInstance3D",true,false)[0],entry.get("limb_support","")=="quadruped")
	var mesh: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
	for surface in mesh.mesh.get_surface_count():
		var arrays:=mesh.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var bindings: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		var stride:=bindings.size()/points.size()
		for vertex in points.size():
			for slot in stride:
				if weights[vertex*stride+slot]<=0.:continue
				var bind:=bindings[vertex*stride+slot];var bone:=mesh.skin.get_bind_bone(bind)
				if bone<0:bone=skeleton.find_bone(mesh.skin.get_bind_name(bind))
				var point: Vector3=mesh.skin.get_bind_pose(bind)*points[vertex]
				influence_bounds[bone]=(influence_bounds[bone] as AABB).expand(point) if influence_bounds.has(bone) else AABB(point,Vector3.ZERO)
	animator.mixer_applied.connect(update_landmarks)
	contact.modification_processed.connect(update_landmarks)
	update_landmarks()
	for category: String in animator.get_animation_list():animator.get_animation(category).loop_mode=Animation.LOOP_LINEAR if category in entry.loop_categories else Animation.LOOP_NONE
func update_landmarks() -> void:
	if influence_bounds.is_empty():return
	# A normalized positive blend lies inside the union's enclosing AABB.
	# Transform one cached box per used bone rather than skinning every vertex.
	var box:=AABB();var first:=true
	var local_rig:=global_transform.affine_inverse()*skeleton.global_transform
	for bone: int in influence_bounds:
		var transformed: AABB=(local_rig*skeleton.get_bone_global_pose(bone))*(influence_bounds[bone] as AABB)
		box=transformed if first else box.merge(transformed);first=false
	set_meta("nameplate_height",box.end.y+.08)
	set_meta("pick_bounds",box.grow(.025))
func _process(delta: float) -> void:
	super._process(delta)
	update_landmarks()

func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null:return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D;var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/BoglingSurface.gdshader")
			material.set_shader_parameter("albedo_texture",source.albedo_texture);material.set_shader_parameter("normal_texture",source.normal_texture);material.set_shader_parameter("use_normal",source.normal_enabled and source.normal_texture!=null);material.set_shader_parameter("normal_strength",source.normal_scale)
			var palette:=preload("res://Presentation/HumanHue.gd").palette(value)
			material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null);material.set_shader_parameter("partial_hue",(value&0x8000)!=0);mesh.set_surface_override_material(surface,material)
