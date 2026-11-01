extends RefCounted
## Project-authored crossed flame ribbons; no recovered particle geometry.
static func install(body: MeshInstance3D,rig: Skeleton3D) -> void:
	var points:=PackedVector3Array();var normals:=PackedVector3Array();var uvs:=PackedVector2Array();var colours:=PackedColorArray();var bones:=PackedInt32Array();var weights:=PackedFloat32Array();var indices:=PackedInt32Array();var serial:={"value":0}
	var flame=func(center: Vector3,width: float,height: float,bone: int) -> void:
		serial.value+=1;var seed: int=serial.value
		for plane in 3:
			var angle:=float(plane)*PI/3.+float(seed)*.37;var right:=Vector3(cos(angle),0,sin(angle));var normal:=right.cross(Vector3.UP);var start:=points.size()
			for row in 9:
				var t:=float(row)/8.
				for side in 2:
					points.append(center+right*(float(side)-.5)*width+Vector3.UP*t*height);normals.append(normal);uvs.append(Vector2(float(side),t));colours.append(Color(fposmod(float(seed)*.6180339887,1.),float(plane)*.31,0,1))
					for slot in 4:bones.append(bone if slot==0 else 0);weights.append(1. if slot==0 else 0.)
			for row in 8:
				var a:=start+row*2
				for index in [a,a+1,a+2,a+1,a+3,a+2]:indices.append(index)
	var specs: Array=[["pelvis",.65,.65],["spine_01",.7,.8],["spine_02",.75,.85],["spine_03",.7,.8],["Head",.48,.65]]
	for spec in specs:
		var bone:=rig.find_bone(spec[0]);assert(bone>=0);var p:=rig.get_bone_global_rest(bone).origin
		flame.call(p-Vector3.UP*.2,float(spec[1]),float(spec[2]),bone)
		flame.call(p+Vector3(.12,-.12,.05),float(spec[1])*.6,float(spec[2])*.8,bone)
	for side in ["l","r"]:
		for roles in [["upperarm_",.38,.6],["lowerarm_",.36,.55],["hand_",.35,.48]]:
			var bone:=rig.find_bone(str(roles[0])+side);assert(bone>=0);flame.call(rig.get_bone_global_rest(bone).origin-Vector3.UP*.12,float(roles[1]),float(roles[2]),bone)
	var root:=rig.find_bone("root");assert(root>=0)
	for layer in 3:
		for index in 6:
			var angle:=float(index)*TAU/6.+layer*.5;var radius:=.20-float(layer)*.055
			flame.call(Vector3(cos(angle)*radius,.04+float(layer)*.22,sin(angle)*radius),.34+.04*sin(float(index)*2.4),.59+.1*sin(float(index)*1.7+layer),root)
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colours;arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);body.mesh=mesh;body.skin=Skin.new()
	for bone in rig.get_bone_count():body.skin.add_bind(bone,rig.get_bone_global_rest(bone).affine_inverse())
