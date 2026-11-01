extends RefCounted
## Full-skin floor offsets measured offline; runtime samples one scalar curve.
## The owning visual applies this only to its model, never native coordinates.
static var cache: Dictionary={}
static var skin_cache: Dictionary={}
static func skin_points(mesh: MeshInstance3D,rig: Skeleton3D) -> Dictionary:
	var key:=str(mesh.mesh.get_instance_id())+":"+str(mesh.skin.get_instance_id())
	if skin_cache.has(key):return skin_cache[key]
	var data:={"bones":PackedInt32Array(),"bind_poses":[],"surfaces":[],"source_vertices":0,"unique_vertices":0}
	for i in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(i)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(i))
		assert(bone>=0);data.bones.append(bone);data.bind_poses.append(mesh.skin.get_bind_pose(i))
	for surface in mesh.mesh.get_surface_count():
		var a:=mesh.mesh.surface_get_arrays(surface);var points: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var bindings: PackedInt32Array=a[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride: int=bindings.size()/points.size();var seen: Dictionary={};var kept:=PackedVector3Array();var indices:=PackedInt32Array();var ratios:=PackedFloat32Array()
		for vertex in points.size():
			var signature: Array=[points[vertex]]
			for slot in stride:signature.append(bindings[vertex*stride+slot]);signature.append(weights[vertex*stride+slot])
			if seen.has(signature):continue
			seen[signature]=true;kept.append(points[vertex])
			for slot in stride:indices.append(bindings[vertex*stride+slot]);ratios.append(weights[vertex*stride+slot])
		data.surfaces.append({"points":kept,"bindings":indices,"weights":ratios,"stride":stride});data.source_vertices+=points.size();data.unique_vertices+=kept.size()
	skin_cache[key]=data;return data
static func minimum_plane_gap(data: Dictionary,rig: Skeleton3D,space: Transform3D,origin: Vector3,normal: Vector3) -> float:
	var matrices: Array[Transform3D]=[]
	for i in data.bones.size():matrices.append(rig.get_bone_global_pose(data.bones[i])*data.bind_poses[i])
	var lowest:=INF
	for surface: Dictionary in data.surfaces:
		var points: PackedVector3Array=surface.points;var bindings: PackedInt32Array=surface.bindings;var weights: PackedFloat32Array=surface.weights;var stride: int=surface.stride
		for vertex in points.size():
			var point:=Vector3.ZERO
			for slot in stride:
				var weight:=weights[vertex*stride+slot]
				if weight>0.:point+=(matrices[bindings[vertex*stride+slot]]*points[vertex])*weight
			lowest=minf(lowest,normal.dot(space*point-origin))
	return lowest
static func load_curves(path: String,treatment: String) -> Dictionary:
	if not cache.has(path):
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(parsed is Dictionary and parsed.get("sample_rate",0)==960,"Missing measured source ground curves")
		cache[path]=parsed
	return cache[path].treatments[treatment].clips
static func sample(curves: Dictionary,clip: String,time: float) -> float:
	# The common compatibility rest category is a copy of the source collapse.
	var name: String="Death" if clip=="LieDown" else clip
	assert(curves.has(name),"Unmeasured source ground category: "+clip)
	var samples: Array=curves[name]
	var left:=0;var right:=samples.size()-1
	while right-left>1:
		var middle: int=(left+right)/2
		if float(samples[middle][0])<=time:left=middle
		else:right=middle
	var a: Array=samples[left];var b: Array=samples[right]
	return lerpf(float(a[1]),float(b[1]),clampf((time-float(a[0]))/maxf(.000001,float(b[0])-float(a[0])),0.,1.))
