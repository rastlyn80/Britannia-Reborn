extends SceneTree
## Actual in-memory candidate avatar/actions/bounds/corpses. No native server/GPU.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Actions=preload("res://Presentation/HumanActions.gd")
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Ice Elemental runtime deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<16:push_error(label)
func run() -> void:
	Registry.load_index();var saved:=Registry.entries.duplicate(true)
	var accepted_path:="res://local-art/creatures/accepted-index.json";var accepted_pin:=FileAccess.get_sha256(accepted_path)
	var prep_path:="res://local-art/creatures/ice_elementals/candidate.json";var prep_pin:=FileAccess.get_sha256(prep_path)
	var ground_path:="res://local-art/creatures/elementals_ice_elemental-ground.json";var ground_pin:=FileAccess.get_sha256(ground_path)
	var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prep_path));Registry.entries[161]=prep.models[0]
	var runtime: Dictionary={}
	for name in ["IceElementalRuntimeTests.gd","SourceIceElementalVisual.gd","SourceIceElementalSupport.gd","SourceIceElementalMaterial.gd","SourceIceElementalSurface.gdshader","SourcePoseEntry.gd","SourceMageSupport.gd","MeasuredCreatureVisual.gd","MeasuredCreatureSupport.gd","SourceBipedVisual.gd","SourceBipedSupport.gd","CreatureVisual.gd","SourceMountContact.gd","SourceGroundLookup.gd","SkinGeometry.gd","HumanAvatar.gd","HumanActions.gd","CorpseModels.gd","MountVisual.gd","CreatureRegistry.gd","LegacyAvatar.gd","OstardVisual.gd","OstardSurface.gdshader","HumanHue.gd","AnimalPoseLibrary.gd","FootContact.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name);check(not str(runtime[name]).is_empty(),"Required runtime input exists:"+name)
	var assets: Dictionary={}
	for name: String in prep.assets_sha256:assets[name]=FileAccess.get_sha256("res://local-art/creatures/"+name);check(assets[name]==prep.assets_sha256[name],"Candidate artwork/curve is exactly staged")
	var hues_pin:=FileAccess.get_sha256("res://hues.local.json");var artwork_pin:=FileAccess.get_sha256("res://Network/Artwork.gd")
	var origin:=Vector3(3.25,.17,-4.5);var actor:=Avatar.new();actor.initial_body=161
	var plate:=Label3D.new();plate.name="Nameplate";plate.text="Ice Elemental";actor.add_child(plate)
	var picker:=StaticBody3D.new();picker.collision_layer=4;picker.collision_mask=0;picker.set_meta("server_mobile",true);var picker_shape:=CollisionShape3D.new();picker_shape.shape=BoxShape3D.new();picker.add_child(picker_shape);actor.add_child(picker)
	root.add_child(actor);actor.position=origin;actor.set_process(false);actor.set_physics_process(false)
	var entity:={"serial":7000161,"body":161,"hue":0,"direction":5,"x":1100,"y":1700,"z":0,"flags":0,"name":"Ice Elemental"}
	actor.apply_server_appearance(entity,[])
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.active=false;visual.contact.enabled=false;visual.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	check(actor.human_visual==null and visual.get_script()==preload("res://Presentation/SourceIceElementalVisual.gd") and actor.native_body==161,"Actual avatar preserves161 and selects only the injected original Ice Elemental renderer")
	check(int(actor.server_appearance.body)==161 and int(actor.server_appearance.skin_hue)==0 and actor.server_appearance.native_mobile==entity and actor.server_appearance.equipment.is_empty(),"Appearance retains authoritative native body/hue/equipment")
	var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
	var raw: Node3D=load("res://local-art/creatures/elementals_ice_elemental-modern.gltf").instantiate();root.add_child(raw)
	var raw_player: AnimationPlayer=raw.find_children("*","AnimationPlayer",true,false)[0];var raw_rig: Skeleton3D=raw.find_children("*","Skeleton3D",true,false)[0];raw_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;raw_player.deterministic=true
	var requests: Array=[];var native_categories:={0:"Walk",1:"Idle",2:"Death",3:"Death2",4:"Attack",5:"Attack2",6:"Attack3",10:"Hit",11:"Pillage",12:"Cast2",13:"Hit",14:"Cast2",15:"Hit",16:"Hit",17:"Fidget",18:"Fidget",21:"Death"}
	for group: int in native_categories:requests.append({"protocol":"classic","body":161,"action":group,"frames":7,"delay":2,"repeat_count":1,"repeat":false,"reverse":false})
	for group: int in [0,1,2,3,4,5,11,14]:requests.append({"protocol":"new","body":161,"type":group,"subaction":0,"variation":0})
	var records: Array=[];var maximum_floor:=0.;var maximum_joint:=0.;var poses:=0
	for request: Dictionary in requests:
		for prior_rate: float in [.65,1.,1.65]:
			visual.dead=false;visual.action_remaining=0.;visual.animator.stop();visual.play("Run",0.);visual.animator.speed_scale=prior_rate;visual.animator.advance(.127)
			check(actor.receive_native_action(request),"Actual avatar dispatches the supported native-format Ice Elemental group")
			var expected: String=native_categories[int(request.action)] if request.protocol=="classic" else {0:"Attack",1:"Hit",2:"Hit",3:"Death",4:"Hit",5:"Fidget",11:"Cast2",14:"Pillage"}[int(request.type)]
			check(visual.current_clip==expected and visual.get_meta("native_action")==request,"Exact category and raw request retained without changing server identity")
			var length: float=visual.animator.get_animation(expected).length;var duration:=Actions.duration(request,length)
			check(is_equal_approx(visual.action_remaining,duration) and is_equal_approx(visual.animator.speed_scale,1.),"Native action duration is independent of prior gait speed")
			visual.animator.advance(duration*.5)
			check(absf(visual.animator.current_animation_position-length*.5)<.001,"Actual timed action reaches its source midpoint regardless of preceding gait speed")
			# Compare settled source poses separately from the real crossfade;
			# timed mixed-pose/terrain behaviour has its own independent gate.
			visual.play(expected,0.)
			for phase: float in [.073,.291,.573,.871,1.]:
				visual.animator.seek(length*phase,true);visual.animator.advance(0.);visual.skeleton.force_update_all_bone_transforms()
				raw_player.play(expected,0.);raw_player.seek(visual.animator.current_animation_position,true);raw_player.advance(0.);raw_player.pause();raw_rig.force_update_all_bone_transforms()
				var error:=0.
				for bone in visual.skeleton.get_bone_count():
					var a: Transform3D=visual.skeleton.get_bone_pose(bone);var b:=raw_rig.get_bone_pose(bone)
					error=maxf(error,a.origin.distance_to(b.origin));check(a.basis.is_equal_approx(b.basis),"Measured model support leaves every source joint basis intact")
				var bounds:=Geometry.deformed_bounds(mesh,visual.skeleton);var gap:=bounds.position.y-origin.y;maximum_floor=maxf(maximum_floor,absf(gap));maximum_joint=maxf(maximum_joint,error);poses+=1
				check(error<.00001,"Steady support preserves all source local bone positions")
				check(absf(gap)<.008,"Actual avatar complete skin remains within8mm of its flat native anchor")
				check((visual.global_transform*(visual.get_meta("pick_bounds") as AABB)).grow(.001).encloses(bounds),"Actual weighted picking bounds enclose the complete source skin")
				check(float(visual.get_meta("nameplate_height"))>visual.to_local(bounds.end).y-.001,"Actual nameplate remains above the source skin")
				var shape_box:=AABB(-(picker_shape.shape as BoxShape3D).size*.5,(picker_shape.shape as BoxShape3D).size)
				check((picker_shape.global_transform*shape_box).grow(.001).encloses(bounds),"Actual avatar picking collider follows the complete final animated source skin")
				check(plate.global_position.y>bounds.end.y+.015,"Actual avatar label follows the final source pose")
				check(actor.position==origin and visual.position.is_zero_approx() and visual.model.position.x==0. and visual.model.position.z==0.,"Body support never changes native coordinates or horizontal source placement")
			await physics_frame;await physics_frame
			var target:=picker_shape.global_position
			var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target+Vector3.UP*4.,target-Vector3.UP*4.,4))
			check(hit.get("collider")==picker,"Real physics picking ray reaches the actual animated avatar collider")
			visual.dead=false
			check(actor.receive_native_action(request) and visual.animator.current_animation_position<.00001,"Repeated request restarts even a paused or repeated source category")
			records.append({"request":request.duplicate(true),"prior_rate":prior_rate,"clip":expected,"duration_s":duration})
	var gait_records: Array=[]
	for clip: String in ["Walk","Run"]:
		visual.dead=false;visual.action_remaining=0.;visual.play(clip,0.)
		for step in 17:
			var phase: float=(float(step)+.137)/17.
			visual.animator.seek(visual.animator.get_animation(clip).length*phase,true);visual.animator.advance(0.);visual.skeleton.force_update_all_bone_transforms()
			var bounds:=Geometry.deformed_bounds(mesh,visual.skeleton);var gap:=bounds.position.y-origin.y
			check(gap>-.008 and (clip=="Run" or absf(gap)<.008),"Actual candidate gait preserves positive Run rise and grounded Walk")
			gait_records.append({"clip":clip,"phase":phase,"floor_m":gap})
	var unsupported: Array=[]
	for group: int in [7,8,9,19,20]:
		visual.dead=false;visual.action_remaining=0.;visual.play("Idle",0.);var clip: String=visual.current_clip
		check(not actor.receive_native_action({"protocol":"classic","body":161,"action":group}) and visual.current_clip==clip,"Missing source categories remain explicit instead of fabricated animation coverage")
		unsupported.append(group)
	var catalogue:=Corpses.catalogue();var listed:=false
	for item: Dictionary in catalogue:
		if int(item.body)==161:listed=int(item.graphic)==0x2006 and int(item.amount)==161
	check(listed,"Native161 candidate automatically appears under static corpse graphic0x2006")
	var corpse_records: Array=[]
	for hue: int in [0,53,0x8035,0x453]:
		entity.hue=hue;actor.apply_server_appearance(entity,[])
		check(actor.native_body==161 and visual.native_hue==hue and visual.hue==hue,"Full/partial supplied hues and raw supplied colour retain raw flags")
		var live_material:=mesh.get_active_material(0) as ShaderMaterial
		check(live_material!=null and bool(live_material.get_shader_parameter("partial_hue"))==bool(hue&0x8000) and bool(live_material.get_shader_parameter("use_hue"))==(hue!=0),"Native hue flags reach the actual source material uniforms")
		var posed:=Corpses.posed(161,hue)
		check(posed!=null and posed.get_script()==preload("res://Presentation/SourceIceElementalVisual.gd"),"Static corpse uses the same original Ice Elemental renderer")
		if posed!=null:
			var corpse_mesh: MeshInstance3D=posed.model.find_children("*","MeshInstance3D",true,false)[0]
			var body_bounds:=Geometry.deformed_bounds(corpse_mesh,posed.skeleton)
			check(absf(body_bounds.position.y)<.008,"Final posed Ice Elemental body uses measured floor support")
			var frozen:=Corpses.freeze(posed)
			check(frozen!=null and int(frozen.get_meta("corpse_body"))==161 and int(frozen.get_meta("native_hue"))==hue and int(frozen.get_meta("graphic_id"))==0x2006,"Frozen native graphic0x2006 retains exact body and full hue flags")
			if frozen!=null:
				check(frozen.find_children("*","Skeleton3D",true,false).is_empty() and frozen.find_children("*","AnimationPlayer",true,false).is_empty(),"Static cadaver needs no animation or rig")
				corpse_records.append({"body":161,"hue":hue,"body_floor_m":body_bounds.position.y,"vertices":frozen.get_meta("vertices")});frozen.free()
			posed.free()
	raw.free();actor.free();Registry.entries=saved
	check(accepted_pin==FileAccess.get_sha256(accepted_path),"Prepared renderer tests leave the accepted registry untouched")
	check(prep_pin==FileAccess.get_sha256(prep_path) and ground_pin==FileAccess.get_sha256(ground_path),"Exact preparation and residual curves remain unchanged")
	check(hues_pin==FileAccess.get_sha256("res://hues.local.json") and artwork_pin==FileAccess.get_sha256("res://Network/Artwork.gd"),"Private source palette and palette loader unchanged during raw hue checks")
	for name: String in runtime:check(runtime[name]==FileAccess.get_sha256("res://Presentation/"+name),"Runtime source remains unchanged:"+name)
	var report:={"checks":checks,"failures":failures,"poses":poses,"gait_records":gait_records,"assets_sha256":assets,"requests":records,"unsupported_classic_groups":unsupported,"corpses":corpse_records,"maximum_floor_error_m":maximum_floor,"maximum_local_position_error_m":maximum_joint,"preparation_sha256":prep_pin,"ground_measurement_sha256":ground_pin,"hues_sha256":hues_pin,"artwork_script_sha256":artwork_pin,"runtime_sha256":runtime,"scope":"In-memory candidate registry only; actual avatar native-format category/timing/restart, complete CPU skins, source local poses, actual picking collider/rays and nameplate/native roots, raw hue/material uniform flags and final static corpses. No real server/native behaviours, GPU/material pixels, physical terrain/transition or family acceptance."}
	FileAccess.open("res://../work/creatures/ice-elemental/runtime-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("ICE161 RUNTIME: ",checks," checks / ",failures," failures / ",poses," poses");quit(1 if failures else 0)
