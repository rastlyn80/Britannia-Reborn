extends "res://Presentation/CreatureVisual.gd"
## Wind/dust presentation and optional retained rigid source marker.
var wind_phase:=0.
var original_marker: Node3D
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null:return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():mesh.set_surface_override_material(surface,preload("res://Presentation/AirElementalMaterial.gd").build(value,wind_phase,mesh.name=="Dust"))
	if original_marker!=null:
		for mesh: MeshInstance3D in original_marker.find_children("*","MeshInstance3D",true,false):
			var material:=mesh.material_override as ShaderMaterial;var palette: Texture2D=null if value==0x4001 else preload("res://Presentation/HumanHue.gd").palette(value)
			material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null)
func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(update_wind_pose)
	# Proprietary marker remains optional local input, outside the public model.
	if ResourceLoader.exists("res://local-art/air/source-marker.gltf"):
		original_marker=load("res://local-art/air/source-marker.gltf").instantiate();add_child(original_marker);original_marker.position.y=.5;original_marker.visible=false
		for mesh: MeshInstance3D in original_marker.find_children("*","MeshInstance3D",true,false):
			var source:=mesh.mesh.surface_get_material(0) as StandardMaterial3D;var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/CreatureFlashSurface.gdshader");material.set_shader_parameter("albedo_texture",source.albedo_texture);material.set_shader_parameter("gain",0.);mesh.material_override=material;mesh.set_meta("source_death_flash",true)
		set_hue(native_hue)
	update_wind_pose()
func update_wind_pose() -> void:
	var fraction:=animator.current_animation_position/maxf(.001,animator.current_animation_length);wind_phase=TAU*fraction
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():mesh.get_active_material(surface).set_shader_parameter("phase",wind_phase)
	var highest:=0.
	for name in ["Head","hand_l","hand_r","upperarm_l","upperarm_r"]:
		var bone:=skeleton.find_bone(name)
		if bone>=0:highest=maxf(highest,to_local(skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)).y+(.42 if name=="Head" else .28))
	set_meta("nameplate_height",highest)
	if entry.has("pick_bounds"):
		var box: Dictionary=entry.pick_bounds;var p: Array=box.position;var s: Array=box.size
		set_meta("pick_bounds",AABB(Vector3(p[0],p[1],p[2])+model.position,Vector3(s[0],s[1],s[2])))
	if original_marker!=null:
		original_marker.visible=animator.assigned_animation in ["Death","Death2"] and fraction>0. and fraction<1.
		for mesh: MeshInstance3D in original_marker.find_children("*","MeshInstance3D",true,false):mesh.material_override.set_shader_parameter("gain",pow(sin(PI*fraction),2.))
func _physics_process(_delta: float) -> void:
	if dead or not is_inside_tree():return
	var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*2.,global_position+Vector3.DOWN*4.,1))
	model.position.y=clampf(to_local(hit.position).y,-1.25,1.25) if not hit.is_empty() else 0.
	update_wind_pose()
