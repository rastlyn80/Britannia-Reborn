extends SceneTree
const Visual=preload("res://Presentation/SourceElementalVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const CATEGORIES=["Idle","Walk","Run","Attack","Attack2","Attack3","Hit","Death","Death2","Fidget","Cast2","Stomp","Pillage","LieDown"]
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Original elemental action deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<20:push_error(label)
func pose(actor: Node3D,clip: String,phase: float) -> void:
	actor.dead=false;actor.action_remaining=0.;actor.play(clip,0.);actor.animator.seek(actor.animator.get_animation(clip).length*phase,true);actor.animator.advance(0.);actor.animator.pause();actor.skeleton.force_update_all_bone_transforms();actor.update_landmarks()
func run() -> void:
	var preparation:="res://local-art/creatures/snow_elementals/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation));var record: Dictionary=prep.models[0];var actors: Array=[];var pins: Dictionary={};var baseline_lengths: Array=[];var samples: Array=[];var pairs: Array=[];var maximum_floor_error:=0.;var maximum_joint_error:=0.;var maximum_run_rise:=0.;var run_anchor_range: Array=[];var source_segment_ranges: Dictionary={}
	for treatment in ["original","rounded","modern"]:
		var actor:=Visual.new();actor.entry=record;actor.treatment=treatment;root.add_child(actor);actor.set_process(false);actor.set_physics_process(false);actor.contact.enabled=false;actor.contact.active=false;actor.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip: String in CATEGORIES:
			check(actor.animator.has_animation(clip),"All12 original categories, explicit Pillage reuse and terminal rest exist")
			actor.animator.get_animation(clip).loop_mode=Animation.LOOP_NONE
		check(actor.skeleton.get_bone_count()==34 and actor.contact.feet.size()==2,"All34 source joints and actual two-foot sole chains retained")
		pose(actor,"Idle",0.);var lengths: Dictionary={}
		for bone in actor.skeleton.get_bone_count():
			var parent: int=actor.skeleton.get_bone_parent(bone)
			if parent>=0:lengths[bone]=actor.skeleton.get_bone_global_pose(bone).origin.distance_to(actor.skeleton.get_bone_global_pose(parent).origin)
		baseline_lengths.append(lengths);actors.append(actor);var path: String="res://local-art/creatures/"+str(record.kind)+"-"+treatment+".gltf";pins[treatment]={"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")};run_anchor_range.append([INF,-INF])
	for clip: String in CATEGORIES:
		for step in 37:
			var phase:=0. if step==0 else 1. if step==36 else (float(step)-.371)/36.;var reference: Array=[];var source_low:=0.;var phase_lengths: Dictionary={}
			for i in actors.size():
				var actor: Node3D=actors[i];pose(actor,clip,phase);var rig: Skeleton3D=actor.skeleton;var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0];var box:=Geometry.deformed_bounds(mesh,rig);var origin:=rig.get_bone_global_pose(0).origin;var relative: Array=[];var error:=0.
				for bone in rig.get_bone_count():relative.append(rig.get_bone_global_pose(bone).origin-origin)
				if i==0:reference=relative;source_low=box.position.y
				else:
					for bone in rig.get_bone_count():error=maxf(error,(relative[bone] as Vector3).distance_to(reference[bone]))
				maximum_joint_error=maxf(maximum_joint_error,error)
				check(error<.00001,"Refinement/surface preserve every original relative source joint centre")
				check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.5,"Complete imported actual skin finite")
				check((actor.global_transform*(actor.get_meta("pick_bounds") as AABB)).grow(.001).encloses(box),"Weighted dynamic bounds contain complete imported skin")
				if clip=="Run":
					maximum_run_rise=maxf(maximum_run_rise,box.position.y);check(box.position.y>-.008 and absf(box.position.y-source_low)<.006,"Retained source run rise, not per-frame grounding")
					var space: Node3D=actor.model.find_child("SourceSpace",true,false);check(space!=null,"Original source-space parent retained")
					if space!=null:run_anchor_range[i][0]=minf(float(run_anchor_range[i][0]),space.position.z);run_anchor_range[i][1]=maxf(float(run_anchor_range[i][1]),space.position.z)
				else:maximum_floor_error=maxf(maximum_floor_error,absf(box.position.y));check(absf(box.position.y)<.008,"Coupled240Hz imported grounded action remains within8mm")
				for bone: int in baseline_lengths[i]:
					var parent:=rig.get_bone_parent(bone);var length:=rig.get_bone_global_pose(bone).origin.distance_to(rig.get_bone_global_pose(parent).origin)
					if i==0:
						phase_lengths[bone]=length;var name:=rig.get_bone_name(bone)
						if not source_segment_ranges.has(name):source_segment_ranges[name]=[length,length]
						source_segment_ranges[name][0]=minf(float(source_segment_ranges[name][0]),length);source_segment_ranges[name][1]=maxf(float(source_segment_ranges[name][1]),length)
					check(absf(length-float(phase_lengths[bone]))<.00002,"Every modern skeletal segment retains its actual same-phase original source length, including animated source translations")
				check(actor.position.is_zero_approx(),"Source action never moves authoritative native entity coordinates")
				samples.append({"clip":clip,"phase":phase,"treatment":actor.treatment,"floor_m":box.position.y,"source_floor_m":source_low,"maximum_joint_error_m":error})
			pairs.append({"clip":clip,"phase":phase})
	check(maximum_run_rise>.15,"Actual imported original Run retains more than15cm of vertical rise")
	for bounds: Array in run_anchor_range:check(absf(float(bounds[1])-float(bounds[0]))<.000001,"Run uses one fixed per-clip source floor anchor")
	var modern: Node3D=actors[2];var timing: Array=[]
	for rate in [.25,1.,3.2]:
		for request in [{"protocol":"classic","action":12,"frames":5,"delay":0},{"protocol":"classic","action":14,"frames":5,"delay":0},{"protocol":"new","type":11},{"protocol":"new","type":14}]:
			modern.dead=false;modern.action_remaining=0.;modern.animator.speed_scale=rate;check(modern.receive_action(request),"Actual original caster/ground-slap native category consumed");var clip: String=modern.current_clip;check(clip==("Pillage" if int(request.get("type",-1))==14 else "Cast2"),"Native casting selects recovered Cast2; scavenging is explicit Stomp reuse");var length: float=modern.animator.get_animation(clip).length;var seconds: float=preload("res://Presentation/HumanActions.gd").duration(request,length);modern.animator.advance(seconds*.5);check(absf(modern.animator.current_animation_position-length*.5)<.001,"Requested native duration independent of preceding gait rate");timing.append({"preceding_rate":rate,"clip":clip,"position":modern.animator.current_animation_position,"length":length,"seconds":seconds})
	pose(modern,"Death",1.);modern.set_meta("corpse_body",163);modern.set_meta("native_hue",0);modern.set_meta("death_clip","Death");var corpse:=Corpses.freeze(modern);check(corpse!=null,"Original source Snow body freezes into a static corpse")
	if corpse!=null:
		var bounds: AABB=corpse.get_meta("corpse_bounds");check(bounds.position.y==0. and bounds.size.y<1.2 and corpse.find_children("*","Skeleton3D",true,false).is_empty(),"Static source collapse has no rig and rests on its lower skin");corpse.free()
	for actor: Node3D in actors:actor.free()
	var runtime: Dictionary={}
	for name in ["SourceElementalActionTests.gd","SourceElementalVisual.gd","SourceElementalMaterial.gd","SourceElementalSurface.gdshader","SourceGroundLookup.gd","SourcePlaneSoleSupport.gd","MeasuredCreatureVisual.gd","MeasuredCreatureSupport.gd","SourceBipedVisual.gd","SourceBipedSupport.gd","CreatureVisual.gd","SourceMountContact.gd","OstardVisual.gd","AnimalPoseLibrary.gd","SkinGeometry.gd","CorpseModels.gd","HumanActions.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var report:={"checks":checks,"failures":failures,"samples":samples,"paired_poses":pairs,"assets":pins,"source_segment_ranges":source_segment_ranges,"maximum_grounded_floor_error_m":maximum_floor_error,"maximum_relative_joint_error_m":maximum_joint_error,"maximum_run_rise_m":maximum_run_rise,"run_anchor_ranges":run_anchor_range,"native_timing":timing,"preparation_sha256":FileAccess.get_sha256(preparation),"runtime_sha256":runtime,"scope":"Actual directly instantiated original/refined/modern source Snow skins,34source joints/same-phase segment lengths including animated source translations,12source motions plus explicit Pillage reuse, Run vertical trajectory/constant anchor, native action timing/restarts, weighted bounds and static corpse. No accepted route, real server, arbitrary terrain/full original choreography/physical no-slip/final art certification."};DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/snow_elementals"));FileAccess.open("res://../outputs/creatures/snow_elementals/actions.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("SOURCE SNOW ACTIONS: ",checks," / ",failures," failures / ",samples.size()," skins / run rise ",maximum_run_rise,"m");quit(1 if failures else 0)
