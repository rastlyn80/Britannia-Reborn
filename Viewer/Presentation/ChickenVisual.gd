extends "res://Presentation/CreatureVisual.gd"
## The original independent foot roots and seven curved-bone joints stay intact.
var influence_bounds: Dictionary={}
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null or treatment!="modern":return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source!=null:mesh.set_surface_override_material(surface,preload("res://Presentation/ChickenMaterial.gd").build(source,value))
func _ready() -> void:
	super._ready()
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var a:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var binds: PackedInt32Array=a[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride:=binds.size()/vertices.size()
			for vertex in vertices.size():
				for slot in stride:
					if weights[vertex*stride+slot]<=0.:continue
					var bind:=binds[vertex*stride+slot];var bone:=mesh.skin.get_bind_bone(bind)
					if bone<0:bone=skeleton.find_bone(mesh.skin.get_bind_name(bind))
					var p: Vector3=mesh.skin.get_bind_pose(bind)*vertices[vertex]
					influence_bounds[bone]=(influence_bounds[bone] as AABB).expand(p) if influence_bounds.has(bone) else AABB(p,Vector3.ZERO)
	animator.mixer_applied.connect(update_landmarks);contact.modification_processed.connect(update_landmarks);update_landmarks()
func update_landmarks() -> void:
	var box:=AABB();var first:=true;var local_rig:=global_transform.affine_inverse()*skeleton.global_transform
	for bone: int in influence_bounds:
		var part: AABB=(local_rig*skeleton.get_bone_global_pose(bone))*(influence_bounds[bone] as AABB);box=part if first else box.merge(part);first=false
	if first:return
	set_meta("pick_bounds",box.grow(.015));set_meta("nameplate_height",box.end.y+.06)
func _process(delta: float) -> void:
	super._process(delta);update_landmarks()
