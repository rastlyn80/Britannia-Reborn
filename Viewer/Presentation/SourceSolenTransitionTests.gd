extends SceneTree
## Actual imported mixed skins and actual picking on flat/sloped finite colliders.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
const Visual=preload("res://Presentation/SourceSolenVisual.gd")
var kind:="fire_ant_worker"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):kind=arg.trim_prefix("--kind=")
	create_timer(300.).timeout.connect(func():push_error("Source solen_workers mixed-skin deadline");quit(1));call_deferred("run")
func run() -> void:
	var preparation:="res://local-art/creatures/solen_workers/preparation.json";var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation)).models.filter(func(r: Dictionary):return r.kind==kind)[0];var body:=int(record.bodies[0].body);Registry.load_index();Registry.entries[body]=record
	var viewport:=SubViewport.new();viewport.size=Vector2i(640,480);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);var camera:=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(3,2,5);camera.look_at(Vector3(0,1,0))
	var actor:=Avatar.new();actor.initial_body=body;var picker:=StaticBody3D.new();picker.set_meta("server_mobile",body);picker.collision_layer=2;var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();picker.add_child(shape);actor.add_child(picker);viewport.add_child(actor);actor.apply_server_appearance({"body":body,"hue":0},[]);var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0];var skin:=Ground.skin_points(mesh,rig);var modified: Dictionary={"serial":0};var plane: Dictionary={"origin":Vector3.ZERO,"normal":Vector3.UP}
	var reference:=Visual.new();reference.entry=record;reference.treatment="original";viewport.add_child(reference);reference.visible=false;reference.set_process(false);reference.set_physics_process(false);reference.contact.active=false;reference.contact.enabled=false;reference.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;var reference_mesh: MeshInstance3D=reference.model.find_children("*","MeshInstance3D",true,false)[0];var reference_skin:=Ground.skin_points(reference_mesh,reference.skeleton)
	visual.contact.modification_processed.connect(func():
		var protected: Dictionary={}
		for bone in rig.get_bone_count():
			if not rig.get_bone_name(bone).begins_with("legbone "):protected[bone]=rig.get_bone_global_pose(bone).origin
		modified["protected"]=protected;modified["box"]=Geometry.deformed_bounds(mesh,rig);modified["gap"]=Ground.minimum_plane_gap(skin,rig,rig.global_transform,plane.origin,plane.normal);modified["serial"]=int(modified.serial)+1)
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var slab:=BoxShape3D.new();slab.size=Vector3(12,.1,12);collider.shape=slab;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground);var samples: Array=[];var checks:=0;var failures:=0;var minimum_gap:=INF;var maximum_gap:=-INF;var grounded_gait_cases:=0
	for slope in [0.,.08]:
		ground.rotation.x=slope
		for pair in [["Idle","Walk"],["Walk","Run"],["Run","Walk"],["Run","Attack"],["Run","Attack2"],["Run","Hit"],["Run","Fidget2"],["Run","Death"]]:
			visual.dead=false;visual.action_remaining=1000.;visual.contact.enabled=true;visual.current_clip=pair[0];visual.animator.speed_scale=1.;visual.play(pair[0],0.);visual.animator.seek(visual.animator.get_animation(pair[0]).length*.73,true);visual.animator.advance(0.);visual.animator.pause()
			reference.dead=false;reference.action_remaining=1000.;reference.current_clip=pair[0];reference.animator.speed_scale=1.;reference.play(pair[0],0.);reference.animator.seek(reference.animator.get_animation(pair[0]).length*.73,true);reference.animator.advance(0.);reference.animator.pause()
			for i in 30:await physics_frame;actor.animate(false,0.,1./60.,0.);await process_frame
			var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,2,0),Vector3(0,-2,0),1));assert(not hit.is_empty());plane.origin=hit.position;plane.normal=hit.normal
			if pair[1] in ["Attack","Attack2","Hit","Fidget2","Death"]:visual.receive_action({"protocol":"classic","action":{"Attack":4,"Attack2":5,"Hit":10,"Fidget2":18,"Death":2}[pair[1]],"frames":5,"delay":0})
			else:visual.current_clip=pair[1];visual.action_remaining=1000.;visual.play(pair[1],.18)
			reference.global_transform=visual.global_transform;reference.model.basis=visual.model.basis.orthonormalized().scaled_local(reference.default_model_scale)
			if pair[1] in ["Attack","Attack2","Hit","Fidget2","Death"]:reference.receive_action({"protocol":"classic","action":{"Attack":4,"Attack2":5,"Hit":10,"Fidget2":18,"Death":2}[pair[1]],"frames":5,"delay":0})
			else:reference.current_clip=pair[1];reference.action_remaining=1000.;reference.play(pair[1],.18)
			for step in 18:
				var serial:=int(modified.serial);visual.animator.advance(1./60.);visual._process(1./60.);reference.animator.advance(1./60.);reference._process(1./60.);await physics_frame;actor.animate(false,0.,1./60.,0.);await process_frame;await RenderingServer.frame_post_draw
				reference.global_transform=visual.global_transform;reference.model.basis=visual.model.basis.orthonormalized().scaled_local(reference.default_model_scale);reference.skeleton.force_update_all_bone_transforms();var source_gap:=Ground.minimum_plane_gap(reference_skin,reference.skeleton,reference.skeleton.global_transform,plane.origin,plane.normal);var joint_error:=0.;var primary:=rig.get_bone_global_pose(0).origin;var source_primary:=reference.skeleton.get_bone_global_pose(0).origin
				for bone: int in modified.protected:joint_error=maxf(joint_error,(modified.protected[bone] as Vector3).distance_to(reference.skeleton.get_bone_global_pose(bone).origin))
				var box: AABB=modified.box;var low:=float(modified.gap);var contained: bool=(shape.global_transform*AABB(-shape.shape.size*.5,shape.shape.size)).grow(.001).encloses(box);var fresh: bool=int(modified.serial)>serial;minimum_gap=minf(minimum_gap,low);maximum_gap=maxf(maximum_gap,low)
				if pair[1] in ["Walk","Run"] and absf(low)<.008:grounded_gait_cases+=1
				for ok in [fresh,box.position.is_finite() and box.size.is_finite(),low>-.008,low<.35,contained,actor.global_position.is_zero_approx(),joint_error<.00001]:
					checks+=1
					if not ok:failures+=1;if failures<15:push_error("Mixed source skin/picker/native coordinate failure: %s/%s frame%s slope%s gap%f picker%s"%[pair[0],pair[1],step,slope,low,contained])
				samples.append({"source":pair[0],"target":pair[1],"frame":step,"slope":slope,"gap_m":low,"original_gap_m":source_gap,"protected_source_joint_error_m":joint_error,"actual_picker_contains":contained,"fresh_modified_skin":fresh})
	checks+=1
	if grounded_gait_cases!=108:failures+=1;push_error("Mixed Solen gait must preserve grounded support")
	actor.free();reference.free();ground.free();var runtime: Dictionary={}
	for name in ["SourceSolenTransitionTests.gd","SourceSolenVisual.gd","SourceGroundLookup.gd","SourceSolenSupport.gd","MeasuredCreatureSupport.gd","CreatureRegistry.gd","CreatureVisual.gd","SmallSnakeVisual.gd","BirdGroundSupport.gd","SourceSolenMaterial.gd","SourceSolenSurface.gdshader","SourceMountContact.gd","FootContact.gd","OstardVisual.gd","HumanAvatar.gd","LegacyAvatar.gd","HumanActions.gd","SkinGeometry.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var asset:=Registry.asset_path(record);var report:={"checks":checks,"failures":failures,"kind":kind,"body":body,"samples":samples,"minimum_plane_gap_m":minimum_gap,"maximum_plane_gap_m":maximum_gap,"grounded_gait_cases":grounded_gait_cases,"renderer":RenderingServer.get_current_rendering_method(),"runtime_sha256":runtime,"preparation_sha256":FileAccess.get_sha256(preparation),"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import"),"scope":"Actual registered original solen_workers mixed render-stage skins and actual picker on two finite planes across eight real gait/action transitions, including native attack/hit/feeding/death packets and death-only negative support. Original source torso motion and six-leg terrain support retained; native coordinates untouched. Offline rendering, not real-server or arbitrary-terrain/all-phase transition certification."};FileAccess.open("res://../outputs/creatures/solen_workers/"+kind+"-transitions.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("SOURCE SOLEN TRANSITIONS: ",checks," / ",failures," failures / ",samples.size()," mixed skins / min gap ",minimum_gap);quit(1 if failures else 0)
