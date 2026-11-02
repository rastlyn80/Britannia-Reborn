extends SceneTree
## Original private Ice161 source/refined rigs and complete weighted skins.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
const FOLDER="res://../work/creatures/ice-elemental/prepared/"
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Original Ice source deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<14:push_error(label)
func run() -> void:
	var prep_path:=FOLDER+"preparation.json";var prep_pin:=FileAccess.get_sha256(prep_path);var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prep_path));var row: Dictionary=prep.models[0]
	var ground_path:=FOLDER+str(row.kind)+"-ground.json";var ground_pin:=FileAccess.get_sha256(ground_path);var measurement: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ground_path))
	check(measurement.preparation_sha256==prep_pin and measurement.recipe_sha256==FileAccess.get_sha256("res://Presentation/BakeIceElementalGround.gd") and measurement.geometry_sha256==FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd"),"Actual imported skin residuals match exact original inputs and measurement recipe")
	var actors: Array=[];var pins: Dictionary={};var records: Array=[];var maximum_joint:=0.;var maximum_basis:=0.;var maximum_floor:=0.;var poses:=0;var clips: PackedStringArray=[];var run_ranges: Dictionary={}
	check(int(row.bodies[0].body)==161 and int(row.bodies[0].animation_body)==158 and row.bodies[0].scale==[1.3,1.3,1.3],"Own native Ice161 identity and explicit table motion link retained")
	for treatment: String in ["original","rounded","modern"]:
		var path:=FOLDER+str(row.kind)+"-"+treatment+".gltf";pins[path]=FileAccess.get_sha256(path);var document:=GLTFDocument.new();var state:=GLTFState.new();check(document.append_from_file(ProjectSettings.globalize_path(path),state)==OK,"Actual private original Ice GLTF imports")
		var model:=document.generate_scene(state);root.add_child(model);var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0];var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0];var mesh: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;player.deterministic=true
		check(rig.get_bone_count()==34,"All34source mesh joints survive refinement")
		var a:=mesh.mesh.surface_get_arrays(0);var points: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var normals: PackedVector3Array=a[Mesh.ARRAY_NORMAL];check(weights.size()==points.size()*4,"Legacy four-slot skin remains explicit")
		for vertex in points.size():
			var total:=0.
			for slot in 4:total+=weights[vertex*4+slot]
			check(points[vertex].is_finite() and normals[vertex].is_finite() and absf(total-1.)<.0001,"Complete source/refined Ice skin data is finite and normalized")
		var names: PackedStringArray=[]
		for clip: String in player.get_animation_list():
			if clip=="RESET":continue
			names.append(clip);player.get_animation(clip).loop_mode=Animation.LOOP_NONE
		if clips.is_empty():clips=names
		check(names==clips and names.size()==13,"Twelve original named motions plus explicit Stomp/Pillage reuse survive")
		check(measurement.treatments[treatment].asset_sha256==pins[path],"Complete-skin residuals match each exact imported asset")
		actors.append({"model":model,"player":player,"rig":rig,"mesh":mesh,"treatment":treatment,"curves":Ground.load_curves(ground_path,treatment)});run_ranges[treatment]=[INF,-INF]
	for clip: String in clips:
		for step in 17:
			var phase:=0. if step==0 else 1. if step==16 else (float(step)-.317)/16.;var reference: Array=[]
			for index in actors.size():
				var actor: Dictionary=actors[index];var player: AnimationPlayer=actor.player;var rig: Skeleton3D=actor.rig;player.play(clip,0.);player.seek(player.get_animation(clip).length*phase,true);player.advance(0.);player.pause();rig.force_update_all_bone_transforms();var origin:=rig.get_bone_global_pose(0).origin;var joint_error:=0.;var basis_error:=0.
				for bone in rig.get_bone_count():
					var pose:=rig.get_bone_global_pose(bone);pose.origin-=origin
					if index==0:reference.append(pose)
					else:
						var target: Transform3D=reference[bone];joint_error=maxf(joint_error,pose.origin.distance_to(target.origin));basis_error=maxf(basis_error,maxf(pose.basis.x.distance_to(target.basis.x),maxf(pose.basis.y.distance_to(target.basis.y),pose.basis.z.distance_to(target.basis.z))))
				actor.model.position.y=Ground.sample(actor.curves,clip,player.current_animation_position)
				var box:=Geometry.deformed_bounds(actor.mesh,rig);poses+=1;maximum_joint=maxf(maximum_joint,joint_error);maximum_basis=maxf(maximum_basis,basis_error)
				check(joint_error<.00001 and basis_error<.00001,"Every original relative joint/basis survives the refined skin")
				check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.5,"Actual complete Ice skin remains finite")
				if clip=="Run":
					check(box.position.y>-.008,"One whole-clip Run anchor retains source rise without penetration")
					var range_: Array=run_ranges[actor.treatment];range_[0]=minf(float(range_[0]),box.position.y);range_[1]=maxf(float(range_[1]),box.position.y)
				else:
					maximum_floor=maxf(maximum_floor,absf(box.position.y));check(absf(box.position.y)<.008,"Actual imported source action stays within8mm of its review floor")
				records.append({"clip":clip,"phase":phase,"treatment":actor.treatment,"body_floor_m":box.position.y,"relative_joint_error_m":joint_error,"basis_error":basis_error})
	for actor: Dictionary in actors:actor.model.free()
	for path: String in pins:check(pins[path]==FileAccess.get_sha256(path),"Exact private source asset unchanged")
	check(prep_pin==FileAccess.get_sha256(prep_path),"Original Ice preparation unchanged")
	check(ground_pin==FileAccess.get_sha256(ground_path),"Actual measured source support unchanged")
	var report:={"checks":checks,"failures":failures,"poses":poses,"records":records,"run_floor_ranges_m":run_ranges,"maximum_relative_joint_error_m":maximum_joint,"maximum_basis_error":maximum_basis,"maximum_grounded_error_m":maximum_floor,"preparation_sha256":prep_pin,"ground_measurement_sha256":ground_pin,"assets_sha256":pins,"runtime_sha256":{"IceElementalSourceTests.gd":FileAccess.get_sha256("res://Presentation/IceElementalSourceTests.gd"),"SkinGeometry.gd":FileAccess.get_sha256("res://Presentation/SkinGeometry.gd"),"SourceGroundLookup.gd":FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd")},"scope":"Actual original/refined Ice161 direct imports,34mesh joints,12named source motions plus explicit Pillage reuse, complete weighted skins and source-relative rig fidelity at17off-grid phases with actual960Hz model-only action residuals. Source Run rise retained without correction. No saved-import/material/GPU/native/avatar/terrain/death/corpse/family acceptance."}
	FileAccess.open("res://../work/creatures/ice-elemental/source-poses.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("ORIGINAL ICE SOURCE:",checks,"checks/",failures,"failures/",poses,"poses; floor",maximum_floor);quit(1 if failures else 0)
