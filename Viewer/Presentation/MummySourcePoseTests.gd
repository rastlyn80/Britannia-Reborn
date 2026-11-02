extends SceneTree
## Imported original/refined Mummy skins and rigs; no accepted runtime route.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
const FOLDER="res://local-art/creatures/"
const PREPARATION=FOLDER+"mummies/preparation.json"
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(120.).timeout.connect(func():push_error("Mummy source pose deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<12:push_error(label)
func run() -> void:
	var prep_pin:=FileAccess.get_sha256(PREPARATION);var test_pin:=FileAccess.get_sha256("res://Presentation/MummySourcePoseTests.gd")
	var geometry_pin:=FileAccess.get_sha256("res://Presentation/SkinGeometry.gd")
	var ground_path:=FOLDER+"walking_dead_mummy-ground.json";var ground_pin:=FileAccess.get_sha256(ground_path)
	var measurement: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ground_path))
	check(measurement.preparation_sha256==prep_pin and measurement.recipe_sha256==FileAccess.get_sha256("res://Presentation/BakeSourceMummyGround.gd") and measurement.geometry_sha256==FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd"),"Exact imported complete-skin residual measurement matches source and recipe")
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PREPARATION))
	var record: Dictionary=preparation.models[0];var actors: Array=[];var assets: Dictionary={};var clips: PackedStringArray=[]
	var samples: Array=[];var maximum_joint:=0.;var maximum_basis:=0.;var maximum_floor:=0.;var maximum_raw_floor:=0.;var pairs:=0
	for treatment: String in ["original","rounded","modern"]:
		var path:=FOLDER+str(record.kind)+"-"+treatment+".gltf";var node:=load(path).instantiate() as Node3D;root.add_child(node)
		var player: AnimationPlayer=node.find_children("*","AnimationPlayer",true,false)[0];var rig: Skeleton3D=node.find_children("*","Skeleton3D",true,false)[0];var mesh: MeshInstance3D=node.find_children("*","MeshInstance3D",true,false)[0]
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		check(rig.get_bone_count()==33,"Every original mesh joint retained")
		var names: PackedStringArray=[]
		for clip: String in player.get_animation_list():
			if clip=="RESET":continue
			names.append(clip);player.get_animation(clip).loop_mode=Animation.LOOP_NONE
		if clips.is_empty():clips=names
		check(names==clips and names.size()==7,"All seven original motion categories in every treatment")
		assets[treatment]={"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")}
		check(assets[treatment].asset_sha256==measurement.treatments[treatment].asset_sha256 and assets[treatment].import_sha256==measurement.treatments[treatment].import_sha256,"Measured curves belong to this exact imported skin")
		actors.append({"node":node,"player":player,"rig":rig,"mesh":mesh,"curves":Ground.load_curves(ground_path,treatment)})
	for clip: String in clips:
		for step in 37:
			var phase:=0. if step==0 else 1. if step==36 else (float(step)-.317)/36.;var reference: Array=[]
			for index in actors.size():
				var actor: Dictionary=actors[index];var player: AnimationPlayer=actor.player;var rig: Skeleton3D=actor.rig
				player.play(clip,0.);player.seek(player.get_animation(clip).length*phase,true);player.advance(0.);player.pause();rig.force_update_all_bone_transforms()
				actor.node.position.y=0.;var raw_box:=Geometry.deformed_bounds(actor.mesh,rig)
				actor.node.position.y=Ground.sample(actor.curves,clip,player.current_animation_position)
				var box:=Geometry.deformed_bounds(actor.mesh,rig);var origin:=rig.get_bone_global_pose(0).origin;var joint_error:=0.;var basis_error:=0.
				for bone in rig.get_bone_count():
					var pose:=rig.get_bone_global_pose(bone);pose.origin-=origin
					if index==0:reference.append(pose)
					else:
						var source: Transform3D=reference[bone];joint_error=maxf(joint_error,pose.origin.distance_to(source.origin))
						basis_error=maxf(basis_error,maxf(pose.basis.x.distance_to(source.basis.x),maxf(pose.basis.y.distance_to(source.basis.y),pose.basis.z.distance_to(source.basis.z))))
				if index>0:pairs+=1
				check(joint_error<.00001 and basis_error<.00001,"Refinement retains relative source joint positions and bases")
				check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.5,"Complete original/refined weighted body remains finite")
				check(absf(box.position.y)<.008,"Complete prepared body remains within8mm of the flat review floor")
				maximum_joint=maxf(maximum_joint,joint_error);maximum_basis=maxf(maximum_basis,basis_error);maximum_floor=maxf(maximum_floor,absf(box.position.y))
				maximum_raw_floor=maxf(maximum_raw_floor,absf(raw_box.position.y))
				samples.append({"clip":clip,"phase":phase,"treatment":index,"raw_body_floor_m":raw_box.position.y,"body_floor_m":box.position.y,"joint_error_m":joint_error,"basis_error":basis_error})
	for actor: Dictionary in actors:actor.node.free()
	check(prep_pin==FileAccess.get_sha256(PREPARATION) and test_pin==FileAccess.get_sha256("res://Presentation/MummySourcePoseTests.gd") and geometry_pin==FileAccess.get_sha256("res://Presentation/SkinGeometry.gd"),"Source proof inputs remain unchanged during trial")
	for treatment: String in assets:
		var path:=FOLDER+str(record.kind)+"-"+treatment+".gltf";var pin: Dictionary=assets[treatment]
		check(pin.asset_sha256==FileAccess.get_sha256(path) and pin.import_sha256==FileAccess.get_sha256(path+".import"),"Asset/import remains unchanged during trial")
	check(ground_pin==FileAccess.get_sha256(ground_path),"Residual curves unchanged during independent split-vertex pose tests")
	var report:={"checks":checks,"failures":failures,"samples":samples,"paired_poses":pairs,"maximum_joint_error_m":maximum_joint,"maximum_basis_error":maximum_basis,"maximum_floor_error_m":maximum_floor,"maximum_raw_floor_error_m":maximum_raw_floor,"ground_measurement_sha256":ground_pin,"assets":assets,"preparation_sha256":prep_pin,"runtime_sha256":{"MummySourcePoseTests.gd":test_pin,"SkinGeometry.gd":geometry_pin,"SourceGroundLookup.gd":FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd")},"scope":"Actual Godot imported original/refined/candidate Mummy rigs and complete split-vertex skins at37phases of seven original clips.960Hz residual lookup supports the model without modifying any source animation channel. Relative rig equivalence after subdivision. Two unweighted finger leaves absent from coarse mesh are declared by strict matcher. No source-to-client exact choreography, GPU/material/mask, actual action/terrain/corpse/native acceptance or gameplay."}
	var file:=FileAccess.open("res://../work/creatures/mummies/source-poses.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MUMMY SOURCE POSES: ",checks," checks / ",failures," failures / ",samples.size()," skins / ",pairs," pairs; maximum floor=",maximum_floor);quit(1 if failures else 0)
