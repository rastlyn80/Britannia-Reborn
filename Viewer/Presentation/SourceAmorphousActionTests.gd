extends SceneTree
## Actual source motion/skin comparisons, retained bounce, static cadavers.
const Visual=preload("res://Presentation/SourceAmorphousVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const CATEGORIES=["Idle","Walk","Run","Attack","Attack2","Attack3","Hit","Death","Death2","Fidget","Eat","Pillage","LieDown"]
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(300.).timeout.connect(func():push_error("Source amorphous action deadline");quit(1));call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<20:push_error(message)
func pose(actor: Node3D,clip: String,phase: float) -> void:
	actor.dead=false;actor.action_remaining=0.;actor.play(clip,0.);actor.animator.seek(actor.animator.get_animation(clip).length*phase,true);actor.animator.advance(0.);actor.animator.pause();actor.skeleton.force_update_all_bone_transforms();actor.update_landmarks()
func run() -> void:
	var preparation:="res://local-art/creatures/amorphous/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation));var reports: Array=[];var samples: Array=[];var pairs: Array=[];var timing: Array=[];var maximum_error:=0.;var maximum_floor_error:=0.
	for record: Dictionary in prep.models:
		var body:=int(record.bodies[0].body);var actors: Array=[];var pins: Dictionary={};var anchors: Dictionary={};var ranges: Dictionary={}
		for treatment in ["original","rounded","modern"]:
			var actor:=Visual.new();actor.entry=record;actor.treatment=treatment;root.add_child(actor);actor.apply_identity(body,0);actor.set_process(false);actor.set_physics_process(false);actor.contact.enabled=false;actor.contact.active=false;actor.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			check(actor.skeleton.get_bone_count()==int(record.stats.original.bones) and actor.contact.feet.is_empty(),"Original nonstandard rigs retained; no ordinary foot IK invented")
			if record.has("pose_subdivision") and treatment!="original":
				var refined: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0];var data:=refined.mesh.surface_get_arrays(0)
				check(actor.model.has_meta("pose_subdivision") and int(actor.model.get_meta("pose_subdivision").triangles)==736,"Actual Slime mesh uses736 source-pose-preserving triangles")
				check((data[Mesh.ARRAY_BONES] as PackedInt32Array).size()==(data[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()*8,"Exact source skin contributions retain up to7 influences in8slots")
			for clip: String in CATEGORIES:check(actor.animator.has_animation(clip),"All original and explicit reused source categories exist");actor.animator.get_animation(clip).loop_mode=Animation.LOOP_NONE
			var path: String="res://local-art/creatures/"+str(record.kind)+"-"+treatment+".gltf";pins[treatment]={"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")};anchors[treatment]={"Walk":[INF,-INF],"Run":[INF,-INF]};ranges[treatment]={"Walk":[INF,-INF],"Run":[INF,-INF]};actors.append(actor)
		for clip: String in CATEGORIES:
			for step in 37:
				var phase:=0. if step==0 else 1. if step==36 else (float(step)-.371)/36.;var reference: Array=[]
				for i in actors.size():
					var actor: Node3D=actors[i];pose(actor,clip,phase);var rig: Skeleton3D=actor.skeleton;var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0];var box:=Geometry.deformed_bounds(mesh,rig);var origin:=rig.get_bone_global_pose(0).origin;var joints: Array=[];var error:=0.
					for bone in rig.get_bone_count():joints.append(rig.get_bone_global_pose(bone).origin-origin)
					if i==0:reference=joints
					else:
						for bone in joints.size():error=maxf(error,(joints[bone] as Vector3).distance_to(reference[bone]))
						maximum_error=maxf(maximum_error,error);check(error<.00001,"Refinement and surface preserve every same-phase source joint centre")
					check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.05,"Actual complete original/refined skin finite")
					check((actor.global_transform*(actor.get_meta("pick_bounds") as AABB)).grow(.001).encloses(box),"Weighted dynamic bounds contain every face/tendril/blob pose")
					if clip in ["Walk","Run"]:
						check(box.position.y>-.008,"Whole-clip gait anchor remains nonpenetrating")
						var space: Node3D=actor.model.find_child("SourceSpace",true,false);var anchor: Array=anchors[actor.treatment][clip];anchor[0]=minf(float(anchor[0]),space.position.z);anchor[1]=maxf(float(anchor[1]),space.position.z);var rise: Array=ranges[actor.treatment][clip];rise[0]=minf(float(rise[0]),box.position.y);rise[1]=maxf(float(rise[1]),box.position.y)
					else:maximum_floor_error=maxf(maximum_floor_error,absf(box.position.y));check(absf(box.position.y)<.008,"Grounded source actions stay within unchanged8mm tolerance")
					check(actor.global_position.is_zero_approx(),"Animation never changes authoritative native coordinates")
					samples.append({"kind":record.kind,"body":body,"treatment":actor.treatment,"clip":clip,"phase":phase,"floor_m":box.position.y,"maximum_joint_error_m":error})
				pairs.append({"kind":record.kind,"clip":clip,"phase":phase})
		for treatment: String in anchors:
			for clip: String in ["Walk","Run"]:var range: Array=anchors[treatment][clip];check(absf(float(range[1])-float(range[0]))<.000001,"Both source gaits retain one constant floor anchor")
			check(float(ranges[treatment].Run[1])-float(ranges[treatment].Run[0])>(.1 if body==775 else .2),"Actual original running bounce retained rather than flattened")
		var modern: Node3D=actors[2]
		for rate in [.25,1.,3.2]:
			for specification in [{"action":4,"expected":"Attack"},{"action":5,"expected":"Attack2"},{"action":6,"expected":"Attack3"},{"action":10,"expected":"Hit"},{"action":2,"expected":"Death"},{"action":3,"expected":"Death2"},{"action":11,"expected":"Pillage"},{"action":17,"expected":"Fidget"}]:
				var request:={"protocol":"classic","action":int(specification.action),"frames":5,"delay":0};modern.dead=false;modern.animator.speed_scale=rate;check(modern.receive_action(request) and modern.current_clip==specification.expected,"Actual monster action group selects original or explicit reuse")
				var length: float=modern.animator.current_animation_length;modern.animator.advance(.4);check(absf(modern.animator.current_animation_position-length*.5)<.001,"Native duration independent of preceding locomotion rate")
				modern.dead=false;check(modern.receive_action(request),"Repeated native source action consumed");modern.animator.advance(.4);check(absf(modern.animator.current_animation_position-length*.5)<.001,"Repeated native action restarts at its own beginning");timing.append({"body":body,"preceding_rate":rate,"clip":modern.current_clip,"position":modern.animator.current_animation_position,"length":length,"seconds":.8})
		pose(modern,"Death",1.);modern.set_meta("corpse_body",body);modern.set_meta("native_hue",0);modern.set_meta("death_clip","Death");var corpse:=Corpses.freeze(modern);check(corpse!=null,"Both source creatures have a static final-pose cadaver")
		if corpse!=null:check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and (corpse.get_meta("corpse_bounds") as AABB).position.y==0.,"Final source cadaver has no rig and rests on its lower skin");corpse.free()
		reports.append({"kind":record.kind,"body":body,"assets":pins,"anchors":anchors,"source_vertical_ranges":ranges})
		for actor: Node3D in actors:actor.free()
	var runtime: Dictionary={}
	for name in ["SourceAmorphousActionTests.gd","SourceAmorphousVisual.gd","SourceAmorphousMaterial.gd","SourceAmorphousSurface.gdshader","SmallSnakeVisual.gd","SourceGroundLookup.gd","SourcePoseSubdivision.gd","BirdGroundSupport.gd","CreatureVisual.gd","SourceMountContact.gd","FootContact.gd","OstardVisual.gd","AnimalPoseLibrary.gd","SkinGeometry.gd","HumanActions.gd","CorpseModels.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/amorphous"));FileAccess.open("res://../outputs/creatures/amorphous/actions.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"models":reports,"samples":samples,"paired_poses":pairs,"native_timing":timing,"maximum_relative_joint_error_m":maximum_error,"maximum_grounded_floor_error_m":maximum_floor_error,"runtime_sha256":runtime,"preparation_sha256":FileAccess.get_sha256(preparation),"scope":"Actual directly instantiated original/refined/modern PlagueBeast/Slime skins,56/29source joints,9/7source motions plus explicit reuses, retained source bounce/constant gait anchors, timing/repeated classic requests and static cadavers. Offline, not accepted routes, real native/owner lifecycle, arbitrary terrain/physical no-slip/final-art certification."}));print("SOURCE AMORPHOUS ACTIONS: ",checks," / ",failures," failures / ",samples.size()," skins / source joint error ",maximum_error," / grounded error ",maximum_floor_error);quit(1 if failures else 0)
