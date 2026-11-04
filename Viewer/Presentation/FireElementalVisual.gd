extends "res://Presentation/CreatureVisual.gd"
## Private procedural flame actor; native movement and gameplay stay outside.
var fire_phase:=0.
var envelopes: Dictionary={}
var meshes: Array[MeshInstance3D]=[]
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null:return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		# Each component has one material; keep visibility transitions independent
		# of per-surface override updates in the headless renderer.
		mesh.material_override=preload("res://Presentation/FireElementalMaterial.gd").build(value,fire_phase,mesh.name=="Ash")
func _ready() -> void:
	super._ready();contact.enabled=false;contact.active=false
	preload("res://Presentation/ElementalClassicGestures.gd").install(animator, skeleton, model.scene_file_path, entry)
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		meshes.append(mesh);mesh.extra_cull_margin=.08;var boxes: Dictionary={}
		if mesh.skin==null:continue
		for surface in mesh.mesh.get_surface_count():
			var a:=mesh.mesh.surface_get_arrays(surface);var points: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var joints: PackedInt32Array=a[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride:=joints.size()/points.size()
			for vertex in points.size():
				for slot in stride:
					if weights[vertex*stride+slot]<=0.:continue
					var bind:=joints[vertex*stride+slot];var bone:=mesh.skin.get_bind_bone(bind)
					if bone<0:bone=skeleton.find_bone(mesh.skin.get_bind_name(bind))
					var point: Vector3=mesh.skin.get_bind_pose(bind)*points[vertex]
					boxes[bone]=(boxes[bone] as AABB).expand(point) if boxes.has(bone) else AABB(point,Vector3.ZERO)
		envelopes[mesh.get_instance_id()]=boxes
	animator.mixer_applied.connect(update_fire_pose);update_fire_pose()
func update_fire_pose() -> void:
	fire_phase=TAU*float(animator.current_animation_position)/maxf(.001,float(animator.current_animation_length));var first:=true;var bounds:=AABB();var inverse:=global_transform.affine_inverse()
	for mesh: MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():mesh.get_active_material(surface).set_shader_parameter("phase",fire_phase)
		if not mesh.is_visible_in_tree():continue
		if mesh.skin==null:
			var box: AABB=(inverse*mesh.global_transform)*mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
		else:
			var boxes: Dictionary=envelopes[mesh.get_instance_id()];var reference:=inverse*skeleton.global_transform
			for bone: int in boxes:
				var box: AABB=(reference*skeleton.get_bone_global_pose(bone))*(boxes[bone] as AABB);bounds=box if first else bounds.merge(box);first=false
	if not first:set_meta("nameplate_height",bounds.end.y+.16);set_meta("pick_bounds",bounds.grow(.08))
func _physics_process(_delta: float) -> void:
	if dead or not is_inside_tree():return
	var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*2.,global_position+Vector3.DOWN*4.,1))
	model.position.y=clampf(to_local(hit.position).y,-1.25,1.25) if not hit.is_empty() else 0.;update_fire_pose()
