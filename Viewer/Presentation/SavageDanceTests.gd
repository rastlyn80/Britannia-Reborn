extends SceneTree
## Off-grid baked-animation checks plus actual GPU poses; no native route edits.
const Human=preload("res://Presentation/HumanVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const INPUTS=["SavageDanceTests.gd","SavageDanceRetarget.gd","PrepareSavageDance.gd","HumanVisual.gd","HumanMotion.gd","SkinGeometry.gd","SavageBodyPaint.gd","SavageSkin.gdshader"]
var checks:=0
var failures:=0
var rendered:=0
var captures: Array=[]
var rows: Array=[]
var viewport: SubViewport
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Savage dance test deadline");quit(1))
	call_deferred("run")
func check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:failures+=1;push_error(label)
	return ok
func sha_optional(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
func run() -> void:
	if not check(RenderingServer.get_rendering_device()!=null,"Actual Forward+ GPU is required for dance captures"):quit(1);return
	var folder:="res://local-art/human-npcs/savages/dance/"
	var reference:="res://../work/creatures/savages/dance-reference/"
	var preparation_sha:=FileAccess.get_sha256(folder+"preparation.json")
	var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"preparation.json"))
	var source_sha:=FileAccess.get_sha256(reference+"preparation.json")
	var source_prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(reference+"preparation.json"))
	var accepted_path:="res://local-art/human-npcs/accepted-index.json";var accepted_start:=sha_optional(accepted_path)
	var runtime: Dictionary={}
	for name in INPUTS:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	viewport=SubViewport.new();viewport.size=Vector2i(500,640);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.2;camera.position=Vector3(.2,1.,4.);viewport.add_child(camera);camera.look_at(Vector3(0.,1.,0.))
	for row: Dictionary in prep.models:
		var gender:=str(row.gender);var female:=gender=="female"
		var source_row: Dictionary={}
		for candidate: Dictionary in source_prep.models:
			if str(candidate.gender)==gender:source_row=candidate
		if not check(not source_row.is_empty(),"Matching original gender reference exists"):continue
		check(row.status=="prepared" and int(row.mapped_bones)==52,"Candidate maps all modern body/finger joints and stays prepared")
		check(FileAccess.get_sha256(str(row.asset))==row.asset_sha256,"Exact generated animation matches preparation")
		check(FileAccess.get_sha256(reference+str(source_row.output))==row.source_reference_sha256,"Exact original reference matches retarget preparation")
		var human:=Human.new();human.female=female;viewport.add_child(human);human.set_process(false);human.set_native_profile({"skin":"savage"},0)
		var clip: Animation=load(str(row.asset));var library:=human.animator.get_animation_library("").duplicate()
		human.animator.stop();human.animator.remove_animation_library("");human.animator.add_animation_library("",library);library.add_animation("Savage_Dance",clip)
		human.animator.play("Savage_Dance",0.);human.animator.pause()
		check(clip.get_track_count()==human.skeleton.get_bone_count()*2 and clip.loop_mode==Animation.LOOP_NONE,"Every target joint has explicit position/rotation tracks for a one-shot action")
		var document:=GLTFDocument.new();var state:=GLTFState.new()
		check(document.append_from_file(ProjectSettings.globalize_path(reference+str(source_row.output)),state)==OK,"Actual original dance reference loads")
		var source:=document.generate_scene(state);root.add_child(source)
		var source_rig: Skeleton3D=source.find_children("*","Skeleton3D",true,false)[0]
		var player: AnimationPlayer=source.find_children("*","AnimationPlayer",true,false)[0]
		var source_mesh: MeshInstance3D=source.find_children("Body*","MeshInstance3D",true,false)[0]
		var target_mesh: MeshInstance3D=human.model.find_children("Body*","MeshInstance3D",true,false)[0]
		player.play("TribalDance");player.pause()
		var worst_floor:=0.;var worst_basis:=0.;var worst_offset:=0.;var lift:=0.;var samples: Array=[]
		var mappings: Array=row.mapping
		check(mappings.size()==52,"Complete explicit original-to-modern joint mapping is recorded")
		for index in 193:
			# Different fractional phases from the 60 Hz generation grid.
			var time:=clip.length*(float(index)+.371)/193.
			player.seek(time,true);human.animator.seek(time,true);source_rig.force_update_all_bone_transforms();human.skeleton.force_update_all_bone_transforms()
			var expected:=Geometry.deformed_bounds(source_mesh,source_rig).position.y
			var bounds:=Geometry.deformed_bounds(target_mesh,human.skeleton)
			var observed:=bounds.position.y;var error:=absf(observed-expected);worst_floor=maxf(worst_floor,error);lift=maxf(lift,observed)
			check(bounds.position.is_finite() and bounds.size.is_finite() and error<.004,"Off-grid complete skin retains original clearance within four millimetres")
			for bone in human.skeleton.get_bone_count():
				if human.skeleton.get_bone_name(bone)=="pelvis":continue
				var difference:=human.skeleton.get_bone_pose_position(bone).distance_to(human.skeleton.get_bone_rest(bone).origin)
				worst_offset=maxf(worst_offset,difference);check(difference<.000001,"Fixed modern joint offsets retain limb proportions")
			for pair: Dictionary in mappings:
				var from:=source_rig.find_bone(str(pair.source));var to:=human.skeleton.find_bone(str(pair.target))
				check(from>=0 and to>=0,"Declared source and modern joint exist")
				if from<0 or to<0:continue
				var a:=source_rig.global_basis.orthonormalized();var b:=human.skeleton.global_basis.orthonormalized()
				var wanted:=a*source_rig.get_bone_global_pose(from).basis*source_rig.get_bone_global_rest(from).basis.inverse()*a.inverse()
				var actual:=b*human.skeleton.get_bone_global_pose(to).basis*human.skeleton.get_bone_global_rest(to).basis.inverse()*b.inverse()
				var difference:=maxf(wanted.x.distance_to(actual.x),maxf(wanted.y.distance_to(actual.y),wanted.z.distance_to(actual.z)))
				worst_basis=maxf(worst_basis,difference);check(difference<.0001,"Off-grid original global rotation change survives retargeting")
			samples.append({"time":time,"source_clearance_m":expected,"target_clearance_m":observed})
		check(lift>.12,"Original airborne dance phase is preserved instead of flattened")
		var first_picture: Image
		for phase in [0.,.25,.5,.75]:
			human.animator.seek(clip.length*phase,true)
			await process_frame;await RenderingServer.frame_post_draw
			var picture:=viewport.get_texture().get_image()
			check(not picture.is_empty(),"Actual modern dance GPU pose renders")
			var occupied:=0;var changed:=0
			for y in range(0,picture.get_height(),4):
				for x in range(0,picture.get_width(),4):
					var pixel:=picture.get_pixel(x,y)
					if maxf(pixel.r,maxf(pixel.g,pixel.b))>.25:occupied+=1
					if first_picture!=null:
						var before:=first_picture.get_pixel(x,y)
						if Vector3(pixel.r,pixel.g,pixel.b).distance_to(Vector3(before.r,before.g,before.b))>.1:changed+=1
			check(occupied>500,"Actual GPU capture contains the visible body, not an empty frame")
			if first_picture==null:first_picture=picture.duplicate()
			else:check(changed>150,"Actual GPU dance phase differs visibly from its initial pose")
			var picture_path:="res://../work/creatures/savages/dance-%s-%02d.png"%[gender,roundi(phase*100)]
			picture.save_png(picture_path);captures.append({"path":picture_path,"sha256":FileAccess.get_sha256(picture_path),"occupied_samples":occupied,"changed_samples":changed})
			rendered+=1
		rows.append({"gender":gender,"complete_skin_holdouts":samples,"mapped_bones":52,"maximum_floor_error_m":worst_floor,"maximum_global_basis_error":worst_basis,"maximum_local_offset_error_m":worst_offset,"preserved_lift_m":lift,"asset_sha256":row.asset_sha256})
		human.free();source.free()
	for name in INPUTS:check(runtime[name]==FileAccess.get_sha256("res://Presentation/"+name),"Runtime/test unchanged during sampling")
	check(preparation_sha==FileAccess.get_sha256(folder+"preparation.json") and source_sha==FileAccess.get_sha256(reference+"preparation.json"),"Prepared/reference inputs unchanged during sampling")
	check(sha_optional(accepted_path)==accepted_start,"Dance trials leave accepted body/action index unchanged")
	var report:={"checks":checks,"failures":failures,"models":rows,"rendered_poses":rendered,"captures":captures,"runtime_sha256":runtime,"preparation_sha256":preparation_sha,"source_preparation_sha256":source_sha,"scope":"386 off-grid complete-skin/rotation/length samples on actual baked rigs, shared CPU skin kernel, plus eight actual GPU captures. No native111, slopes, transitions, clothing dynamics or runtime acceptance."}
	var file:=FileAccess.open("res://../work/creatures/savages/dance-tests.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SAVAGE DANCE: ",checks," checks / ",failures," failures; ",rendered," GPU captures; no runtime acceptance");quit(1 if failures else 0)
