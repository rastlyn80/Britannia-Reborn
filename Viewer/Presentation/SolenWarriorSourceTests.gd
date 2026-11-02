extends SceneTree
## Original/refined eight-slot ant meshes, source rig/UV and whole weighted skins.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Solen warrior source deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<10:push_error(label)
func run() -> void:
	var prep_path:="res://local-art/creatures/solen_warriors/preparation.json";var prep_pin:=FileAccess.get_sha256(prep_path);var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prep_path))
	var records: Array=[];var asset_pins: Dictionary={};var ground_pins: Dictionary={};var gait_ranges: Dictionary={};var maximum_joint:=0.;var maximum_basis:=0.;var maximum_floor:=0.;var maximum_raw_floor:=0.;var poses:=0
	for record: Dictionary in prep.models:
		var ground_path: String="res://local-art/creatures/"+str(record.kind)+"-ground.json";ground_pins[ground_path]=FileAccess.get_sha256(ground_path)
		var measurement: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ground_path));check(measurement.preparation_sha256==prep_pin and measurement.recipe_sha256==FileAccess.get_sha256("res://Presentation/BakeSolenWarriorGround.gd") and measurement.geometry_sha256==FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd"),"Actual residuals belong to this exact original/refined import")
		var actors: Array=[];var clips: PackedStringArray=[]
		for treatment: String in ["original","rounded","modern"]:
			var path: String="res://local-art/creatures/"+str(record.kind)+"-"+treatment+".gltf";asset_pins[path]=FileAccess.get_sha256(path)
			var document:=GLTFDocument.new();var state:=GLTFState.new();check(document.append_from_file(ProjectSettings.globalize_path(path),state)==OK,"Actual source ant GLTF imports without losing the extra weight set")
			var model:=document.generate_scene(state);root.add_child(model)
			var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0];var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0];var mesh: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
			player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;player.deterministic=true
			check(rig.get_bone_count()==44,"All44 original source mesh joints remain")
			var arrays:=mesh.mesh.surface_get_arrays(0);var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var stride: int=weights.size()/points.size();var extended:=0
			check(stride==8 and bool(mesh.mesh.surface_get_format(0)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS),"Original/refined actual source mesh uses eight-slot skin data")
			for vertex in points.size():
				var total:=0.;var used:=0
				for slot in stride:
					var weight:=weights[vertex*stride+slot];total+=weight
					if weight>.00001:used+=1
					check(is_finite(weight) and weight>=0.,"Source/refined weights remain finite/nonnegative")
				check(absf(total-1.)<.0001 and points[vertex].is_finite() and normals[vertex].is_finite(),"Actual source skin/normal/point is finite and normalized")
				if used>4:extended+=1
			check(extended>0,"Five-influence source vertices survive actual import and refinement")
			var names: PackedStringArray=[]
			for clip: String in player.get_animation_list():
				if clip=="RESET":continue
				names.append(clip);player.get_animation(clip).loop_mode=Animation.LOOP_NONE
			if clips.is_empty():clips=names
			check(names==clips and names.size()==10,"All ten selected original motions in every treatment")
			check(measurement.treatments[treatment].asset_sha256==asset_pins[path],"Residuals match the current source/refined asset")
			for gait: String in ["Walk","Run"]:
				var samples: Array=measurement.treatments[treatment].clips[gait];var fixed:=true
				for sample: Array in samples:fixed=fixed and is_equal_approx(float(sample[1]),float(samples[0][1]))
				check(fixed,"One whole-clip imported anchor preserves the original source gait rise")
			actors.append({"model":model,"player":player,"rig":rig,"mesh":mesh,"extended_vertices":extended,"curves":Ground.load_curves(ground_path,treatment)})
		for clip: String in clips:
			for step in 23:
				var phase:=0. if step==0 else 1. if step==22 else (float(step)-.317)/22.;var reference: Array=[]
				for index in actors.size():
					var actor: Dictionary=actors[index];var player: AnimationPlayer=actor.player;var rig: Skeleton3D=actor.rig
					player.play(clip,0.);player.seek(player.get_animation(clip).length*phase,true);player.advance(0.);player.pause();rig.force_update_all_bone_transforms()
					var origin:=rig.get_bone_global_pose(0).origin;var error:=0.;var basis_error:=0.
					for bone in rig.get_bone_count():
						var pose:=rig.get_bone_global_pose(bone);pose.origin-=origin
						if index==0:reference.append(pose)
						else:
							var source: Transform3D=reference[bone];error=maxf(error,pose.origin.distance_to(source.origin));basis_error=maxf(basis_error,maxf(pose.basis.x.distance_to(source.basis.x),maxf(pose.basis.y.distance_to(source.basis.y),pose.basis.z.distance_to(source.basis.z))))
					actor.model.position.y=0.;var raw_box:=Geometry.deformed_bounds(actor.mesh,rig);maximum_raw_floor=maxf(maximum_raw_floor,absf(raw_box.position.y))
					actor.model.position.y=Ground.sample(actor.curves,clip,player.current_animation_position)
					var box:=Geometry.deformed_bounds(actor.mesh,rig);poses+=1;maximum_joint=maxf(maximum_joint,error);maximum_basis=maxf(maximum_basis,basis_error)
					check(error<.00001 and basis_error<.00001,"Every relative source joint/basis retained across refinement")
					check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.2,"Complete actual eight-slot source/refined skin remains finite")
					if clip in ["Walk","Run"]:
						check(box.position.y>-.008,"One constant gait anchor retains source bounce without floor penetration")
						var key: String=str(record.kind)+"/"+str(index)+"/"+clip
						var range_: Array=gait_ranges.get(key,[INF,-INF]);range_[0]=minf(float(range_[0]),box.position.y);range_[1]=maxf(float(range_[1]),box.position.y);gait_ranges[key]=range_
					else:
						maximum_floor=maxf(maximum_floor,absf(box.position.y))
						check(absf(box.position.y)<.008,"Actual complete source/refined ant stays within8mm of the review floor")
					records.append({"kind":record.kind,"clip":clip,"phase":phase,"treatment":index,"body_floor_m":box.position.y,"raw_floor_m":raw_box.position.y,"relative_joint_error_m":error,"basis_error":basis_error})
		for actor: Dictionary in actors:actor.model.free()
	check(prep_pin==FileAccess.get_sha256(prep_path),"Prepared ant input remains unchanged during real engine tests")
	for path: String in asset_pins:check(asset_pins[path]==FileAccess.get_sha256(path),"Exact source/refined GLTF remains unchanged")
	for path: String in ground_pins:check(ground_pins[path]==FileAccess.get_sha256(path),"Measured residual curves remain unchanged")
	var report:={"checks":checks,"failures":failures,"poses":poses,"records":records,"gait_floor_ranges_m":gait_ranges,"maximum_relative_joint_error_m":maximum_joint,"maximum_basis_error":maximum_basis,"maximum_floor_error_m":maximum_floor,"maximum_raw_floor_error_m":maximum_raw_floor,"assets_sha256":asset_pins,"ground_measurement_sha256":ground_pins,"preparation_sha256":prep_pin,"runtime_sha256":{"SolenWarriorSourceTests.gd":FileAccess.get_sha256("res://Presentation/SolenWarriorSourceTests.gd"),"SkinGeometry.gd":FileAccess.get_sha256("res://Presentation/SkinGeometry.gd") ,"SourceGroundLookup.gd":FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd")},"scope":"Actual source ant eight-slot GLTF import, all44 mesh joints/ten selected source motions, retained five-influence vertices, finite normals/full weighted skins and source/refined relative poses at23off-grid phases. Actual960Hz full-skin action residuals; one whole-clip gait anchor preserves source bounce. No source joint-channel edits. No render/terrain/native action/hue/corpse/AI or family acceptance."}
	FileAccess.open("res://../work/creatures/solen-warriors/source-poses.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("SOLEN WARRIOR SOURCE: ",checks," checks / ",failures," failures / ",poses," poses / floor",maximum_floor);quit(1 if failures else 0)
