extends "res://Presentation/SourceMountContact.gd"
## Keep the authored sole lift while adapting each source limb to its plane.
var model_root: Node3D
var flat_basis:=Basis.IDENTITY
func configure(mesh: MeshInstance3D,quadruped: bool) -> void:
	assert(mesh.mesh.get_surface_count()==1,"Measured source support requires one surface")
	var data:=mesh.mesh.surface_get_arrays(0)
	assert(data[Mesh.ARRAY_WEIGHTS].size()==data[Mesh.ARRAY_VERTEX].size()*4,"Measured source influence layout changed")
	super.configure(mesh,quadruped);align_skinned_soles=true;iterations=6
func source_lifts() -> Array[float]:
	var rig:=get_skeleton();var matrices: Array[Transform3D]=[]
	for bind in surface.skin.get_bind_count():
		var index:=surface.skin.get_bind_bone(bind)
		if index<0:index=rig.find_bone(surface.skin.get_bind_name(bind))
		matrices.append(rig.get_bone_global_pose(index)*surface.skin.get_bind_pose(bind))
	var reference:=Transform3D(flat_basis,Vector3.ZERO)*model_root.global_transform.affine_inverse()*rig.global_transform
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var result: Array[float]=[]
	for foot: Dictionary in feet:
		var low:=INF
		for vertex: int in foot.vertices:
			var point:=Vector3.ZERO
			for slot in 4:point+=(matrices[indices[vertex*4+slot]]*vertices[vertex])*weights[vertex*4+slot]
			low=minf(low,(reference*point).y)
		result.append(low)
	return result
func _process_modification_with_delta(_delta: float) -> void:
	errors.clear();stance_gaps.clear()
	if not enabled or surface==null or model_root==null:return
	var lifts:=source_lifts()
	for i in feet.size():
		if not contacts.has(i):continue
		var hit: Dictionary=contacts[i];var lift:=0. if lifts[i]<.015 else lifts[i]
		# Classify against the actual flat source pose, not terrain-distorted
		# height. Preserve a swing or lunge above its local plane rather than
		# mistaking a low step for stance or dragging an airborne limb down.
		for pass_index in 2:
			var point:=sole(feet[i]);var plane_y: float=hit.position.y-(hit.normal.x*(point.x-hit.position.x)+hit.normal.z*(point.z-hit.position.z))/hit.normal.y
			align_sole(feet[i],plane_y+lift/hit.normal.y,1.)
		if lifts[i]<.015:
			var gap: float=hit.normal.dot(sole(feet[i])-hit.position)
			errors.append(absf(gap));stance_gaps.append(gap)
