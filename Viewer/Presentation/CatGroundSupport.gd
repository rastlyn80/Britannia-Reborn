extends "res://Presentation/SourceMountContact.gd"
## Actual paws occupy a different surface from the torso. Preserve all eight
## source/refinement influences and gather soles across every material slot.
var stride:=8
func configure(mesh: MeshInstance3D,_quadruped: bool) -> void:
	surface=mesh;feet.clear();arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	var vertices:=PackedVector3Array();var joints:=PackedInt32Array();var weights:=PackedFloat32Array()
	for index in mesh.mesh.get_surface_count():
		var part:=mesh.mesh.surface_get_arrays(index);vertices.append_array(part[Mesh.ARRAY_VERTEX]);joints.append_array(part[Mesh.ARRAY_BONES]);weights.append_array(part[Mesh.ARRAY_WEIGHTS])
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_BONES]=joints;arrays[Mesh.ARRAY_WEIGHTS]=weights;stride=joints.size()/vertices.size()
	var rig:=get_skeleton()
	for side: String in ["l","r"]:
		for names in [["thigh","calf","foot"],["upperarm","forearm","hand"]]:
			var a:=bone(side+" "+str(names[0]));var b:=bone(side+" "+str(names[1]));var c:=bone(side+" "+str(names[2]))
			if mini(a,mini(b,c))<0:continue
			var record:={"a":a,"b":b,"c":c,"end":c,"vertices":[],"source_leg":side+" "+str(names[2])};var seen: Dictionary={}
			for vertex in vertices.size():
				var influence:=0.
				for j in stride:
					var bind:=joints[vertex*stride+j];var index:=mesh.skin.get_bind_bone(bind)
					if index<0:index=rig.find_bone(mesh.skin.get_bind_name(bind))
					if index==c:influence+=weights[vertex*stride+j]
				if influence>.6 and not seen.has(vertices[vertex]):record.vertices.append(vertex);seen[vertices[vertex]]=true
			if not record.vertices.is_empty():feet.append(record)
	align_skinned_soles=true;iterations=5
func sole(record: Dictionary) -> Vector3:
	var rig:=get_skeleton();var matrices: Array[Transform3D]=[]
	for bind in surface.skin.get_bind_count():
		var index:=surface.skin.get_bind_bone(bind)
		if index<0:index=rig.find_bone(surface.skin.get_bind_name(bind))
		matrices.append(rig.get_bone_global_pose(index)*surface.skin.get_bind_pose(bind))
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var joints: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var lowest:=Vector3(0.,INF,0.)
	for vertex: int in record.vertices:
		var p:=Vector3.ZERO
		for j in stride:p+=(matrices[joints[vertex*stride+j]]*vertices[vertex])*weights[vertex*stride+j]
		p=rig.to_global(p)
		if p.y<lowest.y:lowest=p
	return lowest if lowest.is_finite() else rig.to_global(rig.get_bone_global_pose(record.end).origin)
func _process_modification_with_delta(_delta: float) -> void:
	errors.clear();stance_gaps.clear()
	if not enabled or surface==null:return
	for i in feet.size():
		if not contacts.has(i):continue
		var record: Dictionary=feet[i];var point:=sole(record);var hit: Dictionary=contacts[i]
		# The source cat's swing is only a few centimetres high. The larger
		# animal's 16cm threshold would drag almost the whole swing to ground.
		var strength:=1.-smoothstep(.008,.024,maxf(0.,point.y-origin_y))
		if strength<=.001:continue
		align_sole(record,hit.position.y,strength)
		if strength>.95:
			var gap:=sole(record).y-float(hit.position.y);errors.append(absf(gap));stance_gaps.append(gap)
