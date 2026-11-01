extends SceneTree
## Actual rat avatar, fur response, four source legs, finite terrain and corpse.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Support=preload("res://Presentation/RatGroundSupport.gd")
const INPUTS=["RatPresentationTests.gd","RatGroundSupport.gd","SourceMountContact.gd","CreatureVisual.gd","OstardVisual.gd","HumanAvatar.gd","LegacyAvatar.gd","CreatureRegistry.gd","MountVisual.gd","CreatureFurMaterial.gd","CreatureFurSurface.gdshader","HumanHue.gd","AnimalPoseLibrary.gd","HumanActions.gd","CorpseModels.gd","SkinGeometry.gd"]
var checks:=0
var failures:=0
var viewport: SubViewport
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<18:push_error(label)
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
	Registry.load_index()
	var candidate:="res://local-art/rat/candidate.json";var record: Dictionary
	if "--public" in OS.get_cmdline_user_args():record=Registry.entry(238);candidate="res://Art/Creatures/index.json"
	else:record=JSON.parse_string(FileAccess.get_file_as_string(candidate))
	Registry.entries[238]=record
	var output:="res://../outputs/creatures/rat-trial";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=Vector2i(800,700);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.62;camera.near=.001;viewport.add_child(camera);camera.position=Vector3(.7,.35,.75);camera.look_at(Vector3(0.,.06,0.))
	var actor:=Avatar.new();actor.initial_body=238;actor.set_meta("own",true)
	var plate:=Node3D.new();plate.name="Nameplate";actor.add_child(plate)
	var picker:=StaticBody3D.new();picker.collision_layer=2;picker.set_meta("server_mobile",42);var pick_shape:=CollisionShape3D.new();pick_shape.shape=CapsuleShape3D.new();picker.add_child(pick_shape);actor.add_child(picker)
	viewport.add_child(actor);actor.apply_server_appearance({"body":238,"hue":0},[]);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false)
	var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
	check(visual.native_body==238 and visual.action_profile=="animal","Exact ordinary Rat identity uses animal action profile")
	check(visual.contact is Support and visual.contact.feet.size()==4,"Four independently weighted source legs configured")
	for foot: Dictionary in visual.contact.feet:check(foot.vertices.size()>0 and foot.a!=foot.b,"Actual sole vertices and two distinct real leg joints")
	visual.contact.enabled=false;visual.play("Idle",0.);visual.animator.seek(0.,true);visual.animator.pause()
	var base:=await capture();base.save_png(ProjectSettings.globalize_path(output+"/fur-default.png"))
	var material:=mesh.get_surface_override_material(0) as ShaderMaterial
	check(material!=null and material.shader==preload("res://Presentation/CreatureFurSurface.gdshader"),"Natural matte fur shader is bound to the actual rat")
	material.set_shader_parameter("fur_roughness",.06);var polished:=await capture();var rough_pixels:=difference(base,polished)
	check(rough_pixels>10,"Actual fur roughness changes rendered response")
	actor.apply_server_appearance({"body":238,"hue":0},[])
	var rig_id:=rig.get_instance_id();var hues: Array=[];var full_pixels:=0;var partial_pixels:=0
	for hue in [53,0x8035,0x901]:
		actor.apply_server_appearance({"body":238,"hue":hue},[]);var dyed:=await capture();var pixels:=difference(base,dyed)
		check(visual.native_hue==hue and rig.get_instance_id()==rig_id,"Raw hue bits update without replacing the animated rig")
		check(pixels>50,"Server hue has visible GPU response")
		if hue==53:full_pixels=pixels
		if hue==0x8035:partial_pixels=pixels
		hues.append({"hue":hue,"pixels":pixels});dyed.save_png(ProjectSettings.globalize_path(output+"/hue-%04x.png"%hue))
	check(partial_pixels<full_pixels-20,"Partial tint protects visible pink features")
	actor.apply_server_appearance({"body":238,"hue":0},[])
	check(pick_shape.shape is BoxShape3D and pick_shape.shape.size.y<.35 and pick_shape.shape.size.z<.8,"Measured small rat selection box replaces human dimensions")
	check(is_equal_approx(float(actor.get_meta("camera_height")),.15),"Rat camera uses its own scale")
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(8.,.1,8.);collider.shape=shape;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground)
	actor.set_physics_process(true);visual.set_process(true);visual.set_physics_process(true);var terrain: Array=[]
	for slope in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,-.08)]:
		for yaw in [0.,PI/2.]:
			for clip in ["Idle","Walk","Eat"]:
				ground.position.y=-.15 if yaw==0. else .18;ground.rotation=Vector3(slope.x,0.,slope.y)
				visual.current_clip=clip;visual.action_remaining=100.;visual.dead=false;visual.contact.enabled=true;visual.play(clip,0.)
				for frame in 55:
					await physics_frame;actor.animate(false,yaw,1./60.,0.);visual.animator.seek(visual.animator.current_animation_length*.5,true);visual.animator.pause();await process_frame
				var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1))
				check(not hit.is_empty(),"Actual finite support collider is sampled")
				if hit.is_empty():continue
				check(actor.global_position.is_zero_approx() and absf(actor.ground_offset-float(hit.position.y))<.015,"Raised/lowered support preserves native entity coordinates")
				check(visual.contact.contacts.size()==4,"Every source leg samples terrain")
				var gaps: Array=[]
				for foot: Dictionary in visual.contact.feet:
					var sole: Vector3=visual.contact.sole(foot);var gap: float=hit.normal.dot(sole-hit.position);gaps.append(gap)
					check(absf(gap)<(.018 if clip=="Walk" else .004),"Actual weighted paw follows the finite support plane: "+str(foot.source_leg)+" "+clip)
				var head:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("head")).origin)
				check(absf(plate.global_position.y-head.y-.08)<.004,"Nameplate follows the actual rat skull")
				terrain.append({"clip":clip,"slope":str(slope),"yaw":yaw,"height":ground.position.y,"paw_gaps":gaps})
				if clip=="Eat" and yaw==0. and slope==Vector2.ZERO:
					var feeding:=await capture();feeding.save_png(ProjectSettings.globalize_path(output+"/feeding-grounded.png"))
	for protocol in ["classic","new"]:
		for action in range(13) if protocol=="classic" else [0,3,4]:
			visual.dead=false;visual.action_remaining=0.;check(visual.receive_action({"protocol":protocol,"action":action,"type":action}),"Actual native animal category: "+protocol+" "+str(action))
	# A rat has no native spellcaster category. Do not invent a cast solely to
	# make an irrelevant protocol slot look complete.
	actor.free();ground.free()
	for hue in [0,53,0x8035]:
		var corpse:=Corpses.build(238,hue);check(corpse!=null,"Native0x2006/amount238 corpse exists")
		if corpse==null:continue
		viewport.add_child(corpse);var bounds: AABB=corpse.get_meta("corpse_bounds")
		check(corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("corpse_body")==238 and corpse.get_meta("native_hue")==hue,"Corpse retains exact native graphic/body/hue")
		check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and bounds.position.y==0. and bounds.size.y<.3,"Corpse is grounded static geometry with no running rig")
		var image:=await capture();image.save_png(ProjectSettings.globalize_path(output+"/corpse-%04x.png"%hue));corpse.free()
	var runtime: Dictionary={}
	for name in INPUTS:runtime["res://Presentation/"+name]=FileAccess.get_sha256("res://Presentation/"+name)
	var asset:=Registry.asset_path(record);var report:={"checks":checks,"failures":failures,"terrain":terrain,"hues":hues,"roughness_response_pixels":rough_pixels,
		"renderer":RenderingServer.get_current_rendering_method(),"runtime_sha256":runtime,"candidate_sha256":FileAccess.get_sha256(candidate),"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import")}
	FileAccess.open(output+"/presentation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RAT PRESENTATION: ",checks," / ",failures," failures; ",terrain.size()," four-paw terrain cases");quit(0 if failures==0 else 1)
