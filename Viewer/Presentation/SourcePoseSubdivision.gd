extends RefCounted
## Subdivide the posed source surface, rather than averaging incompatible binds.
## A vertex's per-bind conditional point preserves barycentric LBS through motion.
static var cache: Dictionary={}
static func apply(mesh: MeshInstance3D,rig: Skeleton3D,levels: int=2,offset: float=.0015) -> Dictionary:
	assert(levels>=1 and levels<=2 and mesh.mesh.get_surface_count()==1)
	var key:=str(mesh.mesh.get_instance_id())+":"+str(mesh.skin.get_instance_id())+":"+str(levels)+":"+str(offset)
	if cache.has(key):mesh.mesh=cache[key].mesh;mesh.skin=cache[key].skin;return cache[key].report
	var original_mesh:=mesh.mesh;var original_skin:=mesh.skin;var a:=original_mesh.surface_get_arrays(0);var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=a[Mesh.ARRAY_NORMAL];var uv: PackedVector2Array=a[Mesh.ARRAY_TEX_UV];var bindings: PackedInt32Array=a[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var source_tangents: PackedFloat32Array=a[Mesh.ARRAY_TANGENT] if a[Mesh.ARRAY_TANGENT]!=null else PackedFloat32Array();assert(bindings.size()==vertices.size()*4)
	var provenance: Array[Dictionary]=[]
	for i in vertices.size():provenance.append({i:1.})
	var triangles:=PackedInt32Array()
	if a[Mesh.ARRAY_INDEX]!=null:triangles=a[Mesh.ARRAY_INDEX]
	else:
		for i in vertices.size():triangles.append(i)
	var source_triangles:=triangles.size()/3
	for level in levels:
		var edges: Dictionary={};var next:=PackedInt32Array()
		for triangle in range(0,triangles.size(),3):
			var corners: Array[int]=[triangles[triangle],triangles[triangle+1],triangles[triangle+2]];var mids: Array[int]=[]
			for pair in [[corners[0],corners[1]],[corners[1],corners[2]],[corners[2],corners[0]]]:
				var edge:=Vector2i(mini(pair[0],pair[1]),maxi(pair[0],pair[1]))
				if not edges.has(edge):
					var mixed: Dictionary={}
					for source: int in provenance[pair[0]]:mixed[source]=float(provenance[pair[0]][source])*.5
					for source: int in provenance[pair[1]]:mixed[source]=float(mixed.get(source,0.))+float(provenance[pair[1]][source])*.5
					edges[edge]=provenance.size();provenance.append(mixed)
				mids.append(int(edges[edge]))
			for index in [corners[0],mids[0],mids[2],mids[0],corners[1],mids[1],mids[2],mids[1],corners[2],mids[0],mids[1],mids[2]]:next.append(index)
		triangles=next
	var skin:=Skin.new();var bind_cache: Dictionary={};var points:=PackedVector3Array();var directions:=PackedVector3Array();var textures:=PackedVector2Array();var tangents:=PackedFloat32Array();var bones:=PackedInt32Array();var ratios:=PackedFloat32Array();var max_influences:=0
	for recipe: Dictionary in provenance:
		var point:=Vector3.ZERO;var normal:=Vector3.ZERO;var tex:=Vector2.ZERO
		for source: int in recipe:
			var amount:=float(recipe[source]);point+=vertices[source]*amount;normal+=normals[source]*amount;tex+=uv[source]*amount
		normal=normal.normalized();var delta:=normal*offset if recipe.size()>1 else Vector3.ZERO;point+=delta;var contributions: Dictionary={}
		for source: int in recipe:
			for slot in 4:
				var amount:=float(recipe[source])*weights[source*4+slot]
				if amount<=0.:continue
				var bind:=bindings[source*4+slot];var old:=original_skin.get_bind_pose(bind);var target: Vector3=old*vertices[source]+old.basis*delta
				if not contributions.has(bind):contributions[bind]={"weight":0.,"point":Vector3.ZERO}
				contributions[bind].weight+=amount;contributions[bind].point+=target*amount
		max_influences=maxi(max_influences,contributions.size());assert(contributions.size()<=8,"Exact source subdivision exceeds the eight-weight skin format")
		var slot:=0
		for bind: int in contributions:
			var item: Dictionary=contributions[bind];var pose:=original_skin.get_bind_pose(bind);pose.origin=(item.point as Vector3)/float(item.weight)-pose.basis*point
			var bone:=original_skin.get_bind_bone(bind)
			if bone<0:bone=rig.find_bone(original_skin.get_bind_name(bind))
			assert(bone>=0);var signature: Array=[bone,pose.basis,pose.origin]
			if not bind_cache.has(signature):bind_cache[signature]=skin.get_bind_count();skin.add_bind(bone,pose)
			bones.append(int(bind_cache[signature]));ratios.append(float(item.weight));slot+=1
		while slot<8:bones.append(0);ratios.append(0.);slot+=1
		points.append(point);directions.append(normal);textures.append(tex)
		if not source_tangents.is_empty():
			var tangent:=Vector3.ZERO;var handedness:=0.
			for source: int in recipe:
				var amount:=float(recipe[source]);tangent+=Vector3(source_tangents[source*4],source_tangents[source*4+1],source_tangents[source*4+2])*amount;handedness+=source_tangents[source*4+3]*amount
			tangent=tangent.slide(normal).normalized();tangents.append_array(PackedFloat32Array([tangent.x,tangent.y,tangent.z,1. if handedness>=0. else -1.]))
	var output: Array=[];output.resize(Mesh.ARRAY_MAX);output[Mesh.ARRAY_VERTEX]=points;output[Mesh.ARRAY_NORMAL]=directions;output[Mesh.ARRAY_TEX_UV]=textures;output[Mesh.ARRAY_BONES]=bones;output[Mesh.ARRAY_WEIGHTS]=ratios;output[Mesh.ARRAY_INDEX]=triangles
	if not tangents.is_empty():output[Mesh.ARRAY_TANGENT]=tangents
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,output,[],{},Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS);result.surface_set_material(0,original_mesh.surface_get_material(0));mesh.mesh=result;mesh.skin=skin
	var report:={"source_triangles":source_triangles,"triangles":triangles.size()/3,"vertices":points.size(),"binds":skin.get_bind_count(),"maximum_influences":max_influences,"source_bones":rig.get_bone_count(),"normal_offset_source_units":offset,"method":"Barycentric source-vertex skin contributions with per-bind conditional inverse-bind translations; original skeleton, UVs and animation channels retained. Bounded rest-normal offset only."};cache[key]={"mesh":result,"skin":skin,"report":report};return report
