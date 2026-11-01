extends RefCounted
## Original cloud/vortex geometry on the retained CC0 rig; no human face mesh.
static func install(body: MeshInstance3D,rig: Skeleton3D) -> void:
	var points:=PackedVector3Array();var normals:=PackedVector3Array();var uvs:=PackedVector2Array();var colours:=PackedColorArray();var bones:=PackedInt32Array();var weights:=PackedFloat32Array();var indices:=PackedInt32Array()
	var puff=func(center: Vector3,radii: Vector3,bone: int) -> void:
		var sphere:=SphereMesh.new();sphere.radius=1.;sphere.height=2.;sphere.radial_segments=24;sphere.rings=12
		var arrays:=sphere.surface_get_arrays(0);var start:=points.size()
		var v: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var n: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for i in v.size():
			points.append(center+v[i]*radii);normals.append((n[i]/radii).normalized());uvs.append(Vector2(v[i].x*.5+.5,(center.y+v[i].y*radii.y)*.5));colours.append(Color(0,0,0,1))
			for slot in 4:bones.append(bone if slot==0 else 0);weights.append(1. if slot==0 else 0.)
		for index in arrays[Mesh.ARRAY_INDEX]:indices.append(start+int(index))
	for definition in [["pelvis",Vector3(.28,.20,.24),Vector3(0,.02,0)],["spine_02",Vector3(.34,.26,.25),Vector3(0,.02,0)],["spine_03",Vector3(.40,.24,.27),Vector3(0,.08,0)],["Head",Vector3(.20,.23,.19),Vector3(0,.07,0)]]:
		var bone:=rig.find_bone(str(definition[0]));assert(bone>=0);puff.call(rig.get_bone_global_rest(bone).origin+definition[2],definition[1],bone)
	for side in ["l","r"]:
		var upper:=rig.find_bone("upperarm_"+side);var lower:=rig.find_bone("lowerarm_"+side);var hand:=rig.find_bone("hand_"+side);assert(mini(upper,mini(lower,hand))>=0)
		var a:=rig.get_bone_global_rest(upper).origin;var b:=rig.get_bone_global_rest(lower).origin;var c:=rig.get_bone_global_rest(hand).origin
		puff.call(a,Vector3(.22,.21,.23),upper)
		for step in 3:
			puff.call(a.lerp(b,float(step)/3.),Vector3(.17,.17,.19),upper)
			puff.call(b.lerp(c,float(step)/3.),Vector3(.155,.15,.17),lower)
		puff.call(c+Vector3(.04 if side=="l" else -.04,0,0),Vector3(.17,.17,.19),hand)
	var root:=rig.find_bone("root");assert(root>=0)
	for row in 25:
		var t:=float(row)/24.;var radius:=.055+.30*t+.022*sin(t*TAU*2.)
		for side in 33:
			var a:=TAU*float(side)/32.+t*11.;points.append(Vector3(cos(a)*radius,.035+t*1.05,sin(a)*radius));normals.append(Vector3(cos(a),-.28,sin(a)).normalized());uvs.append(Vector2(float(side)/32.,(.035+t*1.05)*.5));colours.append(Color(1,0,0,1))
			for slot in 4:bones.append(root if slot==0 else 0);weights.append(1. if slot==0 else 0.)
	var cone_start:=points.size()-25*33
	for row in 24:
		for side in 32:
			var a:=cone_start+row*33+side;var b:=a+1;var c:=a+33;var d:=c+1
			for index in [a,b,c,b,d,c]:indices.append(index)
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colours;arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);body.mesh=mesh
	body.skin=Skin.new()
	for bone in rig.get_bone_count():body.skin.add_bind(bone,rig.get_bone_global_rest(bone).affine_inverse())
