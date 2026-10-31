extends SkeletonModifier3D
## Stance-foot support from actual skinned sole vertices. Visual bones only.
var feet: Array=[]
var contacts: Dictionary={}
var errors: Array=[]
var origin_y:=0.
var enabled:=true
var surface: MeshInstance3D
var arrays: Array
func bone(suffix: String) -> int:
	var rig:=get_skeleton()
	for i in rig.get_bone_count():
		if rig.get_bone_name(i).replace("_","")=="bip01 "+suffix:return i
	return -1
func configure(mesh: MeshInstance3D,quadruped: bool) -> void:
	surface=mesh;arrays=mesh.mesh.surface_get_arrays(0)
	var rig:=get_skeleton()
	for side in ["l","r"]:
		var chains: Array=[[side+" thigh",side+" calf",side+" horselink",side+" foot"]]
		if quadruped:chains.append([side+" upperarm",side+" forearm",side+" hand",side+" hand"])
		for chain in chains:
			var record:={"a":bone(chain[0]),"b":bone(chain[1]),"c":bone(chain[2]),"end":bone(chain[3]),"vertices":[]}
			if mini(record.a,mini(record.b,record.c))<0:continue
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var seen: Dictionary={}
			for i in vertices.size():
				var score:=0.
				for j in 4:
					var bind:=indices[i*4+j];var index:=surface.skin.get_bind_bone(bind)
					if index<0:index=rig.find_bone(surface.skin.get_bind_name(bind))
					if index==record.end:score+=weights[i*4+j]
				if score>.6 and not seen.has(vertices[i]):record.vertices.append(i);seen[vertices[i]]=true
			feet.append(record)
func sole(record: Dictionary) -> Vector3:
	var rig:=get_skeleton();var lowest:=Vector3(0,INF,0)
	var matrices: Array[Transform3D]=[]
	for i in surface.skin.get_bind_count():
		var index:=surface.skin.get_bind_bone(i)
		if index<0:index=rig.find_bone(surface.skin.get_bind_name(i))
		matrices.append(rig.get_bone_global_pose(index)*surface.skin.get_bind_pose(i))
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	for i: int in record.vertices:
		var p:=Vector3.ZERO
		for j in 4:p+=(matrices[indices[i*4+j]]*vertices[i])*weights[i*4+j]
		p=rig.to_global(p)
		if p.y<lowest.y:lowest=p
	return lowest if lowest.is_finite() else rig.to_global(rig.get_bone_global_pose(record.end).origin)
func sample(space: PhysicsDirectSpaceState3D,origin: Vector3) -> void:
	origin_y=origin.y
	for i in feet.size():
		var p:=sole(feet[i]);var from:=Vector3(p.x,origin.y+.65,p.z)
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(from,from-Vector3.UP*1.3,1))
		if enabled and not hit.is_empty() and hit.normal.y>.75 and absf(hit.position.y-origin.y)<.45:contacts[i]=hit
		else:contacts.erase(i)
func aim(a: int,b: int,target: Vector3) -> void:
	var rig:=get_skeleton();var pose:=rig.get_bone_global_pose(a)
	var direction:=rig.get_bone_global_pose(b).origin-pose.origin;var goal:=target-pose.origin
	if direction.length_squared()>.000001 and goal.length_squared()>.000001:pose.basis=Basis(Quaternion(direction.normalized(),goal.normalized()))*pose.basis;rig.set_bone_global_pose(a,pose)
func _process_modification_with_delta(_delta: float) -> void:
	errors.clear()
	if not enabled or surface==null:return
	var rig:=get_skeleton();var inverse:=rig.global_transform.affine_inverse()
	for i in feet.size():
		if not contacts.has(i):continue
		var record: Dictionary=feet[i];var p:=sole(record);var hit: Dictionary=contacts[i]
		var strength:=1.-smoothstep(.025,.16,maxf(0.,p.y-origin_y))
		var shift:=clampf(hit.position.y-p.y,-.24,.24)*strength
		var a:=rig.get_bone_global_pose(record.a).origin;var b:=rig.get_bone_global_pose(record.b).origin;var c:=rig.get_bone_global_pose(record.c).origin
		var target: Vector3=inverse*(rig.to_global(c)+Vector3.UP*shift)
		var knee:=preload("res://Presentation/FootContact.gd").knee_target(a,b,c,target)
		aim(record.a,record.b,knee);aim(record.b,record.c,target)
		if strength>.95:errors.append(absf(sole(record).y-hit.position.y))
