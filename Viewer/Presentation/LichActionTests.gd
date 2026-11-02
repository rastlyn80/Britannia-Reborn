extends SceneTree
const Visual=preload("res://Presentation/LichVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const CATEGORIES=["Idle","Walk","Run","Attack","Attack2","Attack3","Hit","Death","Fidget","Cast","Pillage","LieDown"]
const FINGERS=["bip01 r finger0","bip01 r finger01","bip01 r finger1","bip01 r finger11"]
const HELD_ARM=["bip01 r forearm","bip01 r hand","cp_grasp_rhand"]
var checks:=0
var failures:=0
var samples: Array=[]
var pairs: Array=[]
var validated_models: Array=[]
func _initialize() -> void:
	create_timer(240.).timeout.connect(func():push_error("Lich action deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<16:push_error(label)
func pose(visual: Node3D,clip: String,phase: float) -> void:
	visual.dead=false;visual.action_remaining=0.;visual.play(clip,0.);visual.animator.seek(visual.animator.get_animation(clip).length*phase,true);visual.animator.advance(0.);visual.animator.pause();visual.skeleton.force_update_all_bone_transforms();visual.update_grip()
func run() -> void:
	var prep_path:="res://local-art/creatures/liches/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prep_path));var maximum_gap:=0.;var maximum_relative_error:=0.;var maximum_wrist_support_degrees:=0.;var maximum_hand_support_m:=0.;var cadavers: Array=[]
	for row: Dictionary in prep.models:
		var actors: Array=[];var asset_pins: Dictionary={};var reference_lengths: Dictionary={}
		for treatment in ["original","rounded","modern"]:
			var actor:=Visual.new();actor.entry=row;actor.treatment=treatment;root.add_child(actor);actor.set_process(false);actor.set_physics_process(false);actor.contact.enabled=false;actor.contact.active=false;actor.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;actors.append(actor);var path: String="res://local-art/creatures/"+str(row.kind)+"-"+treatment+".gltf";asset_pins[treatment]={"sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")}
			check(actor.skeleton.get_bone_count()==36,"Original source36joint hierarchy retained")
			for clip in CATEGORIES:check(actor.animator.has_animation(clip),"Every saved/source/authored and common rest category exists")
			pose(actor,"Idle",0.);var lengths: Dictionary={}
			for name in ["bip01 l calf","bip01 l foot","bip01 r calf","bip01 r foot","bip01 l forearm","bip01 l hand","bip01 r forearm","bip01 r hand"]:
				var bone:=actor.skeleton.find_bone(name);var parent: int=actor.skeleton.get_bone_parent(bone);lengths[name]=actor.skeleton.get_bone_global_pose(bone).origin.distance_to(actor.skeleton.get_bone_global_pose(parent).origin)
			reference_lengths[treatment]=lengths
			if treatment=="modern":
				check(actor.staff!=null and actor.finger_fit.chains.size()==2,"Actual original rigid staff and two measured source finger chains exist")
				for chain: Dictionary in actor.finger_fit.chains:check(float(chain.target_error)<.0005 and float(chain.tip_shaft_radius)<.025,"Measured source finger tips close around the actual staff axis")
		for clip: String in CATEGORIES:
			for sample in 21:
				var phase:=0. if sample==0 else 1. if sample==20 else (float(sample)-.371)/20.;var roots: Array=[];var source_poses: Array=[]
				for i in actors.size():
					var actor: Node3D=actors[i];pose(actor,clip,phase);var rig: Skeleton3D=actor.skeleton;var mesh: MeshInstance3D=actor.body_mesh;var box:=Geometry.deformed_bounds(mesh,rig);var gap:=box.position.y;maximum_gap=maxf(maximum_gap,absf(gap));var envelope: AABB=actor.get_meta("pick_bounds")
					check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.5,"Complete actual source/refined/modern skin finite")
					check(absf(gap)<.008,"Complete imported body remains within8mm of flat support: %s/%s/%s %f"%[row.kind,actor.treatment,clip,gap])
					check((actor.global_transform*envelope).grow(.001).encloses(box),"Conservative weighted bounds contain the actual skin")
					check(actor.position.is_zero_approx(),"Source actions do not move native actor coordinates")
					for name: String in reference_lengths[actor.treatment]:
						var bone:=rig.find_bone(name);var parent:=rig.get_bone_parent(bone);var length:=rig.get_bone_global_pose(bone).origin.distance_to(rig.get_bone_global_pose(parent).origin);check(absf(length-float(reference_lengths[actor.treatment][name]))<.00001,"Actual limb segment length preserved across every source/authored pose")
					var positions: Dictionary={};var origin:=rig.get_bone_global_pose(0).origin
					for bone in rig.get_bone_count():positions[rig.get_bone_name(bone)]=rig.get_bone_global_pose(bone).origin-origin
					source_poses.append(positions)
					var staff_gap:=0.
					if actor.staff!=null:
						for part: MeshInstance3D in actor.staff_meshes():staff_gap=minf(staff_gap,(part.global_transform*part.mesh.get_aabb()).position.y);check((actor.global_transform*envelope).grow(.001).encloses(part.global_transform*part.mesh.get_aabb()),"Animated source staff stays inside selection bounds")
						check(staff_gap>gap-.008,"Original staff stays above the sampled body support through gaits, actions and collapse")
						if clip not in ["Death","LieDown"]:check(actor.staff.global_position.distance_to(rig.to_global(rig.get_bone_global_pose(rig.find_bone("cp_grasp_rhand")).origin))<.0001,"Held staff follows the current actual source grasp position without a deferred attachment frame")
					samples.append({"kind":row.kind,"treatment":actor.treatment,"clip":clip,"phase":phase,"body_floor_m":gap,"staff_low_m":staff_gap})
				var error:=0.
				for name: String in source_poses[0]:
					if name in FINGERS or name in HELD_ARM:continue
					error=maxf(error,(source_poses[0][name] as Vector3).distance_to(source_poses[2][name]))
				maximum_relative_error=maxf(maximum_relative_error,error);check(error<.00001,"Refinement/material/grip preserve every unamended source-rig joint centre after common translation")
				var held: Skeleton3D=actors[2].skeleton;var reference: Skeleton3D=actors[1].skeleton;var wrist:=held.find_bone("bip01 r hand");maximum_wrist_support_degrees=maxf(maximum_wrist_support_degrees,rad_to_deg(held.get_bone_pose_rotation(wrist).angle_to(reference.get_bone_pose_rotation(wrist))));maximum_hand_support_m=maxf(maximum_hand_support_m,held.get_bone_global_pose(wrist).origin.distance_to(reference.get_bone_global_pose(wrist).origin))
				pairs.append({"kind":row.kind,"clip":clip,"phase":phase,"maximum_unamended_joint_error_m":error})
		var modern: Node3D=actors[2]
		for request in [{"protocol":"classic","action":12},{"protocol":"new","type":11},{"protocol":"new","type":14},{"protocol":"classic","action":14}]:
			modern.dead=false;modern.action_remaining=0.;check(modern.receive_action(request),"Actual candidate renderer consumes native casting/scavenging categories")
		pose(modern,"Death",1.);modern.set_meta("corpse_body",int(row.bodies[0].body));modern.set_meta("native_hue",0);modern.set_meta("death_clip","Death");var body_mesh: MeshInstance3D=modern.body_mesh;var body_box:=Geometry.deformed_bounds(body_mesh,modern.skeleton);var corpse:=Corpses.freeze(modern);check(corpse!=null,"Candidate body and original staff can freeze into a static cadaver")
		if corpse!=null:
			var box: AABB=corpse.get_meta("corpse_bounds");check(box.position.y==0. and corpse.find_children("*","Skeleton3D",true,false).is_empty(),"Frozen candidate corpse has no rig and rests on its complete lower surface");check(box.size.y<body_box.size.y+.1,"Original staff rests beside the corpse instead of remaining an upright spike");cadavers.append({"kind":row.kind,"body_low_m":body_box.position.y,"body_size":[body_box.size.x,body_box.size.y,body_box.size.z],"corpse_size":[box.size.x,box.size.y,box.size.z],"vertices":corpse.get_meta("vertices")});corpse.free()
		validated_models.append({"kind":row.kind,"assets":asset_pins,"staff_asset_sha256":FileAccess.get_sha256(str(row.staff_asset)),"staff_import_sha256":FileAccess.get_sha256(str(row.staff_asset)+".import")})
		for actor: Node3D in actors:actor.free()
	var runtime: Dictionary={}
	for name in ["LichActionTests.gd","LichVisual.gd","LichGrip.gd","LichMaterial.gd","LichSurface.gdshader","SmallSnakeVisual.gd","CreatureVisual.gd","MeasuredCreatureSupport.gd","SourceBipedSupport.gd","SourceMountContact.gd","SkinGeometry.gd","CorpseModels.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var report:={"checks":checks,"failures":failures,"samples":samples,"pairs":pairs,"models":validated_models,"candidate_cadavers":cadavers,"amended_joint_names":FINGERS+HELD_ARM,"maximum_body_floor_error_m":maximum_gap,"maximum_unamended_joint_error_m":maximum_relative_error,"maximum_wrist_support_rotation_degrees":maximum_wrist_support_degrees,"maximum_hand_support_source_m":maximum_hand_support_m,"preparation_sha256":FileAccess.get_sha256(prep_path),"runtime_sha256":runtime,"scope":"Actual directly instantiated imported source/refined/modern Lich candidates and source/authored categories, measured finger closure, unamended source joint centres/all measured limb lengths, weighted bounds, flat body/staff support and candidate static corpse. Right arm/grasp/fingers have declared held-prop amendments. No accepted registry/avatar route, native server, finite terrain, original full choreography or final art certification."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/liches"));FileAccess.open("res://../outputs/creatures/liches/actions.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("LICH ACTIONS: ",checks," / ",failures," failures / ",samples.size()," skins / ",pairs.size()," paired unamended joint poses");quit(1 if failures else 0)
