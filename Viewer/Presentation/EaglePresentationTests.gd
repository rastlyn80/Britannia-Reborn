extends SceneTree
## Actual avatar/materials, finite terrain, flight/action transitions and corpses.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Eagle=preload("res://Presentation/EagleVisual.gd")
const Support=preload("res://Presentation/BirdGroundSupport.gd")
const INPUTS=["EaglePresentationTests.gd","EagleVisual.gd","CreatureEagleMaterial.gd","CreatureEagleSurface.gdshader","BirdGroundSupport.gd","CreatureVisual.gd","SourceMountContact.gd","OstardVisual.gd","HumanAvatar.gd","LegacyAvatar.gd","CreatureRegistry.gd","MountVisual.gd","AnimalVisual.gd","HumanHue.gd","HumanActions.gd","AnimalPoseLibrary.gd","CorpseModels.gd","SkinGeometry.gd","ItemStudio.gd"]
var checks:=0
var failures:=0
var viewport: SubViewport
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<25:push_error(label)
func capture() -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw;return viewport.get_texture().get_image()
func wait_seconds(seconds: float) -> void:
	var until:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<until:await process_frame
func difference(a: Image,b: Image,threshold: float=.04) -> int:
	var count:=0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var d:=a.get_pixel(x,y)-b.get_pixel(x,y)
			if absf(d.r)+absf(d.g)+absf(d.b)>threshold:count+=1
	return count
func plane_gap(mesh: MeshInstance3D,rig: Skeleton3D,point: Vector3,normal: Vector3,claws_only: bool=false) -> float:
	var matrices: Array[Transform3D]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
		matrices.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var low:=INF
	for surface in mesh.mesh.get_surface_count():
		if claws_only and mesh.mesh.surface_get_material(surface).resource_name!="EagleClaws":continue
		var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var joints: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride:=joints.size()/vertices.size()
		for i in vertices.size():
			var p:=Vector3.ZERO
			for j in stride:p+=(matrices[joints[i*stride+j]]*vertices[i])*weights[i*stride+j]
			low=minf(low,normal.dot(rig.to_global(p)-point))
	return low
func run() -> void:
	Registry.load_index();var candidate:="res://local-art/eagle/candidate.json";var record: Dictionary
	if "--public" in OS.get_cmdline_user_args():record=Registry.entry(5);candidate="res://Art/Creatures/index.json"
	else:record=JSON.parse_string(FileAccess.get_file_as_string(candidate))
	Registry.entries[5]=record
	var output:="res://../outputs/creatures/eagle-trial";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=Vector2i(1000,750);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.1;camera.near=.001;viewport.add_child(camera);camera.position=Vector3(.9,.5,1.1);camera.look_at(Vector3(0.,.2,0.))
	var actor:=Avatar.new();actor.initial_body=5;actor.set_meta("own",true);var plate:=Node3D.new();plate.name="Nameplate";actor.add_child(plate)
	var picker:=StaticBody3D.new();picker.collision_layer=2;picker.set_meta("server_mobile",42);var pick_shape:=CollisionShape3D.new();pick_shape.shape=CapsuleShape3D.new();picker.add_child(pick_shape);actor.add_child(picker)
	viewport.add_child(actor);actor.apply_server_appearance({"body":5,"hue":0},[]);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false
	var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
	check(visual is Eagle and visual.native_body==5 and visual.action_profile=="animal","Body5 selects eagle presentation and actual Animal profile")
	check(visual.contact is Support and visual.contact.feet.is_empty(),"Ground support never treats source wings as invented stance limbs")
	visual.play("Idle",0.);visual.animator.seek(0.,true);visual.animator.pause();var base:=await capture();base.save_png(ProjectSettings.globalize_path(output+"/pbr-default.png"))
	var eyes:=0;var feathers: ShaderMaterial
	for i in mesh.mesh.get_surface_count():
		var source:=mesh.mesh.surface_get_material(i) as StandardMaterial3D;var active:=mesh.get_active_material(i)
		if source.resource_name.begins_with("EagleEye"):eyes+=1;check(active==source,"Fixed eye material survives avatar setup")
		else:
			check(active is ShaderMaterial and active.shader==preload("res://Presentation/CreatureEagleSurface.gdshader"),"Actual donor region receives matte eagle shader")
			if source.resource_name=="EagleWings":feathers=active
	check(eyes==3 and feathers!=null,"Fixed eyes and preserved brown-feather region present")
	if feathers!=null:
		feathers.set_shader_parameter("feather_detail",0.);var plain:=await capture();var detail_pixels:=difference(base,plain,.008)
		print("EAGLE FEATHER DETAIL pixels (RGB sum >0.008): ",detail_pixels);check(detail_pixels>100,"Subtle procedural feather detail changes visible pixels")
		feathers.set_shader_parameter("feather_detail",.7);feathers.set_shader_parameter("feather_roughness",.08);var glossy:=await capture();check(difference(base,glossy)>50,"Matte feather roughness changes actual lighting")
	actor.apply_server_appearance({"body":5,"hue":0},[]);var rig_id:=rig.get_instance_id();var hues: Array=[];var full:=0;var partial:=0
	for hue in [53,0x8035,0x901]:
		actor.apply_server_appearance({"body":5,"hue":hue},[]);var image:=await capture();var pixels:=difference(base,image)
		check(visual.native_hue==hue and rig.get_instance_id()==rig_id,"Raw hue retains its bits and animated rig")
		check(pixels>100,"Native eagle dye changes rendered skin")
		for i in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if source.resource_name.begins_with("EagleEye"):check(mesh.get_active_material(i)==source,"Full and partial dye preserve fixed eyes")
		if hue==53:full=pixels
		if hue==0x8035:partial=pixels
		hues.append({"hue":hue,"pixels":pixels});image.save_png(ProjectSettings.globalize_path(output+"/hue-%04x.png"%hue))
	check(partial<full-100,"Partial dye protects white head/tail and yellow beak/feet")
	actor.apply_server_appearance({"body":5,"hue":0},[])
	check(pick_shape.shape is BoxShape3D and pick_shape.shape.size.x<2.1 and pick_shape.shape.size.y<1.5,"Measured selection includes flight span without human/mount defaults")
	check(is_equal_approx(float(actor.get_meta("camera_height")),.5),"Eagle camera scale is explicit")
	# Movement must play take-off, continue looping full-span flight, then land.
	visual.set_process(true);visual.contact.enabled=false;visual.action_remaining=0.;actor.animate(true,0.,1./60.,1.8)
	check(visual.current_clip=="TakeOff" and visual.animator.assigned_animation=="TakeOff","Actual avatar starts its authored take-off")
	await wait_seconds(.85)
	check(visual.current_clip=="Run" and visual.flight_state=="air" and visual.animator.is_playing(),"Take-off finishes into looping flight")
	check(visual.animator.get_animation("Run").loop_mode==Animation.LOOP_LINEAR,"Donor flight closing interval loops")
	actor.animate(true,0.,1./60.,6.8);check(visual.current_clip=="Run" and visual.animator.speed_scale>1.,"Native running retains flight with a bounded faster stroke")
	for action in [7,5,6]:
		visual.action_remaining=0.;visual.flight_state="air";check(visual.receive_action({"protocol":"classic","action":action}),"Native airborne action accepted")
		var expected: String={7:"AirHit",5:"AirAttack",6:"AirAttack2"}[action]
		check(visual.animator.assigned_animation==expected and visual.get_meta("native_action").action==action,"Exact native action selects declared airborne replacement")
	visual.action_remaining=0.;visual.flight_state="air";check(visual.receive_action({"protocol":"classic","action":3}),"Feeding packet accepted during low flight")
	check(visual.animator.assigned_animation=="Land" and visual.current_clip=="Eat","Feeding waits for an actual landing")
	await wait_seconds(.95)
	check(visual.animator.assigned_animation=="Eat" and visual.flight_state=="ground" and visual.action_remaining>0.,"Landed feeding starts with its own remaining duration")
	visual.action_remaining=0.;visual.flight_state="air";actor.animate(false,0.,1./60.,0.)
	check(visual.current_clip=="Land","Stopping flight starts authored landing")
	await wait_seconds(.95);check(visual.current_clip=="Idle" and visual.flight_state=="ground","Landing returns to perched idle")
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(8.,.1,8.);collider.shape=shape;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground)
	actor.set_physics_process(true);visual.set_physics_process(true);var terrain: Array=[]
	for slope in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,-.08)]:
		for yaw in [0.,PI/2.]:
			for clip in ["Idle","Eat","Run"]:
				ground.position.y=-.15 if yaw==0. else .18;ground.rotation=Vector3(slope.x,0.,slope.y);visual.transition_remaining=0.;visual.current_clip=clip;visual.action_remaining=1000.;visual.dead=false;visual.contact.enabled=true;visual.play(clip,0.)
				for frame in 55:
					await physics_frame;actor.animate(false,yaw,1./60.,0.);visual.animator.seek(visual.animator.current_animation_length*.5,true);visual.animator.pause();await process_frame
				var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1))
				check(not hit.is_empty(),"Finite raised/lowered support plane sampled")
				if hit.is_empty():continue
				var gap:=plane_gap(mesh,rig,hit.position,hit.normal);var claw_gap:=plane_gap(mesh,rig,hit.position,hit.normal,true)
				check(actor.global_position.is_zero_approx() and absf(actor.ground_offset-float(hit.position.y))<.015,"Terrain fitting changes presentation, preserving native coordinates")
				if clip=="Run":check(gap>.07,"Actual low-flight skin stays above the tilted finite plane")
				else:check(absf(claw_gap)<.008 and gap>-.008,"Actual claws remain planted without wing/tail penetration")
				var head:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("Bone.003")).origin);check(absf(plate.global_position.y-head.y-.08)<.004,"Overhead label follows animated eagle skull")
				terrain.append({"clip":clip,"slope":str(slope),"yaw":yaw,"height":ground.position.y,"skin_gap":gap,"claw_gap":claw_gap})
	actor.set_physics_process(false);visual.set_physics_process(false);ground.free();actor.rotation=Vector3.ZERO;actor.visual_root.position.y=0.;visual.model.basis=visual.source_model_basis.scaled_local(visual.default_model_scale);visual.model.position.y=0.
	visual.action_remaining=0.;visual.flight_state="air";visual.dead=false;visual.transition_remaining=0.;visual.receive_action({"protocol":"classic","action":8})
	check(visual.current_clip=="Death" and visual.animator.assigned_animation=="AirDeath","Airborne native death selects falling/landing variation")
	visual.set_process(false);visual.animator.seek(visual.animator.current_animation_length,true);visual.animator.pause();for frame in 2:await process_frame
	var live_bounds:=Geometry.deformed_bounds(mesh,rig);var frozen:=Corpses.build(5,0)
	check(frozen!=null,"Native corpse graphic0x2006/amount5 is available from candidate registry")
	if frozen:
		var frozen_bounds: AABB=frozen.get_meta("corpse_bounds");print("EAGLE AIR DEATH final ",live_bounds," static ",frozen_bounds);check(frozen_bounds.size.distance_to(live_bounds.size)<.001 and absf(live_bounds.position.y)<.001,"Air death ends at the exact static cadaver shape/height");frozen.free()
	actor.free()
	for hue in [0,53,0x8035]:
		var corpse:=Corpses.build(5,hue);check(corpse!=null,"Eagle static cadaver exists for native hue")
		if corpse==null:continue
		viewport.add_child(corpse);var bounds: AABB=corpse.get_meta("corpse_bounds")
		check(corpse.get_meta("corpse_body")==5 and corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("native_hue")==hue,"Corpse retains native graphic/body/hue")
		check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and bounds.position.y==0. and bounds.size.y<.22,"Cadaver is grounded static geometry")
		var image:=await capture();image.save_png(ProjectSettings.globalize_path(output+"/corpse-%04x.png"%hue));corpse.free()
	var runtime: Dictionary={}
	for name in INPUTS:runtime["res://Presentation/"+name]=FileAccess.get_sha256("res://Presentation/"+name)
	var asset:=Registry.asset_path(record);var report:={"checks":checks,"failures":failures,"terrain":terrain,"hues":hues,"renderer":RenderingServer.get_current_rendering_method(),"runtime_sha256":runtime,"candidate_sha256":FileAccess.get_sha256(candidate),"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import")}
	FileAccess.open(output+"/presentation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("EAGLE PRESENTATION: ",checks," / ",failures," failures; ",terrain.size()," finite-plane cases");quit(1 if failures else 0)
