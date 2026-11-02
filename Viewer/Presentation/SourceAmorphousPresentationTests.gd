extends SceneTree
## Actual avatar, complete non-IK skins, source bounce and finite terrain.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Visual=preload("res://Presentation/SourceAmorphousVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const CATEGORIES=preload("res://Presentation/SourceAmorphousActionTests.gd").CATEGORIES
const INPUTS=["SourceAmorphousPresentationTests.gd","SourceAmorphousActionTests.gd","SourceAmorphousVisual.gd","SourceAmorphousMaterial.gd","SourceAmorphousSurface.gdshader","SmallSnakeVisual.gd","SourceGroundLookup.gd","SourcePoseSubdivision.gd","BirdGroundSupport.gd","CreatureRegistry.gd","CreatureVisual.gd","SourceMountContact.gd","FootContact.gd","OstardVisual.gd","OstardSurface.gdshader","CreatureCutoutSurface.gdshader","HumanAvatar.gd","LegacyAvatar.gd","HumanHue.gd","HumanActions.gd","MountVisual.gd","AnimalVisual.gd","AnimalPoseLibrary.gd","SkinGeometry.gd","CorpseModels.gd"]
var checks:=0
var failures:=0
var viewport: SubViewport
var kind:="slimes_slime"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):kind=arg.trim_prefix("--kind=")
	create_timer(1500.).timeout.connect(func():push_error("Source amorphous presentation deadline");quit(1));call_deferred("run")
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
			if absf(d.r)+absf(d.g)+absf(d.b)>.025:count+=1
	return count
func run() -> void:
	var preparation:="res://local-art/creatures/amorphous/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation));var record: Dictionary=prep.models.filter(func(r: Dictionary):return r.kind==kind)[0];var body:=int(record.bodies[0].body);Registry.load_index();Registry.entries[body]=record
	var output:="res://../outputs/creatures/amorphous/"+kind+"-presentation";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=Vector2i(1000,750);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;viewport.add_child(camera)
	var actor:=Avatar.new();actor.initial_body=body;actor.set_meta("own",true);var plate:=Node3D.new();plate.name="Nameplate";actor.add_child(plate);var picker:=StaticBody3D.new();picker.set_meta("server_mobile",body);picker.collision_layer=2;var pick_shape:=CollisionShape3D.new();pick_shape.shape=BoxShape3D.new();picker.add_child(pick_shape);actor.add_child(picker);viewport.add_child(actor);actor.apply_server_appearance({"body":body,"hue":0},[]);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false;visual.contact.active=false;var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0];var skin:=Ground.skin_points(mesh,rig)
	check(visual is Visual and rig.get_bone_count()==(56 if body==775 else 29) and visual.contact.feet.is_empty(),"Original actual avatar retains complete nonstandard rig without invented foot chains")
	visual.play("Idle",0.);visual.animator.seek(0.,true);visual.animator.pause();rig.force_update_all_bone_transforms();var idle:=Geometry.deformed_bounds(mesh,rig);camera.size=idle.size.length()*1.1;camera.position=idle.get_center()+Vector3(2.,1.4,4.)*idle.size.length();camera.look_at(idle.get_center());var wide:=camera.transform;var wide_size:=camera.size;var base:=await capture();base.save_png(ProjectSettings.globalize_path(output+"/default.png"));var instance:=rig.get_instance_id();var hues: Array=[];var images: Array[Image]=[];var requested: Array=[53,0x8035,0x901]
	if body==51:
		for hue in range(2201,2225):requested.append(hue)
		for hue in range(17,32):requested.append(hue)
	for hue: int in requested:
		actor.apply_server_appearance({"body":body,"hue":hue},[]);var image:=await capture();var pixels:=difference(base,image);var material:=mesh.get_active_material(0) as ShaderMaterial
		check(visual.native_body==body and visual.native_hue==hue and rig.get_instance_id()==instance,"Raw native body/hue bits retain the exact source skeleton")
		check(material.get_shader_parameter("use_hue") and bool(material.get_shader_parameter("partial_hue"))==bool(hue&0x8000),"Actual full/partial native palette flags bound")
		if not hue&0x8000:check(pixels>100,"Native full colour visibly changes actual source flesh/gel")
		hues.append({"hue":hue,"changed_pixels":pixels});images.append(image);image.save_png(ProjectSettings.globalize_path(output+"/hue-%04x.png"%hue))
	var partial_pixels:=difference(images[0],images[1]);check(partial_pixels>100,"Partial source-neutral recolouring remains distinct from full-body colour")
	actor.apply_server_appearance({"body":body,"hue":0},[]);var material:=mesh.get_active_material(0) as ShaderMaterial;var original:=material.get_shader_parameter("source_atlas") as Texture2D;var detailed:=material.get_shader_parameter("albedo_texture") as Texture2D;var source_image:=original.get_image()
	if source_image.is_compressed():check(source_image.decompress()==OK,"Actual bound original opacity decompresses for inspection")
	var nonopaque:=0
	for y in source_image.get_height():
		for x in source_image.get_width():
			if source_image.get_pixel(x,y).a<1.:nonopaque+=1
	check(nonopaque>0 and original.get_width()==(256 if body==775 else 64),"Original source atlas and graded alpha retained independently of authored surface")
	var modern_rgb:=await capture()
	if body==775:material.set_shader_parameter("albedo_texture",original)
	else:material.set_shader_parameter("gel_strength",0.)
	var source_rgb:=await capture();var texture_pixels:=difference(modern_rgb,source_rgb);check(texture_pixels>100,"Actual generated RGBA/source-RGB composite or authored natural gel changes the source surface")
	material.set_shader_parameter("albedo_texture",detailed);material.set_shader_parameter("gel_strength",1.);camera.size=idle.size.length()*.45;var relief:=await capture();relief.save_png(ProjectSettings.globalize_path(output+"/surface.png"));material.set_shader_parameter("detail_strength",0.);var smooth:=await capture();var relief_pixels:=difference(relief,smooth);check(relief_pixels>10,"Authored UV-bound surface relief visibly changes actual lighting");material.set_shader_parameter("detail_strength",.24);camera.transform=wide;camera.size=wide_size
	var cutout_pixels:=0;material.set_shader_parameter("alpha_probe",true)
	for angle in [0.,-.8,PI/2.,PI]:
		actor.rotation.y=angle;material.set_shader_parameter("use_source_alpha",true);var masked:=await capture();material.set_shader_parameter("use_source_alpha",false);var solid:=await capture()
		for y in range(0,solid.get_height(),2):
			for x in range(0,solid.get_width(),2):
				if solid.get_pixel(x,y).g-masked.get_pixel(x,y).g>.08:cutout_pixels+=1
	material.set_shader_parameter("alpha_probe",false);material.set_shader_parameter("use_source_alpha",true);actor.rotation.y=0.;check(cutout_pixels>10,"Actual retained source alpha creates measured body-edge/cutout differences")
	if "--appearance-only" in OS.get_cmdline_user_args():print("SOURCE AMORPHOUS APPEARANCE: ",kind," / ",checks," / ",failures," failures / cutout ",cutout_pixels," / relief ",relief_pixels);actor.free();quit(1 if failures else 0);return
	var phases: Array[float]=[0.,.1173,.2371,.3871,.4619,.5831,.7231,.8371,1.];var references: Dictionary={}
	for clip: String in CATEGORIES:
		var rows: Dictionary={}
		for phase: float in phases:
			visual.play(clip,0.);visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();for frame in 2:await process_frame
			rows[str(phase)]=Ground.minimum_plane_gap(skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP)
		references[clip]=rows
	visual.set_process(true);visual.set_physics_process(true);visual.contact.active=true;actor.set_physics_process(true);var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var slab:=BoxShape3D.new();slab.size=Vector3(12.,.1,12.);collider.shape=slab;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground);var terrain: Array=[];var maximum_planted_gap:=0.;var maximum_lift_error:=0.;var airborne:=0;var planted:=0
	for slope in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,-.08)]:
		for yaw in [0.,PI/2.]:
			for clip: String in CATEGORIES:
				for phase: float in phases:
					ground.position.y=-.15 if yaw==0. else .18;ground.rotation=Vector3(slope.x,0.,slope.y);actor.rotation.y=yaw;visual.dead=false;visual.current_clip=clip;visual.action_remaining=1000.;visual.contact.enabled=true;visual.play(clip,0.);var frames:=0
					for frame in 45:
						await physics_frame;actor.animate(false,yaw,1./60.,0.);visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();await process_frame;frames=frame+1;var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1))
						if frame<2 or hit.is_empty() or absf(actor.ground_offset-float(hit.position.y))>.002:continue
						var normal: Vector3=(visual.global_basis.inverse()*hit.normal).normalized();var target: Basis=Basis.from_euler(Vector3(clampf(atan2(normal.z,normal.y),-.2,.2),0.,clampf(-atan2(normal.x,normal.y),-.15,.15)))*visual.source_model_basis
						if visual.model.basis.orthonormalized().get_rotation_quaternion().angle_to(target.get_rotation_quaternion())<.0005:break
					await RenderingServer.frame_post_draw;var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1));check(not hit.is_empty(),"Actual finite raised/lowered support plane sampled")
					if hit.is_empty():continue
					var gap:=Ground.minimum_plane_gap(skin,rig,rig.global_transform,hit.position,hit.normal);var expected:=float(references[clip][str(phase)]);var actual:=Geometry.deformed_bounds(mesh,rig);var bounds: AABB=visual.get_meta("pick_bounds")
					check(actor.global_position.is_zero_approx() and absf(actor.ground_offset-float(hit.position.y))<.015,"Only presentation follows actual support; native coordinates unchanged")
					if clip in ["Walk","Run"] and expected>.03:airborne+=1;maximum_lift_error=maxf(maximum_lift_error,absf(gap-expected));check(absf(gap-expected)<.009,"Actual running/walking source rise retained on tilted terrain")
					else:planted+=1;maximum_planted_gap=maxf(maximum_planted_gap,absf(gap-expected));check(absf(gap-expected)<.008,"Complete source lower skin follows its actual plane within8mm")
					check(actual.position.is_finite() and actual.size.is_finite(),"Actual complete render-stage source skin remains finite")
					check((visual.global_transform*bounds).grow(.001).encloses(actual),"Dynamic weighted bounds contain every source face/tendril/blob pose")
					check(plate.global_position.y>actual.end.y+.015,"Actual source nameplate clears the whole skin")
					check((pick_shape.global_transform*AABB(-pick_shape.shape.size*.5,pick_shape.shape.size)).grow(.001).encloses(actual),"Actual mobile selection collider encloses complete rendered source skin")
					terrain.append({"clip":clip,"phase":phase,"slope":str(slope),"yaw":yaw,"height":ground.position.y,"gap_m":gap,"source_lift_m":expected,"settling_frames":frames})
	check(airborne>20 and planted>20,"Actual source ground contact and preserved positive gait phases tested")
	actor.set_physics_process(false);visual.set_physics_process(false);visual.contact.active=false;ground.free();actor.free();var cadavers: Array=[]
	for hue in ([0,53,0x8035,2201,2224,17,31] if body==51 else [0,53,0x8035]):
		var corpse:=Corpses.build(body,hue);check(corpse!=null,"Original source body produces native0x2006 static corpse")
		if corpse==null:continue
		viewport.add_child(corpse);var bounds: AABB=corpse.get_meta("corpse_bounds");check(corpse.get_meta("corpse_body")==body and corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("native_hue")==hue,"Static corpse retains exact source body/graphic/raw native colours");check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and bounds.position.y==0.,"Final skin frozen without a rig and grounded");var image:=await capture();image.save_png(ProjectSettings.globalize_path(output+"/corpse-%04x.png"%hue));cadavers.append({"hue":hue,"height":bounds.size.y});corpse.free()
	var runtime: Dictionary={}
	for name in INPUTS:runtime["res://Presentation/"+name]=FileAccess.get_sha256("res://Presentation/"+name)
	var asset:=Registry.asset_path(record);var report:={"kind":kind,"body":body,"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"hues":hues,"partial_full_difference_pixels":partial_pixels,"modern_texture_pixels":texture_pixels,"relief_pixels":relief_pixels,"source_cutout_pixels":cutout_pixels,"source_nonopaque_texels":nonopaque,"terrain":terrain,"maximum_planted_gap_m":maximum_planted_gap,"maximum_lift_error_m":maximum_lift_error,"airborne_gait_cases":airborne,"planted_cases":planted,"cadavers":cadavers,"preparation_sha256":FileAccess.get_sha256(preparation),"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import"),"runtime_sha256":runtime,"scope":"Actual registered original nonstandard source rigs, source-opacity-bound flesh/gel/native colours/picking/nameplates, complete skins on6finite planes, retained gait rise and static cadavers. No bone-changing IK; full source poses read after actual rendered frames. Offline, not native owner lifecycle/autonomous gameplay/arbitrary terrain/complete original choreography/final art."};FileAccess.open(output+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("SOURCE AMORPHOUS PRESENTATION: ",kind," / ",checks," / ",failures," failures / ",terrain.size()," finite poses / rise cases ",airborne);quit(1 if failures else 0)
