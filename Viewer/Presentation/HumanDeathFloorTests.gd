extends SceneTree
## Dense/off-grid complete-skin proof of the prepared human death, without GPU.
const Human=preload("res://Presentation/HumanVisual.gd")
const Ground=preload("res://Presentation/HumanDeathFloor.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Human death-floor test deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func raw_human(female: bool) -> Node3D:
	var human:=Human.new();human.female=female;human.use_grounded_death=false;root.add_child(human);human.set_process(false)
	for modifier: SkeletonModifier3D in human.skeleton.find_children("*","SkeletonModifier3D",true,false):modifier.active=false
	return human
func body_minimum(human: Node3D) -> float:
	# Independent traversal of every split vertex, no preparation bounds helper
	# or deduplicated support cache. Triangle interiors are convex combinations.
	var mesh: MeshInstance3D=human.model.find_children("Body*","MeshInstance3D",true,false)[0]
	var rig: Skeleton3D=human.skeleton;var transforms: Array[Transform3D]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
		transforms.append(Ground.relative_rig(human)*rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var minimum:=INF
	for surface in mesh.mesh.get_surface_count():
		var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride: int=bones.size()/vertices.size()
		for vertex in vertices.size():
			var point:=Vector3.ZERO
			for slot in stride:
				var index:=vertex*stride+slot
				point+=(transforms[bones[index]]*vertices[vertex])*weights[index]
			minimum=minf(minimum,point.y)
	return minimum
func run() -> void:
	var inputs: Dictionary={}
	for name in ["HumanDeathFloorTests.gd","HumanDeathFloor.gd","PrepareHumanDeathFloor.gd","HumanVisual.gd","HumanMotion.gd","SkinGeometry.gd","CorpseModels.gd"]:inputs[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var preparation_path:="res://local-art/human-npcs/shared/death-preparation.json"
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation_path));var records: Array=[]
	for female in [false,true]:
		var raw:=raw_human(female);var human:=raw_human(female);var original: Animation=raw.animator.get_animation("Death")
		var digest:=Ground.signature(human,human.animator.get_animation("Death"))
		human.position=Vector3(6043.125,47.2,-3928.375);human.rotation.y=2.617993878
		check(Ground.signature(human,human.animator.get_animation("Death"))==digest,"World location/facing cannot invalidate the local body/rig/clip signature")
		check(Ground.install(human),"Exact prepared body/rig/clip loads at distant native coordinates")
		var animation: Animation=human.animator.get_animation("Death");var pelvis: int=human.skeleton.find_bone("pelvis")
		check(original!=animation and original.length==animation.length and original.loop_mode==animation.loop_mode,"Prepared death owns its motion without changing duration/loop or source cache")
		check(original.get_track_count()==animation.get_track_count(),"Only the existing pelvis stream is adjusted")
		for track in original.get_track_count():
			check(original.track_get_path(track)==animation.track_get_path(track) and original.track_get_type(track)==animation.track_get_type(track),"Death track identity retained")
			if original.track_get_type(track)==Animation.TYPE_POSITION_3D and str(original.track_get_path(track).get_subname(0))=="pelvis":continue
			check(original.track_get_key_count(track)==animation.track_get_key_count(track),"All non-pelvis-position key counts retained")
			for key in original.track_get_key_count(track):
				check(original.track_get_key_time(track,key)==animation.track_get_key_time(track,key) and original.track_get_key_value(track,key)==animation.track_get_key_value(track,key),"Original rotation/cloth scale/non-pelvis keys remain exact")
		var minimum:=INF;var error:=0.;var maximum:=0.;var poses:=0
		raw.animator.play("Death",0.);human.animator.play("Death",0.)
		var times: Array[float]=[]
		for sample in ceili(original.length*960.)+1:times.append(minf(original.length,float(sample)/960.))
		for phase in [.000173,.071331,.193719,.348217,.523177,.701923,.933179]:times.append(original.length*phase)
		for time in times:
			raw.animator.seek(time,true);human.animator.seek(time,true);raw.skeleton.force_update_all_bone_transforms();human.skeleton.force_update_all_bone_transforms()
			var before:=body_minimum(raw);var after:=body_minimum(human)
			minimum=minf(minimum,after);error=maxf(error,absf(after-maxf(0.,before)));maximum=maxf(maximum,after-before);poses+=1
			check(is_finite(after) and after>=-.004,"Complete body remains above the unchanged4mm floor tolerance between baked samples")
			check(absf(after-maxf(0.,before))<.004,"Floor compensation preserves any positive source rise")
			check(human.position==Vector3(6043.125,47.2,-3928.375),"Prepared clip leaves authoritative coordinates unchanged")
			for bone in human.skeleton.get_bone_count():
				check(raw.skeleton.get_bone_pose_rotation(bone).is_equal_approx(human.skeleton.get_bone_pose_rotation(bone)) and raw.skeleton.get_bone_pose_scale(bone).is_equal_approx(human.skeleton.get_bone_pose_scale(bone)),"All source rotations and scales survive sampled correction")
				if bone!=pelvis:check(raw.skeleton.get_bone_pose_position(bone).is_equal_approx(human.skeleton.get_bone_pose_position(bone)),"Non-pelvis local positions remain unchanged")
		var corpse:=Corpses.posed(401 if female else 400)
		check(corpse!=null and corpse.has_meta("grounded_death_signature"),"Ordinary static corpse installs the same measured clip")
		if corpse!=null:
			check(body_minimum(corpse)>=-.004,"Final static corpse body is supported on a flat floor");corpse.free()
		var mismatch:=raw_human(female);var changed: Animation=mismatch.animator.get_animation("Death").duplicate(true)
		changed.length+=.001;var library: AnimationLibrary=mismatch.animator.get_animation_library("").duplicate();mismatch.animator.stop(true);mismatch.animator.remove_animation_library("");mismatch.animator.add_animation_library("",library);library.remove_animation("Death");library.add_animation("Death",changed)
		check(not Ground.install(mismatch) and mismatch.animator.get_animation("Death")==changed,"Changed source motion is refused without replacing its library")
		mismatch.free();mismatch=raw_human(female);var rest: Transform3D=mismatch.skeleton.get_bone_rest(pelvis);rest.origin.y+=.001;mismatch.skeleton.set_bone_rest(pelvis,rest)
		check(not Ground.install(mismatch),"Changed bind rig is refused");mismatch.free()
		records.append({"female":female,"poses":poses,"minimum_body_y_m":minimum,"maximum_clearance_error_m":error,"maximum_correction_m":maximum,"source_signature":digest,"asset_sha256":FileAccess.get_sha256("res://local-art/human-npcs/shared/"+("female" if female else "male")+"-grounded-death.res")})
		raw.free();human.free();await process_frame
	for name: String in inputs:check(inputs[name]==FileAccess.get_sha256("res://Presentation/"+name),"Death-floor source remains unchanged:"+name)
	check(preparation.models.size()==2,"Both gender-specific preparation records exist")
	var report:={"checks":checks,"failures":failures,"cases":records,"runtime_sha256":inputs,"preparation_sha256":FileAccess.get_sha256(preparation_path),"scope":"Dense960Hz plus off-grid complete-body CPU skinning, unchanged rotations/scales/non-pelvis positions/source rise/duration/native root, exact runtime signature and mismatch refusals, final flat static corpse. No GPU, clothing clearance, slopes, native server or family acceptance."}
	var file:=FileAccess.open("res://../work/creatures/savages/death-floor-tests.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("HUMAN DEATH FLOOR: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
