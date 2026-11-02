extends SceneTree
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const FOLDER="res://local-art/creatures/"
const KINDS=["mages_evil_mage","mages_evil_mage_master"]
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Mage raw pose deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<12:push_error(label)
func pose(actor: Node3D,clip: String,phase: float) -> AABB:
	var player: AnimationPlayer=actor.find_children("*","AnimationPlayer",true,false)[0];var rig: Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0];var mesh: MeshInstance3D=actor.find_children("*","MeshInstance3D",true,false)[0]
	player.play(clip,0.);player.seek(player.get_animation(clip).length*phase,true);player.advance(0.);player.pause();rig.force_update_all_bone_transforms();return Geometry.deformed_bounds(mesh,rig)
func run() -> void:
	var all_actors: Array=[];var samples: Array=[];var pairs:=0;var maximum_floor:=0.;var maximum_joint:=0.;var maximum_basis:=0.;var assets: Dictionary={};var floor_by_clip: Dictionary={}
	for kind: String in KINDS:
		var actors: Array=[];var clips: PackedStringArray=[];assets[kind]={}
		for treatment: String in ["original","rounded","modern"]:
			var path: String=FOLDER+kind+"-"+treatment+".gltf";var actor:=load(path).instantiate() as Node3D;root.add_child(actor);actors.append(actor);all_actors.append(actor)
			var player: AnimationPlayer=actor.find_children("*","AnimationPlayer",true,false)[0];var rig: Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0];player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			check(rig.get_bone_count()==36,"All36 source joints retained")
			var saved: PackedStringArray=[]
			for clip: String in player.get_animation_list():
				if clip=="RESET":continue
				player.get_animation(clip).loop_mode=Animation.LOOP_NONE;saved.append(clip)
			if clips.is_empty():clips=saved
			else:check(saved==clips,"Identical category set in source/refined/modern")
			assets[kind][treatment]={"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")}
		for clip: String in clips:
			for step in 37:
				var phase:=0. if step==0 else 1. if step==36 else (float(step)-.317)/36.;var reference: Array=[];var bases: Array=[]
				for i in actors.size():
					var actor: Node3D=actors[i];var box:=pose(actor,clip,phase);var rig: Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0];var origin:=rig.get_bone_global_pose(0).origin;var joints: Array=[];var error:=0.;var basis_error:=0.
					for bone in rig.get_bone_count():joints.append(rig.get_bone_global_pose(bone).origin-origin)
					if i==0:
						reference=joints
						for bone in rig.get_bone_count():bases.append(rig.get_bone_global_pose(bone).basis)
					else:
						pairs+=1
						for bone in rig.get_bone_count():
							error=maxf(error,(joints[bone] as Vector3).distance_to(reference[bone]));var a: Basis=rig.get_bone_global_pose(bone).basis;var b: Basis=bases[bone];basis_error=maxf(basis_error,maxf(a.x.distance_to(b.x),maxf(a.y.distance_to(b.y),a.z.distance_to(b.z))))
					maximum_floor=maxf(maximum_floor,absf(box.position.y));maximum_joint=maxf(maximum_joint,error);maximum_basis=maxf(maximum_basis,basis_error);var key:=kind+"/"+clip;floor_by_clip[key]=maxf(float(floor_by_clip.get(key,0.)),absf(box.position.y))
					check(error<.00001 and basis_error<.00001,"Same-phase source joint centres and bases retained")
					check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.5,"Complete actual imported weighted skin finite");check(absf(box.position.y)<.008,"Complete imported source/refined skin stays within8mm of ground")
					samples.append({"kind":kind,"clip":clip,"phase":phase,"treatment":i,"floor_m":box.position.y,"joint_error_m":error,"basis_error":basis_error})
	var timing: Array=[];var preparation:="res://local-art/creatures/mages/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation))
	for record: Dictionary in prep.models:
		for identity: Dictionary in record.bodies:
			var visual:=preload("res://Presentation/SourceMageVisual.gd").new();visual.entry=record;root.add_child(visual);visual.apply_identity(int(identity.body),0);visual.set_process(false);visual.set_physics_process(false);visual.contact.active=false;visual.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			for request: Dictionary in [{"protocol":"classic","action":4},{"protocol":"classic","action":5},{"protocol":"classic","action":10},{"protocol":"classic","action":11},{"protocol":"classic","action":12},{"protocol":"classic","action":14},{"protocol":"new","type":11}]:
				for rate in [.65,1.,1.65]:
					visual.dead=false;visual.animator.stop();visual.animator.speed_scale=rate;request.frames=9;request.delay=1;request.repeat_count=0;request.repeat=false;request.reverse=false
					check(visual.receive_action(request),"Native action group resolves to declared original/authored category")
					var expected: String="Cast2" if request.protocol=="new" else str({4:"Attack",5:"Attack2",10:"Hit",11:"Pillage",12:"Cast2",14:"Cast2"}[int(request.action)]);check(visual.current_clip==expected,"Native action selects the intended original/authored category")
					var duration:=preload("res://Presentation/HumanActions.gd").duration(request,visual.animator.get_animation(visual.current_clip).length);visual.animator.advance(duration*.5)
					var position:=visual.animator.current_animation_position;var length:=visual.animator.get_animation(visual.current_clip).length
					check(absf(position-length*.5)<.001,"Native packet duration ignores preceding gait rate")
					check(visual.receive_action(request) and visual.animator.current_animation_position<.00001,"Repeated native action starts at clip beginning")
					timing.append({"body":identity.body,"request":request.duplicate(true),"prior_rate":rate,"clip":visual.current_clip,"position":position,"length":length})
			for mesh: MeshInstance3D in visual.model.find_children("*","MeshInstance3D",true,false):
				for surface in mesh.mesh.get_surface_count():mesh.set_surface_override_material(surface,null)
			visual.free()
	var report:={"checks":checks,"failures":failures,"samples":samples,"paired_poses":pairs,"maximum_joint_error_m":maximum_joint,"maximum_basis_error":maximum_basis,"maximum_floor_error_m":maximum_floor,"floor_error_by_clip":floor_by_clip,"assets":assets,"native_timing":timing,"recipe_sha256":FileAccess.get_sha256("res://Presentation/SourceMageActionTests.gd"),"geometry_sha256":FileAccess.get_sha256("res://Presentation/SkinGeometry.gd"),"preparation_sha256":FileAccess.get_sha256(preparation),"scope":"Actual saved source/refined/modern36-joint centres/bases, full skins and native category/timing/restart dispatch. Original nine source motions plus explicitly authored Pillage; proper-rotation affine rebinding, no exact original affine skin fidelity or native socket certification."};DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/mages"));FileAccess.open("res://../outputs/creatures/mages/actions.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("SOURCE MAGE ACTIONS: ",checks," / ",failures,"failures / ",samples.size()," skins; floor ",maximum_floor);quit(1 if failures else 0)
