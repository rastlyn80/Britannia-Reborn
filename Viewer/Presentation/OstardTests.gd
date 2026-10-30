extends SceneTree
## Exercise actual imported skin vertices, not a box around the animated joints.
const Visual=preload("res://Presentation/OstardVisual.gd")
var checks:=0
var failures:=0
var records: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func deformed_bounds(mesh: MeshInstance3D,rig: Skeleton3D) -> AABB:
	var arrays:=mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var matrices: Array[Transform3D]=[]
	for i in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(i)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(i))
		matrices.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(i))
	var box:=AABB()
	for i in vertices.size():
		var point:=Vector3.ZERO
		for j in 4:point+=(matrices[indices[i*4+j]]*vertices[i])*weights[i*4+j]
		point=rig.to_global(point)
		if not point.is_finite():return AABB(Vector3(INF,INF,INF),Vector3.ZERO)
		box=AABB(point,Vector3.ZERO) if i==0 else box.expand(point)
	return box
func run() -> void:
	var reference_names: Array=[]
	var reference_rest: Array=[]
	var reference_parents: Array=[]
	var reference_lengths: Dictionary={}
	for treatment in ["original","rounded","modern"]:
		var actor:=Visual.new();actor.treatment=treatment;root.add_child(actor)
		var rig: Skeleton3D=actor.skeleton
		check(rig.get_bone_count()==24,"All treatments retain the 24-bone source rig")
		for i in rig.get_bone_count():
			if treatment=="original":
				reference_names.append(rig.get_bone_name(i));reference_rest.append(rig.get_bone_rest(i));reference_parents.append(rig.get_bone_parent(i))
			else:
				check(rig.get_bone_name(i)==reference_names[i] and rig.get_bone_parent(i)==reference_parents[i] and rig.get_bone_rest(i).is_equal_approx(reference_rest[i]),"Refinement preserves bind rig names, hierarchy and rests")
		var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0]
		var arrays:=mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
		check(tangents.size()==vertices.size()*4,"Imported mesh has tangent frames for the shader's normal detail")
		check(vertices.size()==(555 if treatment=="original" else 8880),"Imported triangle corners retain the expected 185 / 2960 triangle topology")
		var valid_skin:=indices.size()==vertices.size()*4 and weights.size()==indices.size()
		for i in vertices.size():
			var total:=0.
			for j in 4:
				var index:=i*4+j
				valid_skin=valid_skin and is_finite(weights[index]) and weights[index]>=0. and indices[index]>=0 and indices[index]<mesh.skin.get_bind_count()
				total+=weights[index]
			valid_skin=valid_skin and absf(total-1.)<.0001
		check(valid_skin,"Actual imported vertex influences are finite, normalised and bound to existing skin matrices")
		for clip in Visual.CLIPS:
			check(actor.animator.has_animation(clip),"Native source clip survives import: "+clip)
			var animation: Animation=actor.animator.get_animation(clip)
			if treatment=="original":reference_lengths[clip]=animation.length
			check(animation.length>0. and is_equal_approx(animation.length,reference_lengths[clip]),"All treatments preserve the same native clip duration")
			var first_pose: Array=[]
			var moved:=false
			for sample in 12:
				var phase:=float(sample)/12.
				actor.animator.play(clip,0.);actor.animator.seek(animation.length*phase,true);actor.animator.pause()
				for frame in 2:await process_frame
				var bounds:=deformed_bounds(mesh,rig)
				check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()<4. and bounds.size.length()>.3,"Skinned vertices stay finite and bounded in "+treatment+" "+clip)
				check(absf(bounds.position.y)<.035,"Exported flat-floor correction keeps the actual lowest vertex within 35 mm: "+treatment+" "+clip+" "+str(phase))
				check(actor.transform.is_equal_approx(Transform3D.IDENTITY),"Animations never move the actor's authoritative root")
				for bone in rig.get_bone_count():
					var pose:=rig.get_bone_global_pose(bone)
					check(pose.origin.is_finite() and pose.basis.is_finite(),"Animated bone pose is finite")
					if sample==0:first_pose.append(pose)
					elif bone>2 and not pose.basis.is_equal_approx(first_pose[bone].basis):moved=true
				records.append({"treatment":treatment,"clip":clip,"phase":phase,"lowest_vertex_m":bounds.position.y,"size_m":[bounds.size.x,bounds.size.y,bounds.size.z]})
			check(moved,"Clip changes actual articulated bone rotations: "+treatment+" "+clip)
		if treatment=="modern":
			var rig_id:=rig.get_instance_id()
			for hue in [0,53,0x8000|53]:
				actor.set_hue(hue)
				var mat: ShaderMaterial=mesh.get_surface_override_material(0)
				check(actor.hue==hue and rig.get_instance_id()==rig_id,"Preview retains exact native hue bits without rebuilding the rig")
				check(mat.get_shader_parameter("partial_hue")==((hue&0x8000)!=0),"Partial hue flag reaches the surface shader")
		actor.free()
	var report:={"checks":checks,"failures":failures,"sampled_poses":records.size(),"samples":records,"scope":"Offline actual Godot imported skin vertices: seven clips, twelve phases, three treatments. Flat-floor export correction; no live movement, rider, terrain IK or mount claims."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/ostard-trial"))
	var file:=FileAccess.open("res://../outputs/ostard-trial/validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("OSTARD TESTS: ",checks-failures," / ",checks,"; ",records.size()," skinned poses");quit(1 if failures else 0)
