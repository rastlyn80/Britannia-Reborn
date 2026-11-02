extends SceneTree
## Actual imported original/refined/modern frogs; no acceptance or native claim.
const Visual=preload("res://Presentation/SourceFrogVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
const CATEGORIES=["Idle","Walk","Run","Attack","Attack2","Hit","Death","Death2","Fidget","Eat","Alert","LieDown"]
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(240.).timeout.connect(func():push_error("Source frog action deadline");quit(1));call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<20:push_error(message)
func pose(actor: Node3D,clip: String,phase: float) -> void:
	actor.dead=false;actor.action_remaining=0.;actor.play(clip,0.);actor.animator.seek(actor.animator.get_animation(clip).length*phase,true);actor.animator.advance(0.);actor.animator.pause();actor.skeleton.force_update_all_bone_transforms();actor.update_landmarks()
func run() -> void:
	var preparation:="res://local-art/creatures/frogs/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation));var reports: Array=[];var samples: Array=[];var paired: Array=[];var timing: Array=[];var maximum_error:=0.;var maximum_floor_error:=0.;var hit_holdouts: Array=[]
	for record: Dictionary in prep.models:
		var body:=int(record.bodies[0].body);var actors: Array=[];var pins: Dictionary={};var anchors: Dictionary={};var tongue_ranges: Dictionary={};var rises: Dictionary={}
		for treatment in ["original","rounded","modern"]:
			var actor:=Visual.new();actor.entry=record;actor.treatment=treatment;root.add_child(actor);actor.apply_identity(body,0);actor.set_process(false);actor.set_physics_process(false);actor.contact.enabled=false;actor.contact.active=false;actor.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			check(actor.skeleton.get_bone_count()==27 and actor.contact.feet.size()==4,"Each original frog bind rig retains27 joints and four real sole chains")
			check(not actor.hit_curves.is_empty(),"Small measured Hit correction attached; hopping clips remain unsampled")
			for clip: String in CATEGORIES:check(actor.animator.has_animation(clip),"Original/explicitly reused/authored frog categories exist");actor.animator.get_animation(clip).loop_mode=Animation.LOOP_NONE
			var path: String="res://local-art/creatures/"+str(record.kind)+"-"+treatment+".gltf";pins[treatment]={"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")};anchors[treatment]={"Walk":[INF,-INF],"Run":[INF,-INF]};tongue_ranges[treatment]={};rises[treatment]={"Walk":[INF,-INF],"Run":[INF,-INF]};actors.append(actor)
			if treatment=="modern":
				var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0];var data:=mesh.mesh.surface_get_arrays(0);var colours: PackedColorArray=data[Mesh.ARRAY_COLOR];var weights: PackedFloat32Array=data[Mesh.ARRAY_WEIGHTS];var binds: PackedInt32Array=data[Mesh.ARRAY_BONES];var marked:=0;var worst:=0.
				check(colours.size()==(data[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),"Modern material retains per-vertex semantic tongue scalar")
				for vertex in colours.size():
					var expected:=0.
					for slot in 4:
						var bind:=binds[vertex*4+slot];var bone:=mesh.skin.get_bind_bone(bind)
						if bone<0:bone=actor.skeleton.find_bone(mesh.skin.get_bind_name(bind))
						if actor.skeleton.get_bone_name(bone) in ["bip01 ponytail12","bip01 ponytail13"]:expected+=weights[vertex*4+slot]
					worst=maxf(worst,absf(colours[vertex].r-expected));if colours[vertex].r>.01:marked+=1
				check(worst<.005 and marked>0 and marked<colours.size(),"Imported tongue scalar matches actual terminal-chain skin weights without tinting the whole body")
		for clip: String in CATEGORIES:
			for step in 37:
				var phase:=0. if step==0 else 1. if step==36 else (float(step)-.371)/36.;var reference: Array=[]
				for i in actors.size():
					var actor: Node3D=actors[i];pose(actor,clip,phase);var rig: Skeleton3D=actor.skeleton;var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0];var box:=Geometry.deformed_bounds(mesh,rig);var origin:=rig.get_bone_global_pose(0).origin;var joints: Array=[];var error:=0.
					for bone in rig.get_bone_count():joints.append(rig.get_bone_global_pose(bone).origin-origin)
					if i==0:reference=joints
					else:
						for bone in joints.size():error=maxf(error,(joints[bone] as Vector3).distance_to(reference[bone]))
						maximum_error=maxf(maximum_error,error);check(error<.00001,"Refinement and surface preserve same-phase original relative joint centres")
					check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.05,"Complete original/refined frog skin is finite")
					check((actor.global_transform*(actor.get_meta("pick_bounds") as AABB)).grow(.001).encloses(box),"Dynamic weighted bounds retain extended tongue and all hopping poses")
					if clip in ["Walk","Run"]:
						check(box.position.y>-.008,"Whole-clip hop anchor remains nonpenetrating")
						var space: Node3D=actor.model.find_child("SourceSpace",true,false);var bounds: Array=anchors[actor.treatment][clip];bounds[0]=minf(float(bounds[0]),space.position.z);bounds[1]=maxf(float(bounds[1]),space.position.z);var rise: Array=rises[actor.treatment][clip];rise[0]=minf(float(rise[0]),box.position.y);rise[1]=maxf(float(rise[1]),box.position.y)
					else:maximum_floor_error=maxf(maximum_floor_error,absf(box.position.y));check(absf(box.position.y)<.008,"Coupled240Hz grounded frog actions stay within8mm")
					var head:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 head")).origin);var tip:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 ponytail13")).origin);var range: Array=tongue_ranges[actor.treatment].get(clip,[INF,-INF]);range[0]=minf(float(range[0]),head.distance_to(tip));range[1]=maxf(float(range[1]),head.distance_to(tip));tongue_ranges[actor.treatment][clip]=range
					check(actor.global_position.is_zero_approx(),"Visual source motion never changes authoritative actor coordinates")
					samples.append({"kind":record.kind,"body":body,"treatment":actor.treatment,"clip":clip,"phase":phase,"floor_m":box.position.y,"maximum_joint_error_m":error})
				paired.append({"kind":record.kind,"clip":clip,"phase":phase})
		for treatment: String in anchors:
			for clip: String in ["Walk","Run"]:var range: Array=anchors[treatment][clip];check(absf(float(range[1])-float(range[0]))<.000001,"Walking and running retain a fixed whole-clip anchor")
			check(float(rises[treatment].Run[1])-float(rises[treatment].Run[0])>.5,"Original frog Run retains its substantial source hop")
			for clip: String in ["Attack","Fidget","Eat"]:check(float(tongue_ranges[treatment][clip][1])>float(tongue_ranges[treatment].Idle[1])*5.,"Original attack/fidget and explicit feeding reuse retain tongue extension")
		for actor: Node3D in actors:
			var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0];var skin:=Ground.skin_points(mesh,actor.skeleton);var count:=ceili(actor.animator.get_animation("Hit").length*960.);var worst:=0.
			for step in count:
				var phase:=(float(step)+.371)/float(count);pose(actor,"Hit",phase);var gap:=Ground.minimum_plane_gap(skin,actor.skeleton,actor.skeleton.global_transform,Vector3.ZERO,Vector3.UP);worst=maxf(worst,absf(gap));check(absf(gap)<.008,"Off-grid complete Hit skin stays within unchanged8mm tolerance")
			hit_holdouts.append({"kind":record.kind,"treatment":actor.treatment,"poses":count,"maximum_floor_error_m":worst})
		var modern: Node3D=actors[2];var requests: Array=[{"action":5,"expected":"Attack"},{"action":6,"expected":"Attack2"},{"action":3,"expected":"Eat"},{"action":4,"expected":"Alert"},{"action":8,"expected":"Death"},{"action":12,"expected":"Death2"}] if body==81 else [{"action":4,"expected":"Attack"},{"action":5,"expected":"Attack2"},{"action":10,"expected":"Hit"},{"action":2,"expected":"Death"},{"action":3,"expected":"Death2"},{"action":17,"expected":"Fidget"}]
		for rate in [.25,1.,3.2]:
			for specification: Dictionary in requests:
				var request:={"protocol":"classic","action":int(specification.action),"frames":5,"delay":0};modern.dead=false;modern.animator.speed_scale=rate;check(modern.receive_action(request) and modern.current_clip==specification.expected,"Animal81/monster80 consume their actual distinct native action groups")
				var length: float=modern.animator.current_animation_length;modern.animator.advance(.4);check(absf(modern.animator.current_animation_position-length*.5)<.001,"Native action duration is independent of previous gait rate")
				modern.dead=false;check(modern.receive_action(request),"Repeated native action consumed");modern.animator.advance(.4);check(absf(modern.animator.current_animation_position-length*.5)<.001,"Repeated native action restarts at its own first frame");timing.append({"body":body,"preceding_rate":rate,"clip":modern.current_clip,"position":modern.animator.current_animation_position,"length":length,"seconds":.8})
		pose(modern,"Death",1.);modern.set_meta("corpse_body",body);modern.set_meta("native_hue",0);modern.set_meta("death_clip","Death");var corpse:=Corpses.freeze(modern);check(corpse!=null,"Both original frog bodies produce a static corpse")
		if corpse!=null:check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and (corpse.get_meta("corpse_bounds") as AABB).position.y==0.,"Cadaver retains static final skin and rests on its lower surface");corpse.free()
		reports.append({"kind":record.kind,"body":body,"assets":pins,"anchors":anchors,"tongue_ranges":tongue_ranges,"source_vertical_ranges":rises,"ground_lookup_sha256":FileAccess.get_sha256(str(record.ground_lookup))})
		for actor: Node3D in actors:actor.free()
	var runtime: Dictionary={}
	for name in ["SourceFrogActionTests.gd","SourceFrogVisual.gd","SourceFrogMaterial.gd","SourceFrogSurface.gdshader","SourcePlaneSoleSupport.gd","SourceGroundLookup.gd","MeasuredCreatureVisual.gd","MeasuredCreatureSupport.gd","SourceBipedVisual.gd","SourceBipedSupport.gd","CreatureVisual.gd","SourceMountContact.gd","FootContact.gd","OstardVisual.gd","AnimalPoseLibrary.gd","SkinGeometry.gd","HumanActions.gd","CorpseModels.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/frogs"));FileAccess.open("res://../outputs/creatures/frogs/actions.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"models":reports,"hit_holdouts":hit_holdouts,"samples":samples,"paired_poses":paired,"native_timing":timing,"maximum_relative_joint_error_m":maximum_error,"maximum_grounded_floor_error_m":maximum_floor_error,"runtime_sha256":runtime,"preparation_sha256":FileAccess.get_sha256(preparation),"scope":"Actual two original frog meshes/distinct27joint rigs/scales/UVs and seven original motions, three explicit category reuses/authored Alert, positive Walk/Run trajectories and tongue bounds. Direct renderer offline skins/timing/static cadavers, not accepted routes, real native gameplay, arbitrary terrain or final art certification."}));print("SOURCE FROG ACTIONS: ",checks," / ",failures," failures / ",samples.size()," skins / relative joint error ",maximum_error," / grounded error ",maximum_floor_error);quit(1 if failures else 0)
