extends RefCounted
## Original overlapping textile cuffs. Fit their radii to the licensed body at
## rest; preserve its skin and the manufactured armour. No skin triangles copied.
static func create(rig: Skeleton3D,body: MeshInstance3D,material: Material) -> MeshInstance3D:
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array();var bones:=PackedInt32Array();var weights:=PackedFloat32Array()
	var skin:=Skin.new()
	var source: PackedVector3Array=body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for side_index in 2:
		var side: String=["l","r"][side_index]
		var lower:=rig.find_bone("lowerarm_"+side);var hand:=rig.find_bone("hand_"+side)
		var a:=rig.get_bone_global_rest(lower).origin;var b:=rig.get_bone_global_rest(hand).origin
		var axis:=(b-a).normalized();var u:=axis.cross(Vector3.FORWARD).normalized();var v:=axis.cross(u).normalized()
		for index in [lower,hand]:skin.add_named_bind(rig.get_bone_name(index),rig.get_bone_global_rest(index).affine_inverse())
		var start:=vertices.size();var steps:=32;var rings:=16
		for ring in rings:
			var t:=lerpf(-a.distance_to(b)-.035,.05,float(ring)/float(rings-1));var centre:=b+axis*t
			var radius:=.038
			for point in source:
				var distance:=point-centre
				if absf(distance.dot(axis))<.014 and distance.length()<.075:radius=maxf(radius,(distance-axis*distance.dot(axis)).length()+.008)
			radius=minf(radius,.075)
			var hand_weight:=smoothstep(-.02,.025,t)
			for segment in steps:
				var angle:=TAU*float(segment)/steps;var normal:=u*cos(angle)+v*sin(angle)
				vertices.append(centre+normal*radius);normals.append(normal);uv.append(Vector2(float(segment)/steps,float(ring)/3.))
				bones.append_array(PackedInt32Array([side_index*2,side_index*2+1,0,0]));weights.append_array(PackedFloat32Array([1.-hand_weight,hand_weight,0,0]))
		for ring in rings-1:
			for segment in steps:
				var x:=start+ring*steps+segment;var y:=start+ring*steps+(segment+1)%steps
				indices.append_array(PackedInt32Array([x,y,y+steps,x,y+steps,x+steps]))
		# Close the overlapping ends inside the existing elbow/gauntlet pieces.
		# Open cylinder rims otherwise reveal skin when viewed down the sleeve.
		for end in 2:
			var ring_start:=start+(0 if end==0 else rings-1)*steps
			var centre:=Vector3.ZERO
			for segment in steps:centre+=vertices[ring_start+segment]/float(steps)
			var cap:=vertices.size();vertices.append(centre);normals.append(-axis if end==0 else axis);uv.append(Vector2(.5,.5))
			bones.append_array(PackedInt32Array([side_index*2+end,0,0,0]));weights.append_array(PackedFloat32Array([1,0,0,0]))
			for segment in steps:
				var x:=ring_start+segment;var y:=ring_start+(segment+1)%steps
				indices.append_array(PackedInt32Array([cap,y,x] if end==0 else [cap,x,y]))
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices;arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(0,material)
	var result:=MeshInstance3D.new();result.name="Extra_RidingSleeveCuffs";result.mesh=mesh;result.skin=skin;rig.add_child(result);result.skeleton=NodePath("..")
	result.set_meta("source_path","authored fitted sleeve cuffs / existing CC0 lining material");return result
