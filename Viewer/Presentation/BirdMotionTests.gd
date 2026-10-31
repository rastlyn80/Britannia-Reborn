extends SceneTree
## Licensed asset/animation trial only; native routing and hue checks are separate.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<15:push_error(label)
func run() -> void:
	var path:="res://local-art/birds/small-bird.glb"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--asset="):path=arg.trim_prefix("--asset=")
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path.get_base_dir()+"/preparation.json"))
	check(FileAccess.get_sha256(path)==preparation.asset_sha256,"Exact authored bird asset matches preparation")
	var actor: Node3D=load(path).instantiate();root.add_child(actor)
	var initial:=actor.transform
	var rig: Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0]
	var animator: AnimationPlayer=actor.find_children("*","AnimationPlayer",true,false)[0]
	var mesh: MeshInstance3D=actor.find_children("*","MeshInstance3D",true,false)[0]
	var arrays:=mesh.mesh.surface_get_arrays(0)
	check(rig.get_bone_count()==65 and arrays[Mesh.ARRAY_INDEX].size()/3==996,"Licensed rig and mesh topology retained")
	check(arrays[Mesh.ARRAY_TANGENT]!=null and arrays[Mesh.ARRAY_TANGENT].size()==arrays[Mesh.ARRAY_VERTEX].size()*4,"Real feather normal map has a tangent basis")
	var material:=mesh.get_active_material(0) as StandardMaterial3D
	check(material!=null and material.normal_enabled and material.normal_texture!=null and material.roughness_texture!=null,"Actual normal and roughness maps are imported")
	check(material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,"Feather alpha uses masked geometry")
	var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride: int=weights.size()/arrays[Mesh.ARRAY_VERTEX].size();var valid: bool=stride==8
	for index in int(weights.size()/stride):
		var total:=0.
		for influence in stride:total+=weights[index*stride+influence];valid=valid and is_finite(weights[index*stride+influence]) and weights[index*stride+influence]>=0.
		valid=valid and absf(total-1.)<.0001
	check(valid,"Exported eight-influence skin stays finite and normalized")
	check(float(preparation.influence_reduction_error_m["8"])<.0005,"Measured source-weight reduction remains below0.5mm")
	check(preparation.clips.size()==16,"Sixteen explicitly authored categories are declared")
	var samples: Array=[];var idle_width:=0.;var flight_width:=0.;var idle_beak:=0.;var feeding_beak:=INF
	var envelope:=AABB();var envelope_first:=true
	for clip: String in preparation.clips:
		check(animator.has_animation(clip),"Declared bird category exists: "+clip)
		if not animator.has_animation(clip):continue
		var animation:=animator.get_animation(clip);animation.loop_mode=Animation.LOOP_NONE
		check(absf(animation.length-float(preparation.clips[clip].duration))<.001,"Authored category duration preserved: "+clip)
		animator.play(clip,0.);animator.pause()
		var first: Array[Transform3D]=[];var pelvis_min:=INF;var pelvis_max:=-INF
		for frame in 21:
			var phase:=float(frame)/20.;animator.seek(animation.length*phase,true)
			for settled in 2:await process_frame
			var bounds:=Geometry.deformed_bounds(mesh,rig)
			envelope=bounds if envelope_first else envelope.merge(bounds);envelope_first=false
			check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()>.05 and bounds.size.length()<.65,"Actual bird skin remains bounded: "+clip)
			check(bounds.position.y>-.01,"Bird skin does not penetrate the flat support plane: "+clip)
			if clip in ["Run","Fly"]:check(bounds.position.y>.01,"Low flight preserves positive clearance")
			elif clip not in ["TakeOff","Land","Walk"]:check(absf(bounds.position.y)<.012,"Grounded categories rest on the support plane")
			if clip=="Walk":check(bounds.position.y<.065,"Wing-assisted hops retain a bounded ground clearance")
			var pelvis: Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("pelvis_control")).origin
			pelvis_min=minf(pelvis_min,pelvis.y);pelvis_max=maxf(pelvis_max,pelvis.y)
			for side in ["L","R"]:
				var foot: Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("foot."+side)).origin
				var thigh: Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("thigh."+side)).origin
				check(foot.distance_to(thigh)<.12,"Leg controls do not drift or stretch across clips")
				if clip=="Idle":
					var toe: Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("t_middle.003."+side)).origin
					check(toe.y>-.005 and toe.y<.012,"Standing toes meet the plane; wing tips do not prop up the body")
			check(actor.transform.is_equal_approx(initial),"Animation leaves the external entity transform unchanged")
			var beak: Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("beak.T")).origin
			if clip=="Idle":idle_width=maxf(idle_width,bounds.size.x);idle_beak=maxf(idle_beak,beak.y)
			if clip=="Eat":feeding_beak=minf(feeding_beak,beak.y)
			if clip=="Run":flight_width=maxf(flight_width,bounds.size.x)
			if frame==0:
				for bone in rig.get_bone_count():first.append(rig.get_bone_global_pose(bone))
			if frame==20 and bool(preparation.clips[clip].loop):
				var continuous:=true
				for bone in rig.get_bone_count():
					var last:=rig.get_bone_global_pose(bone)
					continuous=continuous and first[bone].origin.distance_to(last.origin)<.002 and first[bone].basis.get_rotation_quaternion().angle_to(last.basis.get_rotation_quaternion())<.04
				check(continuous,"Loop endpoints match before enabling looping: "+clip)
			samples.append({"clip":clip,"phase":phase,"minimum_y":bounds.position.y,"maximum_y":bounds.end.y,"skin_diagonal":bounds.size.length()})
		if clip in ["Run","Fly"]:check(pelvis_max-pelvis_min<.035,"Flight torso does not bob with the lowest wing feather")
	check(idle_width<flight_width*.55,"Standing wings fold well inside the flight span")
	check(idle_beak-feeding_beak>.005,"Feeding actually lowers the beak")
	animator.play("Death",0.);animator.seek(animator.current_animation_length,true);animator.pause()
	await process_frame
	actor.set_meta("corpse_body",6);actor.set_meta("native_hue",0);actor.set_meta("death_clip","Death")
	var death_bounds:=Geometry.deformed_bounds(mesh,rig)
	var frozen:=preload("res://Presentation/CorpseModels.gd").freeze(actor)
	check(frozen!=null,"Existing static corpse freezer accepts the bird rig")
	if frozen:
		var corpse_bounds: AABB=frozen.get_meta("corpse_bounds")
		check(corpse_bounds.size.distance_to(death_bounds.size)<.0002,"Frozen bird preserves final skinned bounds within0.2mm")
		check(is_zero_approx(corpse_bounds.position.y) and frozen.find_children("*","Skeleton3D",true,false).is_empty(),"Frozen bird rests on the floor without a live rig")
		frozen.free()
	actor.free()
	var report: Dictionary=preload("res://Presentation/BirdEvidence.gd").capture(path)
	report.merge({"checks":checks,"failures":failures,"envelope":{"position":[envelope.position.x,envelope.position.y,envelope.position.z],"size":[envelope.size.x,envelope.size.y,envelope.size.z]},"samples":samples,"scope":"Actual imported licensed mesh, skin, authored clip continuity, support clearance, leg stability, flight torso and static freezing. Not native server routing, hue response or arbitrary terrain."})
	preload("res://Presentation/BirdEvidence.gd").output("motion-validation",report)
	print("BIRD MOTION: ",checks-failures," / ",checks,"; ",samples.size()," skin samples");quit(1 if failures else 0)
