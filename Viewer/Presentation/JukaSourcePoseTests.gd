extends SceneTree
## Compare actual imported source/refined skeletons and complete weighted skins.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const FOLDER="res://local-art/creatures/"
const PREPARATION=FOLDER+"juka/preparation.json"
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(300.).timeout.connect(func():push_error("Juka source pose deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<16:push_error(label)
func run() -> void:
	var preparation_pin:=FileAccess.get_sha256(PREPARATION)
	var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PREPARATION))
	var samples: Array=[];var assets: Dictionary={};var maximum_joint:=0.;var maximum_basis:=0.;var maximum_floor:=0.;var pairs:=0
	for record: Dictionary in prep.models:
		var kind: String=record.kind;var actors: Array=[];var clips: PackedStringArray=[];assets[kind]={}
		for treatment: String in ["original","rounded","modern"]:
			var path:=FOLDER+kind+"-"+treatment+".gltf";var actor:=load(path).instantiate() as Node3D;root.add_child(actor)
			var player: AnimationPlayer=actor.find_children("*","AnimationPlayer",true,false)[0];var rig: Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0];var mesh: MeshInstance3D=actor.find_children("*","MeshInstance3D",true,false)[0]
			player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			check(rig.get_bone_count()==int(record.stats.original.bones),"All original Juka mesh joints retained")
			var saved: PackedStringArray=[]
			for clip: String in player.get_animation_list():
				if clip=="RESET":continue
				player.get_animation(clip).loop_mode=Animation.LOOP_NONE;saved.append(clip)
			if clips.is_empty():clips=saved
			else:check(saved==clips,"Same selected original category set in every treatment")
			check(saved.size()==13,"Thirteen selected original human motion categories retained")
			assets[kind][treatment]={"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")}
			actors.append({"node":actor,"player":player,"rig":rig,"mesh":mesh})
		for clip: String in clips:
			for step in 37:
				var phase:=0. if step==0 else 1. if step==36 else (float(step)-.317)/36.;var reference: Array=[]
				for index in actors.size():
					var actor: Dictionary=actors[index];var player: AnimationPlayer=actor.player;var rig: Skeleton3D=actor.rig
					player.play(clip,0.);player.seek(player.get_animation(clip).length*phase,true);player.advance(0.);player.pause();rig.force_update_all_bone_transforms()
					var box:=Geometry.deformed_bounds(actor.mesh,rig);var origin:=rig.get_bone_global_pose(0).origin;var error:=0.;var basis_error:=0.
					for bone in rig.get_bone_count():
						var pose:=rig.get_bone_global_pose(bone);pose.origin-=origin
						if index==0:reference.append(pose)
						else:
							var source: Transform3D=reference[bone];error=maxf(error,pose.origin.distance_to(source.origin));basis_error=maxf(basis_error,maxf(pose.basis.x.distance_to(source.basis.x),maxf(pose.basis.y.distance_to(source.basis.y),pose.basis.z.distance_to(source.basis.z))))
					if index>0:pairs+=1
					check(error<.00001 and basis_error<.00001,"Relative source rig centres and bases retained")
					check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.5,"Complete weighted Juka skin finite")
					check(absf(box.position.y)<.008,"Full imported source/refined skin within8mm of ground")
					maximum_joint=maxf(maximum_joint,error);maximum_basis=maxf(maximum_basis,basis_error);maximum_floor=maxf(maximum_floor,absf(box.position.y))
					samples.append({"kind":kind,"clip":clip,"phase":phase,"treatment":index,"floor_m":box.position.y,"joint_error_m":error,"basis_error":basis_error})
		for actor: Dictionary in actors:actor.node.free()
	check(preparation_pin==FileAccess.get_sha256(PREPARATION),"Preparation unchanged throughout pose test")
	for kind: String in assets:
		for treatment: String in assets[kind]:
			var path:=FOLDER+kind+"-"+treatment+".gltf";var pin: Dictionary=assets[kind][treatment]
			check(pin.asset_sha256==FileAccess.get_sha256(path) and pin.import_sha256==FileAccess.get_sha256(path+".import"),"Asset/import unchanged throughout pose test")
	var report:={"checks":checks,"failures":failures,"samples":samples,"paired_poses":pairs,"maximum_joint_error_m":maximum_joint,"maximum_basis_error":maximum_basis,"maximum_floor_error_m":maximum_floor,"assets":assets,"test_sha256":FileAccess.get_sha256("res://Presentation/JukaSourcePoseTests.gd"),"geometry_sha256":FileAccess.get_sha256("res://Presentation/SkinGeometry.gd"),"preparation_sha256":preparation_pin,"scope":"Actual saved source/refined/modern Juka mesh rigs and thirteen selected original human motion categories each. Relative joint/basis and complete weighted skin measurements. Not exact recovered original category assignments, terrain/action routing, material/corpse/native acceptance or gameplay."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/juka"));FileAccess.open("res://../outputs/creatures/juka/source-poses.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("JUKA SOURCE POSES: ",checks," checks / ",failures," failures / ",samples.size()," skins; maximum floor=",maximum_floor);quit(1 if failures else 0)
