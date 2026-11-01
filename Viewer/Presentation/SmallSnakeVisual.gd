extends "res://Presentation/CreatureVisual.gd"
## Legless source reuse with conservative animated skin bounds.
var influence_bounds: Dictionary={}
func _ready() -> void:
	super._ready()
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
