extends "res://Presentation/SourceMountContact.gd"
## Four real two-joint legs on br-n518's rig; no invented Third Dawn bones.
func configure(mesh: MeshInstance3D,_quadruped: bool) -> void:
	surface=mesh;arrays=mesh.mesh.surface_get_arrays(0);feet.clear();align_skinned_soles=true;iterations=8
	var rig:=get_skeleton();var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var joints: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride:=joints.size()/vertices.size()
	for prefix: String in ["base.001_L","base.001_R","base_L","base_R"]:
		var upper:=rig.find_bone(prefix);var lower:=rig.find_bone(prefix+".001")
		if upper<0 or lower<0:continue
		var record:={"a":upper,"b":lower,"c":lower,"end":lower,"vertices":[],"source_leg":prefix};var seen: Dictionary={}
		for vertex in vertices.size():
			var influence:=0.
			for j in stride:
				var bind:=joints[vertex*stride+j];var bone:=surface.skin.get_bind_bone(bind)
				if bone<0:bone=rig.find_bone(surface.skin.get_bind_name(bind))
				if bone==lower:influence+=weights[vertex*stride+j]
			if influence>.6 and not seen.has(vertices[vertex]):record.vertices.append(vertex);seen[vertices[vertex]]=true
		if not record.vertices.is_empty():feet.append(record)
func align_sole(record: Dictionary,height: float,strength: float) -> void:
	var rig:=get_skeleton()
	for iteration in iterations:
		if absf(height-sole(record).y)<.001:break
		for joint: int in [record.b,record.a]:
			var point:=sole(record);var pose:=rig.get_bone_global_pose(joint);var arm:=point-rig.to_global(pose.origin)
			var axis:=arm.cross(Vector3.UP);var lever:=axis.length()
			if lever<.00001:continue
			var angle:=clampf((height-point.y)*strength/lever,-.06,.06)
			pose.basis=Basis(Quaternion((rig.global_basis.inverse()*axis.normalized()).normalized(),angle))*pose.basis
			rig.set_bone_global_pose(joint,pose)
