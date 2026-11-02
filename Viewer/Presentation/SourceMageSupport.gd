extends "res://Presentation/MeasuredCreatureSupport.gd"
## Integral pointed shoes need the lowest signed plane distance, not world Y.
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
var full_skin: Dictionary={}
var base_model_y:=0.
func configure(mesh: MeshInstance3D,_quadruped: bool) -> void:
	super.configure(mesh,false)
	assert(feet.size()==2,"Original mage requires two measured source legs")
	for index in feet.size():feet[index].plane_sole_index=index
	full_skin=Ground.skin_points(mesh,get_skeleton());base_model_y=model_root.position.y
func sole(record: Dictionary) -> Vector3:
	var rig:=get_skeleton();var matrices: Array[Transform3D]=[]
	for bind in surface.skin.get_bind_count():
		var bone:=surface.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(surface.skin.get_bind_name(bind))
		matrices.append(rig.get_bone_global_pose(bone)*surface.skin.get_bind_pose(bind))
	var index:=int(record.plane_sole_index);var normal: Vector3=contacts[index].normal if contacts.has(index) else Vector3.UP;var origin: Vector3=contacts[index].position if contacts.has(index) else Vector3.ZERO
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var low:=INF;var result:=Vector3.ZERO
	for vertex: int in record.vertices:
		var point:=Vector3.ZERO
		for slot in 4:point+=(matrices[indices[vertex*4+slot]]*points[vertex])*weights[vertex*4+slot]
		point=rig.to_global(point);var gap:=normal.dot(point-origin)
		if gap<low:low=gap;result=point
	assert(is_finite(low));return result
func _process_modification_with_delta(_delta: float) -> void:
	errors.clear();stance_gaps.clear()
	if not enabled or surface==null or model_root==null:return
	# Repeated modifier evaluations must start from the animator's common
	# support offset, rather than accumulating the previous contact balance.
	model_root.position.y=base_model_y
	var rig:=get_skeleton();var lifts:=source_lifts()
	for index in feet.size():
		if not contacts.has(index):continue
		var record: Dictionary=feet[index];var hit: Dictionary=contacts[index];var normal: Vector3=hit.normal
		# Distal-weighted cloth follows the same joints as the shoe. Gradually
		# release contact across the first3cm instead of snapping a low swing
		# fully down and dragging the robe hem through the support plane.
		var source_lift:=maxf(0.,lifts[index]);var lift:=source_lift*smoothstep(0.,.03,source_lift)
		# Rotate original leg joints toward the sampled plane. No translations
		# or scale edits: source segment lengths and airborne lift survive.
		for iteration in 12:
			if absf(lift-normal.dot(sole(record)-hit.position))<.0005:break
			for joint: int in [record.c,record.b,record.a]:
				var point:=sole(record);var pose:=rig.get_bone_global_pose(joint);var arm:=point-rig.to_global(pose.origin);var axis:=arm.cross(normal);var lever:=axis.length()
				if lever<.0001:continue
				var angle:=clampf((lift-normal.dot(point-hit.position))/lever,-.045,.045);var local_axis: Vector3=(rig.global_basis.inverse()*axis.normalized()).normalized();pose.basis=Basis(Quaternion(local_axis,angle))*pose.basis;rig.set_bone_global_pose(joint,pose)
		if lifts[index]<.015:
			var gap:=normal.dot(sole(record)-hit.position);errors.append(absf(gap));stance_gaps.append(gap)
	balance_contacts(lifts)
func balance_contacts(lifts: Array[float]) -> void:
	if full_skin.is_empty() or contacts.size()!=feet.size():return
	var hit: Dictionary=contacts[0];var normal: Vector3=hit.normal;var origin: Vector3=hit.position
	# A shared correction is meaningful only on one sampled plane. Steps and
	# separate ledges retain per-foot solving until their volume proof exists.
	for other: Dictionary in contacts.values():
		if normal.dot(other.normal)<.999 or absf(normal.dot(other.position-origin))>.004:return
	var rig:=get_skeleton();var minimum:=Ground.minimum_plane_gap(full_skin,rig,rig.global_transform,origin,normal);var maximum:=minimum
	for index in feet.size():
		var target:=0. if lifts[index]<.015 else lifts[index]
		var residual: float=normal.dot(sole(feet[index])-origin)-target
		minimum=minf(minimum,residual);maximum=maxf(maximum,residual)
	# Fixed source cloth and exact-length limbs can impose slightly different
	# contact heights. The midpoint of the extreme residuals minimizes their
	# largest error under one common translation; it cannot stretch a bone.
	var correction:=clampf(-(minimum+maximum)*.5,-.02,.02)
	var vertical: Vector3=model_root.get_parent_node_3d().global_basis.y
	model_root.position.y+=correction/maxf(.75,normal.dot(vertical))
	errors.clear();stance_gaps.clear()
	for index in feet.size():
		if lifts[index]<.015:
			var gap: float=normal.dot(sole(feet[index])-origin);errors.append(absf(gap));stance_gaps.append(gap)
