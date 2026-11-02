extends SceneTree
## Actual imported mixed skins and actual picking on flat/sloped finite colliders.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
var kind:="elementals_acid_elemental"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):kind=arg.trim_prefix("--kind=")
	create_timer(300.).timeout.connect(func():push_error("Source elemental mixed-skin deadline");quit(1));call_deferred("run")
func run() -> void:
	var preparation:="res://local-art/creatures/fluid_elementals/preparation.json";var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation)).models.filter(func(r: Dictionary):return r.kind==kind)[0];var body:=int(record.bodies[0].body);Registry.load_index();Registry.entries[body]=record
	var viewport:=SubViewport.new();viewport.size=Vector2i(640,480);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);var camera:=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(3,2,5);camera.look_at(Vector3(0,1,0))
	var actor:=Avatar.new();actor.initial_body=body;var picker:=StaticBody3D.new();picker.set_meta("server_mobile",body);picker.collision_layer=2;var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();picker.add_child(shape);actor.add_child(picker);viewport.add_child(actor);actor.apply_server_appearance({"body":body,"hue":0},[]);var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0];var skin:=Ground.skin_points(mesh,rig);var modified: Dictionary={"serial":0};var plane: Dictionary={"origin":Vector3.ZERO,"normal":Vector3.UP}
	visual.contact.modification_processed.connect(func():modified["box"]=Geometry.deformed_bounds(mesh,rig);modified["gap"]=Ground.minimum_plane_gap(skin,rig,rig.global_transform,plane.origin,plane.normal);modified["serial"]=int(modified.serial)+1)
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var slab:=BoxShape3D.new();slab.size=Vector3(12,.1,12);collider.shape=slab;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground);var samples: Array=[];var checks:=0;var failures:=0;var minimum_gap:=INF;var maximum_gap:=-INF;var raised:=0
	for slope in [0.,.08]:
		ground.rotation.x=slope
		for pair in [["Idle","Walk"],["Walk","Run"],["Run","Walk"],["Run","Attack"],["Run","Cast2"],["Run","Death"]]:
			visual.dead=false;visual.action_remaining=1000.;visual.contact.enabled=true;visual.current_clip=pair[0];visual.animator.speed_scale=1.;visual.play(pair[0],0.);visual.animator.seek(visual.animator.get_animation(pair[0]).length*.73,true);visual.animator.advance(0.);visual.animator.pause()
			for i in 30:await physics_frame;actor.animate(false,0.,1./60.,0.);await process_frame
			var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,2,0),Vector3(0,-2,0),1));assert(not hit.is_empty());plane.origin=hit.position;plane.normal=hit.normal
			if pair[1] in ["Attack","Cast2","Death"]:visual.receive_action({"protocol":"classic","action":{"Attack":4,"Cast2":12,"Death":2}[pair[1]],"frames":5,"delay":0})
			else:visual.current_clip=pair[1];visual.action_remaining=1000.;visual.play(pair[1],.18)
			for step in 18:
				var serial:=int(modified.serial);visual.animator.advance(1./60.);visual._process(1./60.);await physics_frame;actor.animate(false,0.,1./60.,0.);await process_frame;await RenderingServer.frame_post_draw
				var box: AABB=modified.box;var low:=float(modified.gap);var contained: bool=(shape.global_transform*AABB(-shape.shape.size*.5,shape.shape.size)).grow(.001).encloses(box);var fresh: bool=int(modified.serial)>serial;minimum_gap=minf(minimum_gap,low);maximum_gap=maxf(maximum_gap,low)
				if low>.03:raised+=1
				for ok in [fresh,box.position.is_finite() and box.size.is_finite(),low>-.008,low<.35,contained,actor.global_position.is_zero_approx()]:
					checks+=1
					if not ok:failures+=1;if failures<15:push_error("Mixed source skin/picker/native coordinate failure: %s/%s frame%s slope%s gap%f picker%s"%[pair[0],pair[1],step,slope,low,contained])
				samples.append({"source":pair[0],"target":pair[1],"frame":step,"slope":slope,"gap_m":low,"actual_picker_contains":contained,"fresh_modified_skin":fresh})
	checks+=1
	if raised<20:failures+=1;push_error("Mixed gait clips lost positive source rise")
	actor.free();ground.free();var runtime: Dictionary={}
	for name in ["SourceFluidElementalTransitionTests.gd","SourceElementalVisual.gd","SourceFluidElementalVisual.gd","SourceFluidElementalMaterial.gd","SourceFluidElementalSurface.gdshader","SourceGroundLookup.gd","SourcePlaneSoleSupport.gd","CreatureRegistry.gd","CreatureVisual.gd","MeasuredCreatureVisual.gd","MeasuredCreatureSupport.gd","SourceBipedVisual.gd","SourceBipedSupport.gd","SourceMountContact.gd","FootContact.gd","OstardVisual.gd","HumanAvatar.gd","LegacyAvatar.gd","HumanActions.gd","SkinGeometry.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var asset:=Registry.asset_path(record);var report:={"kind":kind,"body":body,"checks":checks,"failures":failures,"samples":samples,"minimum_plane_gap_m":minimum_gap,"maximum_plane_gap_m":maximum_gap,"positive_rise_cases":raised,"renderer":RenderingServer.get_current_rendering_method(),"runtime_sha256":runtime,"preparation_sha256":FileAccess.get_sha256(preparation),"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import"),"scope":"Actual registered source Acid/Poison mixed render-stage skins and actual picker on two finite planes across six real gait/action transitions, including native attack/cast/death packets and death-only negative support. Positive source rise retained; native coordinates untouched. Offline rendering, not real-server or arbitrary-terrain/all-phase transition certification."};FileAccess.open("res://../outputs/creatures/fluid_elementals/"+kind+"-transitions.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("SOURCE FLUID TRANSITIONS: ",checks," / ",failures," failures / ",samples.size()," mixed skins / min gap ",minimum_gap);quit(1 if failures else 0)
