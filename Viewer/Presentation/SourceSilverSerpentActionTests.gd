extends SceneTree
const Visual=preload("res://Presentation/SourceSilverSerpentVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const CATEGORIES=["Idle","Walk","Run","Attack","Hit","Death","Fidget","Pillage","Eat","LieDown"]
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Silver source action deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<15:push_error(label)
func pose(visual: Node3D,clip: String,phase: float) -> void:
	visual.dead=false;visual.action_remaining=0.;visual.play(clip,0.);visual.animator.seek(visual.animator.get_animation(clip).length*phase,true);visual.animator.advance(0.);visual.animator.pause();visual.skeleton.force_update_all_bone_transforms();visual.apply_ground()
func run() -> void:
	var preparation:="res://local-art/creatures/silver_serpents/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation));var record: Dictionary=prep.models[0];Registry.load_index()
	for body in [91,92,93]:Registry.entries[body]=record
	var avatar:=Avatar.new();avatar.initial_body=92;root.add_child(avatar);avatar.set_physics_process(false)
	var actors: Array=[];var assets: Dictionary={};var samples: Array=[];var pairs: Array=[];var maximum_floor:=0.;var maximum_joint_error:=0.;var maximum_segment_error:=0.;var maximum_source_gape:=0.;var maximum_basis_error:=0.
	for treatment in ["original","rounded","modern"]:
		var actor: Node3D=avatar.horse_visual if treatment=="modern" else Visual.new()
		if treatment!="modern":actor.entry=record;actor.treatment=treatment;root.add_child(actor)
		actor.set_process(false);actor.set_physics_process(false);actor.contact.enabled=false;actor.contact.active=false;actor.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		check(actor.skeleton.get_bone_count()==18,"All eighteen original rig joints retained")
		for clip: String in CATEGORIES:check(actor.animator.has_animation(clip),"Every source/feeding/rest category available");actor.animator.get_animation(clip).loop_mode=Animation.LOOP_NONE
		actors.append(actor);var path: String="res://local-art/creatures/"+str(record.kind)+"-"+str(treatment)+".gltf";assets[treatment]={"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")}
	check(avatar.horse_visual is Visual and avatar.horse_visual.native_body==92 and avatar.horse_visual.action_profile=="monster","Actual native92 avatar factory selects the owned original Silver presenter")
	for clip: String in CATEGORIES:
		for step in 37:
			var phase:=0. if step==0 else 1. if step==36 else (float(step)-.317)/36.;var reference: Array=[];var reference_basis: Array=[];var lengths: Dictionary={}
			for i in actors.size():
				var actor: Node3D=actors[i];pose(actor,clip,phase);var rig: Skeleton3D=actor.skeleton;var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0];var box:=Geometry.deformed_bounds(mesh,rig);var origin:=rig.get_bone_global_pose(0).origin;var joints: Array=[];var joint_error:=0.;var segment_error:=0.;var basis_error:=0.
				for bone in rig.get_bone_count():joints.append(rig.get_bone_global_pose(bone).origin-origin)
				if i==0:
					reference=joints
					for bone in rig.get_bone_count():reference_basis.append(rig.get_bone_global_pose(bone).basis)
				else:
					pairs.append({"clip":clip,"phase":phase,"treatment":i})
					for bone in rig.get_bone_count():
						joint_error=maxf(joint_error,(joints[bone] as Vector3).distance_to(reference[bone]));var actual: Basis=rig.get_bone_global_pose(bone).basis;var expected: Basis=reference_basis[bone]
						basis_error=maxf(basis_error,maxf(actual.x.distance_to(expected.x),maxf(actual.y.distance_to(expected.y),actual.z.distance_to(expected.z))))
				for bone in rig.get_bone_count():
					var parent: int=rig.get_bone_parent(bone)
					if parent<0:continue
					var length:=rig.get_bone_global_pose(bone).origin.distance_to(rig.get_bone_global_pose(parent).origin)
					if i==0:lengths[bone]=length
					else:segment_error=maxf(segment_error,absf(length-float(lengths[bone])))
				maximum_floor=maxf(maximum_floor,absf(box.position.y));maximum_joint_error=maxf(maximum_joint_error,joint_error);maximum_segment_error=maxf(maximum_segment_error,segment_error);maximum_basis_error=maxf(maximum_basis_error,basis_error)
				check(box.position.is_finite() and box.size.is_finite(),"Complete actual imported skin finite")
				check(absf(box.position.y)<.008,"Independent off-grid source/rounded/modern floor remains within8mm")
				check(joint_error<.00001 and segment_error<.00001 and basis_error<.00001,"Refinement/material preserve same-phase source joints and animated segment lengths")
				check((actor.global_transform*(actor.get_meta("pick_bounds") as AABB)).grow(.001).encloses(box),"Weighted bounds contain every complete source/action skin")
				check(float(actor.get_meta("nameplate_height"))>box.end.y+.025,"Source action nameplate clears the complete skin")
				samples.append({"clip":clip,"phase":phase,"treatment":i,"floor_m":box.position.y,"joint_error_m":joint_error,"segment_error_m":segment_error,"basis_error":basis_error})
	var modern: Node3D=actors[2];var jaw: int=modern.skeleton.find_bone("bip01 ponytail1");pose(modern,"Idle",0.);var idle_jaw: Quaternion=modern.skeleton.get_bone_pose_rotation(jaw)
	for step in 101:pose(modern,"Attack",float(step)/100.);maximum_source_gape=maxf(maximum_source_gape,rad_to_deg(idle_jaw.angle_to(modern.skeleton.get_bone_pose_rotation(jaw))))
	check(maximum_source_gape>5. and maximum_source_gape<=180.,"Original source jaw motion retained without Ice-specific amplitude amendment")
	var timing: Array=[]
	for preceding_rate in [.25,1.,3.2]:
		for action in [4,10,11,17]:
			for repeat in 2:
				modern.dead=false;modern.action_remaining=0.;modern.animator.speed_scale=preceding_rate
				check(modern.receive_action({"protocol":"classic","action":action,"frames":5,"delay":0}),"Actual monster action API accepts source categories and repeated requests")
				var length: float=modern.animator.get_animation(modern.current_clip).length
				check(absf(modern.animator.current_animation_position)<.0001 and is_equal_approx(modern.animator.speed_scale,1.),"Native action restarts independently of prior cadence")
				modern.animator.advance(.4);check(absf(modern.animator.current_animation_position-length*.5)<.001,"Source track midpoint matches half of native800ms duration")
				timing.append({"preceding_rate":preceding_rate,"action":action,"clip":modern.current_clip,"length":length,"position":modern.animator.current_animation_position,"seconds":.8})
	for actor: Node3D in actors:
		if actor!=modern:actor.free()
	avatar.free();var runtime: Dictionary={}
	for name in ["SourceSilverSerpentActionTests.gd","SourceSilverSerpentVisual.gd","SourceSilverSerpentMaterial.gd","SourceSilverSerpentSurface.gdshader","SmallSnakeVisual.gd","SourceGroundLookup.gd","CreatureRegistry.gd","HumanAvatar.gd","CreatureVisual.gd","OstardVisual.gd","HumanActions.gd","SkinGeometry.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var output:="res://../outputs/creatures/silver_serpents";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output));FileAccess.open(output+"/actions.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"paired_poses":pairs,"native_timing":timing,"maximum_floor_error_m":maximum_floor,"maximum_joint_error_m":maximum_joint_error,"maximum_segment_error_m":maximum_segment_error,"maximum_basis_error":maximum_basis_error,"maximum_source_jaw_degrees":maximum_source_gape,"assets":assets,"runtime_sha256":runtime,"preparation_sha256":FileAccess.get_sha256(preparation),"ground_lookup_sha256":FileAccess.get_sha256(str(record.ground_lookup)),"scope":"Actual native92 factory and three original/refined/modern saved skins, eighteen same-phase joints/animated segment lengths, every source/feeding/rest category and classic action timing/restarts. Original jaw channels unamended. No real-server/arbitrary-terrain/full choreography/final art acceptance."}));print("SILVER ACTIONS: ",checks," / ",failures," failures / ",samples.size()," skins");quit(1 if failures else 0)
