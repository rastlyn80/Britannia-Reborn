extends SceneTree
## Actual factory/avatar and render-stage source skin on finite support planes.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Visual=preload("res://Presentation/SourceSolenVisual.gd")
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const CATEGORIES=preload("res://Presentation/SourceSolenActionTests.gd").CATEGORIES
const INPUTS=["SourceSolenPresentationTests.gd","SourceSolenActionTests.gd","SourceSolenVisual.gd","SourceSolenMaterial.gd","SourceSolenSurface.gdshader","SourceGroundLookup.gd","SourceSolenSupport.gd","MeasuredCreatureSupport.gd","SmallSnakeVisual.gd","BirdGroundSupport.gd","CreatureRegistry.gd","CreatureVisual.gd","SourceMountContact.gd","FootContact.gd","OstardVisual.gd","OstardSurface.gdshader","HumanAvatar.gd","LegacyAvatar.gd","HumanHue.gd","HumanActions.gd","MountVisual.gd","AnimalVisual.gd","AnimalPoseLibrary.gd","SkinGeometry.gd","CorpseModels.gd"]
var checks:=0
var failures:=0
var viewport: SubViewport
var kind:="fire_ant_worker"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):kind=arg.trim_prefix("--kind=")
	create_timer(1500.).timeout.connect(func():push_error("Source Solen presentation deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<25:push_error(label)
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
func lengths(rig: Skeleton3D,feet: Array) -> Array:
	var result: Array=[]
	for foot: Dictionary in feet:
		var a:=rig.to_global(rig.get_bone_global_pose(foot.a).origin);var b:=rig.to_global(rig.get_bone_global_pose(foot.b).origin);var c:=rig.to_global(rig.get_bone_global_pose(foot.c).origin);result.append([a.distance_to(b),b.distance_to(c)])
	return result
func run() -> void:
	var preparation:="res://local-art/creatures/solen_workers/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation));var record: Dictionary=prep.models.filter(func(r: Dictionary):return r.kind==kind)[0];var body:=int(record.bodies[0].body);Registry.load_index();Registry.entries[body]=record
	var output:="res://../outputs/creatures/solen_workers/"+kind+"-presentation";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=Vector2i(1000,750);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.;viewport.add_child(camera);camera.position=Vector3(3.,2.,5.);camera.look_at(Vector3(0.,1.2,0.))
	var actor:=Avatar.new();actor.initial_body=body;actor.set_meta("own",true);var plate:=Node3D.new();plate.name="Nameplate";actor.add_child(plate);var picker:=StaticBody3D.new();picker.set_meta("server_mobile",body);picker.collision_layer=2;var pick_shape:=CollisionShape3D.new();pick_shape.shape=BoxShape3D.new();picker.add_child(pick_shape);actor.add_child(picker);viewport.add_child(actor);actor.apply_server_appearance({"body":body,"hue":0},[]);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false;visual.contact.active=false;var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
	check(visual is Visual and rig.get_bone_count()==42 and visual.contact.feet.size()==6,"Owned renderer factory retains original42joint source/six actual two-joint leg chains")
	check(visual.native_body==body and visual.action_profile=="monster","Native red781/black805 source monster identities retained")
	visual.play("Idle",0.);visual.animator.seek(0.,true);visual.animator.pause();var base:=await capture();base.save_png(ProjectSettings.globalize_path(output+"/default.png"));var instance:=rig.get_instance_id();var hues: Array=[];var hue_images: Array[Image]=[]
	for hue in ([53,0x8035,0x901,0x453] if body==805 else [53,0x8035,0x901]):
		actor.apply_server_appearance({"body":body,"hue":hue},[]);var image:=await capture();var pixels:=difference(base,image);var material:=mesh.get_active_material(0) as ShaderMaterial
		check(visual.native_hue==hue and rig.get_instance_id()==instance,"Raw native full/partial hues retain exact bits and skeleton")
		check(material.get_shader_parameter("use_hue") and bool(material.get_shader_parameter("partial_hue"))==bool(hue&0x8000),"Actual palette and partial flag bound")
		check(pixels>100,"Native colour visibly changes actual Solen surface");hues.append({"hue":hue,"changed_pixels":pixels});hue_images.append(image);image.save_png(ProjectSettings.globalize_path(output+"/hue-%04x.png"%hue))
	var partial_pixels:=difference(hue_images[0],hue_images[1]);check(partial_pixels>100,"Authored body-only partial dye remains distinct from full-body tint")
	actor.apply_server_appearance({"body":body,"hue":0},[]);var material:=mesh.get_active_material(0) as ShaderMaterial;var original:=material.get_shader_parameter("source_atlas") as Texture2D;var detailed:=material.get_shader_parameter("albedo_texture") as Texture2D
	check(original.get_width()==256 and original.get_height()==256 and detailed.get_width()>1000,"Original256square atlas and detailed private Solen RGB both bound")
	var original_image:=original.get_image();var opaque:=true
	if original_image.is_compressed():check(original_image.decompress()==OK,"Bound original atlas decompresses for actual texel inspection")
	for y in original_image.get_height():
		for x in original_image.get_width():opaque=opaque and original_image.get_pixel(x,y).a==1.
	check(original_image.get_size()==Vector2i(256,256),"Actual original source atlas dimensions retained")
	material.set_shader_parameter("albedo_texture",original);var old_rgb:=await capture();material.set_shader_parameter("albedo_texture",detailed);var modern_rgb:=await capture();var texture_pixels:=difference(old_rgb,modern_rgb);check(texture_pixels>100,"Private natural Solen atlas changes the retained source UV surface")
	var wide:=camera.transform;var head:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 head")).origin);camera.position=head+Vector3(.65,.2,1.);camera.look_at(head);camera.size=.8;var relief:=await capture();relief.save_png(ProjectSettings.globalize_path(output+"/head.png"));material.set_shader_parameter("detail_strength",0.);var flat:=await capture();var relief_pixels:=difference(relief,flat);check(relief_pixels>10,"Authored albedo relief makes an actual measured lighting difference");material.set_shader_parameter("detail_strength",.22);camera.transform=wide;camera.size=5.
	var source_cutout_pixels:=0
	material.set_shader_parameter("alpha_probe",true)
	for angle in [0.,-.8,PI/2.,PI]:
		actor.rotation.y=angle;material.set_shader_parameter("use_source_alpha",true);var masked:=await capture();material.set_shader_parameter("use_source_alpha",false);var solid:=await capture()
		for y in range(0,solid.get_height(),2):
			for x in range(0,solid.get_width(),2):
				if solid.get_pixel(x,y).g-masked.get_pixel(x,y).g>.08:source_cutout_pixels+=1
	material.set_shader_parameter("alpha_probe",false);material.set_shader_parameter("use_source_alpha",true);actor.rotation.y=0.
	check(source_cutout_pixels==0 if opaque else source_cutout_pixels>10,"Bound source alpha matches actual opaque/cutout input")
	visual.play("Idle",0.);visual.animator.seek(0.,true);visual.animator.pause()
	if "--appearance-only" in OS.get_cmdline_user_args():print("SOURCE SOLEN APPEARANCE: ",checks," / ",failures," failures; relief ",relief_pixels,"px");actor.free();quit(1 if failures else 0);return
	var phases: Array[float]=[0.,.1173,.2371,.3871,.4619,.5831,.7231,.8371,1.];var references: Dictionary={}
	for clip: String in CATEGORIES:
		var rows: Dictionary={}
		for phase: float in phases:
			visual.play(clip,0.);visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();for frame in 2:await process_frame
			var soles: Array=visual.contact.source_lifts();var protected: Dictionary={}
			for bone in rig.get_bone_count():
				if not rig.get_bone_name(bone).begins_with("legbone "):protected[bone]=rig.get_bone_global_pose(bone).origin
			rows[str(phase)]={"soles":soles,"lengths":lengths(rig,visual.contact.feet),"protected":protected}
		references[clip]=rows;visual.play(clip,0.);visual.animator.seek(visual.animator.current_animation_length*(1. if clip in ["Death","Death2","LieDown"] else .3871),true);visual.animator.pause();var image:=await capture();image.save_png(ProjectSettings.globalize_path(output+"/"+clip+".png"))
	var modified: Dictionary={"serial":0,"capture_skin":false};var whole_skin:=Ground.skin_points(mesh,rig);var support_plane: Dictionary={"origin":Vector3.ZERO,"normal":Vector3.UP}
	visual.contact.modification_processed.connect(func():
		var soles: Array=[]
		for foot: Dictionary in visual.contact.feet:soles.append(visual.contact.sole(foot))
		var protected: Dictionary={}
		for bone in rig.get_bone_count():
			if not rig.get_bone_name(bone).begins_with("legbone "):protected[bone]=rig.get_bone_global_pose(bone).origin
		modified["protected"]=protected;modified["soles"]=soles;modified["lengths"]=lengths(rig,visual.contact.feet);modified["serial"]=int(modified.serial)+1
		if bool(modified.capture_skin):modified["minimum_gap"]=Ground.minimum_plane_gap(whole_skin,rig,rig.global_transform,support_plane.origin,support_plane.normal);modified["box"]=Geometry.deformed_bounds(mesh,rig);modified["bounds"]=visual.get_meta("pick_bounds");modified["capture_skin"]=false
	)
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(10.,.1,10.);collider.shape=box;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground);actor.set_physics_process(true);visual.set_process(true);visual.set_physics_process(true);visual.contact.active=true
	var terrain: Array=[];var maximum_planted_gap:=0.;var maximum_lift_error:=0.;var lifted:=0;var planted:=0;var grounded_gait_cases:=0;var maximum_protected_error:=0.;var minimum_skin_gap:=INF
	for slope in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,-.08)]:
		for yaw in [0.,PI/2.]:
			for clip: String in CATEGORIES:
				for phase: float in phases:
					var prior:=int(modified.serial);ground.position.y=-.15 if yaw==0. else .18;ground.rotation=Vector3(slope.x,0.,slope.y);support_plane.origin=ground.position;support_plane.normal=ground.basis.y;actor.rotation.y=yaw;visual.current_clip=clip;visual.action_remaining=1000.;visual.dead=false;visual.contact.enabled=clip not in ["Death","Death2","LieDown"];visual.play(clip,0.);var frames:=0
					for frame in 30:
						await physics_frame;actor.animate(false,yaw,1./60.,0.);visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();await process_frame;frames=frame+1;var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1))
						if frame<2 or hit.is_empty() or absf(actor.ground_offset-float(hit.position.y))>.002:continue
						var normal: Vector3=(visual.global_basis.inverse()*hit.normal).normalized();var target: Basis=Basis.from_euler(Vector3(clampf(atan2(normal.z,normal.y),-.2,.2),0.,clampf(-atan2(normal.x,normal.y),-.15,.15)))*visual.source_model_basis
						if visual.model.basis.orthonormalized().get_rotation_quaternion().angle_to(target.get_rotation_quaternion())<.002:break
					modified.capture_skin=true
					for frame in 3:await process_frame
					var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1));check(not hit.is_empty(),"Real finite raised/lowered collider sampled")
					if hit.is_empty():continue
					check(actor.global_position.is_zero_approx() and absf(actor.ground_offset-float(hit.position.y))<.015,"Support changes presentation while preserving native coordinates")
					check(int(modified.serial)>prior and not bool(modified.capture_skin),"Fresh actual render-stage skeletal skin captured")
					var reference: Dictionary=references[clip][str(phase)];var feet: Array=[];var lowest_gait_gap:=INF
					for i in visual.contact.feet.size():
						var point: Vector3=modified.soles[i];var gap: float=hit.normal.dot(point-hit.position);var authored:=float(reference.soles[i]);var current: Array=modified.lengths[i];var baseline: Array=reference.lengths[i]
						if clip not in ["Death","Death2","LieDown"]:
							if authored>=.03:lifted+=1;maximum_lift_error=maxf(maximum_lift_error,absf(gap-authored));check(absf(gap-authored)<.009,"Actual source foot lift retained: %s/%s gap%f source%f"%[clip,phase,gap,authored])
							elif authored<.015:planted+=1;maximum_planted_gap=maxf(maximum_planted_gap,absf(gap));check(absf(gap)<.008,"Actual planted source sole within8mm: %s/%s gap%f"%[clip,phase,gap])
							else:check(gap>-.008 and gap<authored+.009,"Transition source foot bounded")
						lowest_gait_gap=minf(lowest_gait_gap,gap);check(absf(float(current[0])-float(baseline[0]))<.001 and absf(float(current[1])-float(baseline[1]))<.001,"Terrain support retains each actual same-phase original limb length");feet.append({"foot":i,"gap":gap,"source_lift":authored})
					if clip in ["Walk","Run"] and absf(lowest_gait_gap)<.008:grounded_gait_cases+=1
					var protected_error:=0.
					for bone: int in reference.protected:protected_error=maxf(protected_error,(modified.protected[bone] as Vector3).distance_to(reference.protected[bone]))
					maximum_protected_error=maxf(maximum_protected_error,protected_error);check(protected_error<.00001,"Six-leg support preserves same-phase source torso/arms/antennae/mandible joints")
					minimum_skin_gap=minf(minimum_skin_gap,float(modified.minimum_gap));check(float(modified.minimum_gap)>-.008,"Complete actual render-stage skin stays above the support plane");var actual: AABB=modified.box;var bounds: AABB=modified.bounds;check(actual.position.is_finite() and actual.size.is_finite(),"Complete render-stage source skin finite");check((visual.global_transform*bounds).grow(.001).encloses(actual),"Weighted final-pose bounds contain entire source skin");check(plate.global_position.y>actual.end.y+.015,"Actual nameplate clears complete source skin");check((pick_shape.global_transform*AABB(-pick_shape.shape.size*.5,pick_shape.shape.size)).grow(.001).encloses(actual),"Actual mobile selection collider encloses rendered skin")
					terrain.append({"clip":clip,"phase":phase,"slope":str(slope),"yaw":yaw,"height":ground.position.y,"feet":feet,"minimum_skin_gap_m":modified.minimum_gap,"settling_frames":frames})
	check(lifted>20 and planted>20 and grounded_gait_cases==108,"All six planes/phases retain relative source swing and grounded walking/running support")
	actor.set_physics_process(false);visual.set_physics_process(false);visual.contact.active=false;ground.free();actor.free();var cadavers: Array=[]
	for hue in [0,53,0x8035]:
		var corpse:=Corpses.build(body,hue);check(corpse!=null,"Native0x2006/original Solen body static corpse exists")
		if corpse==null:continue
		viewport.add_child(corpse);var bounds: AABB=corpse.get_meta("corpse_bounds");check(corpse.get_meta("corpse_body")==body and corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("native_hue")==hue,"Static corpse retains exact native body/graphic/raw hue");check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and bounds.position.y==0. and bounds.size.y<float(record.stats.original.height_m)*1.05,"Complete source collapse frozen without a rig and grounded");var image:=await capture();image.save_png(ProjectSettings.globalize_path(output+"/corpse-%04x.png"%hue));cadavers.append({"hue":hue,"height":bounds.size.y});corpse.free()
	var runtime: Dictionary={}
	for name in INPUTS:runtime["res://Presentation/"+name]=FileAccess.get_sha256("res://Presentation/"+name)
	var asset:=Registry.asset_path(record);var report:={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"terrain":terrain,"hues":hues,"cadavers":cadavers,"maximum_planted_gap_m":maximum_planted_gap,"maximum_lift_error_m":maximum_lift_error,"lifted_foot_cases":lifted,"planted_foot_cases":planted,"grounded_gait_cases":grounded_gait_cases,"maximum_protected_joint_error_m":maximum_protected_error,"minimum_skin_gap_m":minimum_skin_gap,"partial_full_difference_pixels":partial_pixels,"modern_texture_pixels":texture_pixels,"relief_pixels":relief_pixels,"original_atlas_opaque":opaque,"source_cutout_pixels":source_cutout_pixels,"runtime_sha256":runtime,"preparation_sha256":FileAccess.get_sha256(preparation),"kind":kind,"body":body,"ground_lookup_sha256":FileAccess.get_sha256(str(record.ground_lookup)),"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import"),"scope":"Actual in-memory owned renderer factory/registered Solen avatar, original42joint rig and source categories; natural private RGB/authored relief/full-partial dyes, actual render-stage relative source six-leg swing/limb lengths/protected torso motion, dynamic picking/nameplate, finite support planes and native static corpse. No accepted route, real-server/original particle/full choreography/no-slip/final art certification."};FileAccess.open(output+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("SOURCE SOLEN PRESENTATION: ",checks," / ",failures," failures / ",terrain.size()," poses / ",grounded_gait_cases," grounded gait cases");quit(1 if failures else 0)
