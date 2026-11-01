extends SceneTree
## Six actual skin surfaces, two physical gaits, planted and lifted paws.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Support=preload("res://Presentation/CatGroundSupport.gd")
const INPUTS=["CatPresentationTests.gd","CatGroundSupport.gd","CreatureCatMaterial.gd","CreatureCatSurface.gdshader","CreatureVisual.gd","SourceMountContact.gd","OstardVisual.gd","HumanAvatar.gd","LegacyAvatar.gd","CreatureRegistry.gd","MountVisual.gd","HumanHue.gd","HumanActions.gd","AnimalPoseLibrary.gd","CorpseModels.gd","SkinGeometry.gd"]
var checks:=0
var failures:=0
var viewport: SubViewport
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<20:push_error(label)
func capture() -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw;return viewport.get_texture().get_image()
func difference(a: Image,b: Image) -> int:
	var count:=0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var d:=a.get_pixel(x,y)-b.get_pixel(x,y)
			if absf(d.r)+absf(d.g)+absf(d.b)>.04:count+=1
	return count
func run() -> void:
	Registry.load_index();var candidate:="res://local-art/cat/candidate.json";var record: Dictionary
	if "--public" in OS.get_cmdline_user_args():record=Registry.entry(201);candidate="res://Art/Creatures/index.json"
	else:record=JSON.parse_string(FileAccess.get_file_as_string(candidate))
	Registry.entries[201]=record;var output:="res://../outputs/creatures/cat-trial";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=Vector2i(1000,750);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.8;camera.near=.001;viewport.add_child(camera);camera.position=Vector3(.8,.4,1.);camera.look_at(Vector3(0.,.16,0.))
	var actor:=Avatar.new();actor.initial_body=201;actor.set_meta("own",true);var plate:=Node3D.new();plate.name="Nameplate";actor.add_child(plate)
	var picker:=StaticBody3D.new();picker.collision_layer=2;picker.set_meta("server_mobile",42);var pick_shape:=CollisionShape3D.new();pick_shape.shape=CapsuleShape3D.new();picker.add_child(pick_shape);actor.add_child(picker)
	viewport.add_child(actor);actor.apply_server_appearance({"body":201,"hue":0},[]);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false
	var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
	check(visual.native_body==201 and visual.action_profile=="animal","Native Cat identity uses the real animal profile")
	check(visual.contact is Support and visual.contact.feet.size()==4 and visual.contact.stride==8,"Four paws span every actual material surface and all eight influences")
	for foot: Dictionary in visual.contact.feet:check(foot.vertices.size()>0 and foot.a!=foot.b and foot.b!=foot.c,"Separate original upper/lower/paw joints and weighted soles")
	visual.play("Idle",0.);visual.animator.seek(0.,true);visual.animator.pause();var base:=await capture();base.save_png(ProjectSettings.globalize_path(output+"/coat-default.png"))
	var eyes:=0;var fur: ShaderMaterial
	for i in mesh.mesh.get_surface_count():
		var source:=mesh.mesh.surface_get_material(i) as StandardMaterial3D;var active:=mesh.get_active_material(i)
		if source.resource_name.begins_with("CatEye"):eyes+=1;check(active==source,"Fixed gold iris/dark pupil surface retains source material")
		else:
			check(active is ShaderMaterial and active.shader==preload("res://Presentation/CreatureCatSurface.gdshader"),"Actual original colour region receives coat shader")
			if source.resource_name=="CatGrey":fur=active
	check(eyes==3 and fur!=null,"Three fixed eye surfaces and original fur region survive")
	if fur!=null:
		fur.set_shader_parameter("coat_detail",0.);var plain:=await capture();check(difference(base,plain)>50,"Authored procedural coat changes actual pixels")
		fur.set_shader_parameter("coat_detail",.65);fur.set_shader_parameter("coat_roughness",.06);var glossy:=await capture();check(difference(base,glossy)>50,"Matte coat roughness changes the actual lighting response")
	actor.apply_server_appearance({"body":201,"hue":0},[]);var rig_id:=rig.get_instance_id();var hues: Array=[];var full_pixels:=0;var partial_pixels:=0
	for hue in [53,0x8035,0x901]:
		actor.apply_server_appearance({"body":201,"hue":hue},[]);var image:=await capture();var pixels:=difference(base,image)
		check(visual.native_hue==hue and rig.get_instance_id()==rig_id,"Raw native hue bits preserve the rig")
		check(pixels>100,"Native cat hue changes visible skin")
		for i in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if source.resource_name.begins_with("CatEye"):check(mesh.get_active_material(i)==source,"Full/partial hue preserves the authored eyes")
		if hue==53:full_pixels=pixels
		if hue==0x8035:partial_pixels=pixels
		hues.append({"hue":hue,"pixels":pixels});image.save_png(ProjectSettings.globalize_path(output+"/hue-%04x.png"%hue))
	check(partial_pixels<full_pixels-100,"Partial tint protects white chest/paws and pink features")
	actor.apply_server_appearance({"body":201,"hue":0},[])
	check(pick_shape.shape is BoxShape3D and pick_shape.shape.size.y<.7 and pick_shape.shape.size.z<1.,"Small measured selection bounds replace human dimensions")
	check(is_equal_approx(float(actor.get_meta("camera_height")),.3),"Cat camera uses its measured scale")
	var gaits: Array=[]
	for speed in [.192,1.8,6.8]:
		visual.action_remaining=0.;visual.current_clip="Idle";actor.animate(true,0.,1./60.,speed)
		var expected: String="Walk" if speed<.4 else "Run" if speed<3.6 else "Gallop"
		check(visual.current_clip==expected and absf(visual.animator.speed_scale-1.)<.001,"Actual avatar selects a measured gait at its physical reference speed")
		check(visual.animator.get_animation(expected).loop_mode==Animation.LOOP_LINEAR,"Selected locomotion category loops")
		gaits.append({"speed":speed,"clip":visual.current_clip,"rate":visual.animator.speed_scale})
	for frame in 45:await physics_frame;await process_frame
	check(visual.animator.is_playing() and visual.current_clip=="Gallop","Gallop continues beyond two cycles instead of freezing")
	visual.animator.pause()
	var baselines: Dictionary={}
	for clip in ["Idle","Walk","Eat","Run","Gallop"]:
		visual.play(clip,0.);visual.animator.seek(visual.animator.current_animation_length*.5,true);visual.animator.pause();for frame in 2:await process_frame
		var baseline: Dictionary={}
		for foot: Dictionary in visual.contact.feet:baseline[foot.source_leg]=visual.contact.sole(foot).y
		baselines[clip]=baseline
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(8.,.1,8.);collider.shape=shape;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground)
	actor.set_physics_process(true);visual.set_process(true);visual.set_physics_process(true);var terrain: Array=[];var lifted:=0
	for slope in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,-.08)]:
		for yaw in [0.,PI/2.]:
			for clip in ["Idle","Walk","Eat","Run","Gallop"]:
				ground.position.y=-.15 if yaw==0. else .18;ground.rotation=Vector3(slope.x,0.,slope.y);visual.current_clip=clip;visual.action_remaining=1000.;visual.dead=false;visual.contact.enabled=true;visual.play(clip,0.)
				for frame in 55:
					await physics_frame;actor.animate(false,yaw,1./60.,0.);visual.animator.seek(visual.animator.current_animation_length*.5,true);visual.animator.pause();await process_frame
				var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1))
				check(not hit.is_empty(),"Actual finite support plane is sampled")
				if hit.is_empty():continue
				check(actor.global_position.is_zero_approx() and absf(actor.ground_offset-float(hit.position.y))<.015,"Support follows raised/lowered presentation without moving native coordinates")
				check(visual.contact.contacts.size()==4,"All four real paws sample support")
				var paws: Array=[]
				for foot: Dictionary in visual.contact.feet:
					var sole: Vector3=visual.contact.sole(foot);var gap: float=hit.normal.dot(sole-hit.position);var baseline:=float(baselines[clip][foot.source_leg]);paws.append({"leg":foot.source_leg,"gap":gap,"authored_lift":baseline})
					if baseline>.025:lifted+=1;check(gap>baseline-.012 and gap<baseline+.012,"Terrain fitting preserves the actual lifted swing paw: "+str(foot.source_leg)+" "+clip)
					elif baseline<.008:check(absf(gap)<.006,"Actual standing paw follows the finite plane within6mm: "+str(foot.source_leg)+" "+clip)
					else:check(gap>-.006 and gap<baseline+.012,"Transition paw stays bounded without whole-leg stretching")
				var head:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 head")).origin);check(absf(plate.global_position.y-head.y-.08)<.004,"Nameplate follows the actual animated skull")
				terrain.append({"clip":clip,"slope":str(slope),"yaw":yaw,"height":ground.position.y,"paws":paws})
				if yaw==0. and slope==Vector2.ZERO and clip in ["Eat","Run","Gallop"]:
					var image:=await capture();image.save_png(ProjectSettings.globalize_path(output+"/grounded-"+clip+".png"))
	check(lifted>=12,"Support test includes real airborne paws rather than only planted poses")
	for action in range(13):
		visual.dead=false;visual.action_remaining=0.;check(visual.receive_action({"protocol":"classic","action":action}),"Actual cat accepts native animal group "+str(action))
	actor.free();ground.free()
	for hue in [0,53,0x8035]:
		var corpse:=Corpses.build(201,hue);check(corpse!=null,"Native0x2006/amount201 cat corpse exists")
		if corpse==null:continue
		viewport.add_child(corpse);var bounds: AABB=corpse.get_meta("corpse_bounds")
		check(corpse.get_meta("corpse_body")==201 and corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("native_hue")==hue,"Corpse retains exact native graphic/body/hue")
		check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and bounds.position.y==0. and bounds.size.y<.2,"Cat cadaver is grounded static geometry")
		var image:=await capture();image.save_png(ProjectSettings.globalize_path(output+"/corpse-%04x.png"%hue));corpse.free()
	var runtime: Dictionary={}
	for name in INPUTS:runtime["res://Presentation/"+name]=FileAccess.get_sha256("res://Presentation/"+name)
	var asset:=Registry.asset_path(record);var report:={"checks":checks,"failures":failures,"terrain":terrain,"lifted_paw_cases":lifted,"hues":hues,"gaits":gaits,"renderer":RenderingServer.get_current_rendering_method(),"runtime_sha256":runtime,"candidate_sha256":FileAccess.get_sha256(candidate),"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import")}
	FileAccess.open(output+"/presentation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CAT PRESENTATION: ",checks," / ",failures," failures; ",terrain.size()," four-paw terrain cases; ",lifted," lifted paws");quit(0 if failures==0 else 1)
