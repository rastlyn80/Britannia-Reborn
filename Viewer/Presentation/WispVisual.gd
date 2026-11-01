extends "res://Presentation/CreatureVisual.gd"
## Independently authored energy actor. No gameplay or native entity transforms.
var energy_phase:=0.
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null:return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as ShaderMaterial
			if source!=null:mesh.set_surface_override_material(surface,preload("res://Presentation/WispMaterial.gd").build(source,value,energy_phase))
func _ready() -> void:
	super._ready()
	for category: String in animator.get_animation_list():animator.get_animation(category).loop_mode=Animation.LOOP_LINEAR if category in entry.get("loop_categories",["Idle","Walk","Run"]) else Animation.LOOP_NONE
	animator.mixer_applied.connect(update_energy_pose)
	update_energy_pose()
func update_energy_pose() -> void:
	energy_phase=TAU*animator.current_animation_position/maxf(.001,animator.current_animation_length)
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var material:=mesh.get_active_material(surface) as ShaderMaterial
			if material!=null:material.set_shader_parameter("phase",energy_phase)
	var tip:=skeleton.find_bone("Ray0")
	if tip>=0:set_meta("nameplate_height",to_local(skeleton.to_global(skeleton.get_bone_global_pose(tip)*Vector3(0,.4,0))).y+.1)
	if entry.has("pick_bounds"):
		var bounds: Dictionary=entry.pick_bounds;var p: Array=bounds.position;var s: Array=bounds.size
		set_meta("pick_bounds",AABB(Vector3(float(p[0]),float(p[1]),float(p[2]))+model.position,Vector3(float(s[0]),float(s[1]),float(s[2]))))
func _physics_process(_delta: float) -> void:
	# Hover above the actual finite surface; native coordinates remain untouched.
	# Ray queries ignore selection Areas, and the visual has no collision body.
	if dead or not is_inside_tree():return
	var query:=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*2.,global_position+Vector3.DOWN*4.,1)
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	model.position.y=clampf(to_local(hit.position).y,-1.25,1.25) if not hit.is_empty() else 0.
	update_energy_pose()
