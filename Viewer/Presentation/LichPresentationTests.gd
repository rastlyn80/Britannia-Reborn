extends SceneTree
## Actual candidate registry/avatar, render-stage skin and finite collider tests.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Visual=preload("res://Presentation/LichVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Categories=preload("res://Presentation/LichActionTests.gd").CATEGORIES
const INPUTS=["LichPresentationTests.gd","LichVisual.gd","LichGrip.gd","LichMaterial.gd","LichSurface.gdshader","SmallSnakeVisual.gd","CreatureRegistry.gd","CreatureVisual.gd","MeasuredCreatureSupport.gd","SourceBipedSupport.gd","SourceMountContact.gd","FootContact.gd","OstardVisual.gd","OstardSurface.gdshader","HumanAvatar.gd","LegacyAvatar.gd","HumanHue.gd","HumanActions.gd","MountVisual.gd","AnimalVisual.gd","AnimalPoseLibrary.gd","SkinGeometry.gd","CorpseModels.gd"]
var checks:=0
var failures:=0
var viewport: SubViewport
func _initialize() -> void:
	create_timer(900.).timeout.connect(func():push_error("Lich presentation deadline");quit(1));call_deferred("run")
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
		var a:=rig.to_global(rig.get_bone_global_pose(foot.a).origin);var b:=rig.to_global(rig.get_bone_global_pose(foot.b).origin);var c:=rig.to_global(rig.get_bone_global_pose(foot.c).origin)
		result.append([a.distance_to(b),b.distance_to(c)])
	return result
func run() -> void:
	var preparation:="res://local-art/creatures/liches/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation));Registry.load_index()
	for record: Dictionary in prep.models:
		for identity: Dictionary in record.bodies:Registry.entries[int(identity.body)]=record
	var output:="res://../outputs/creatures/liches/presentation";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=Vector2i(1000,750);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.;viewport.add_child(camera);camera.position=Vector3(3.,2.,5.);camera.look_at(Vector3(0.,1.25,0.))
	var models: Array=[];var terrain: Array=[];var cadavers: Array=[];var maximum_planted_gap:=0.;var lifted:=0;var planted:=0
	for record: Dictionary in prep.models:
		var body:=int(record.bodies[0].body);var kind: String=record.kind
		var actor:=Avatar.new();actor.initial_body=body;actor.set_meta("own",true);var plate:=Node3D.new();plate.name="Nameplate";actor.add_child(plate)
		var picker:=StaticBody3D.new();picker.set_meta("server_mobile",body);picker.collision_layer=2;var pick_shape:=CollisionShape3D.new();pick_shape.shape=BoxShape3D.new();picker.add_child(pick_shape);actor.add_child(picker)
		viewport.add_child(actor);actor.apply_server_appearance({"body":body,"hue":0},[]);actor.set_physics_process(false)
		var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false;visual.contact.active=false
		var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.body_mesh
		check(visual is Visual and visual.contact.feet.size()==2 and rig.get_bone_count()==36,"Actual registry creates original36joint Lich with two source feet")
		check(visual.native_body==body and visual.action_profile=="monster","Native Lich body/profile reaches actual avatar")
		visual.play("Idle",0.);visual.animator.seek(0.,true);visual.animator.pause();var base:=await capture();base.save_png(ProjectSettings.globalize_path(output+"/"+kind+"-default.png"))
		var staff_pixels:=0;var initial_camera:=camera.transform
		for angle in 3:
			camera.position=Vector3(5.*sin(float(angle)*TAU/3.),2.,5.*cos(float(angle)*TAU/3.));camera.look_at(Vector3(0.,1.25,0.));var with_staff:=await capture();with_staff.save_png(ProjectSettings.globalize_path(output+"/"+kind+"-staff-%s.png"%angle));visual.staff.visible=false;var without_staff:=await capture();visual.staff.visible=true;staff_pixels+=difference(with_staff,without_staff)
		camera.transform=initial_camera
		check(staff_pixels>25,"Original source staff is actually visible from multiple camera angles")
		print("LICH STAFF PIXELS ",kind,": ",staff_pixels," position ",visual.staff.global_position," meshes ",visual.staff_meshes().size())
		if "--staff-probe" in OS.get_cmdline_user_args():actor.free();quit(1 if failures else 0);return
		var instance:=rig.get_instance_id();var hues: Array=[];var hue_images: Array[Image]=[]
		for hue in [53,0x8035,0x901]:
			actor.apply_server_appearance({"body":body,"hue":hue},[]);var image:=await capture();var pixels:=difference(base,image);var material:=mesh.get_active_material(0) as ShaderMaterial
			check(visual.native_hue==hue and rig.get_instance_id()==instance,"Raw full/partial hues preserve original skeleton")
			check(material.get_shader_parameter("use_hue") and bool(material.get_shader_parameter("partial_hue"))==bool(hue&0x8000),"Actual native palette/partial flag bound")
			check(pixels>100,"Native hue changes visible Lich cloth/skin")
			hues.append({"hue":hue,"changed_pixels":pixels});hue_images.append(image);image.save_png(ProjectSettings.globalize_path(output+"/"+kind+"-hue-%04x.png"%hue))
		var partial_pixels:=difference(hue_images[0],hue_images[1]);check(partial_pixels>100,"Authored cloth-only dye remains distinct from full-body hue")
		actor.apply_server_appearance({"body":body,"hue":0},[]);var material:=mesh.get_active_material(0) as ShaderMaterial;var original:=material.get_shader_parameter("source_atlas") as Texture2D
		check(original.get_width()==128 and original.get_height()==128 and material.get_shader_parameter("albedo_texture").get_width()>1000,"Original128square cutouts and detailed private atlas both bound")
		var masked:=await capture();material.set_shader_parameter("use_source_alpha",false);var solid:=await capture();var cutout_pixels:=difference(masked,solid);check(cutout_pixels>25,"Actual original tornrobe/hair alpha removes visible filled polygons");material.set_shader_parameter("use_source_alpha",true)
		var modern_texture: Texture2D=material.get_shader_parameter("albedo_texture");material.set_shader_parameter("albedo_texture",original);var original_rgb:=await capture();material.set_shader_parameter("albedo_texture",modern_texture);var detailed:=await capture();var texture_pixels:=difference(original_rgb,detailed);check(texture_pixels>100,"Modern private cloth/skin RGB changes actual original UV surface")
		var accent_pixels:=0
		if kind=="liche_liche_lord_retro":
			material.set_shader_parameter("use_accent",false);var without_accent:=await capture();accent_pixels=difference(detailed,without_accent);check(accent_pixels>25,"Lord authored crimson trim remains visibly distinct");material.set_shader_parameter("use_accent",true)
		var references: Dictionary={};var phases: Array[float]=[0.,.1573,.3871,.7231,1.]
		for clip: String in Categories:
			var rows: Dictionary={}
			for phase: float in phases:
				visual.play(clip,0.);visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();for frame in 2:await process_frame
				var soles: Array=[]
				for foot: Dictionary in visual.contact.feet:soles.append(visual.contact.sole(foot).y)
				rows[str(phase)]={"soles":soles,"lengths":lengths(rig,visual.contact.feet)}
			references[clip]=rows
			visual.play(clip,0.);visual.animator.seek(visual.animator.current_animation_length*.3871,true);visual.animator.pause();var image:=await capture();image.save_png(ProjectSettings.globalize_path(output+"/"+kind+"-"+clip+".png"))
		var modified: Dictionary={"serial":0,"capture_skin":false}
		visual.contact.modification_processed.connect(func():
			var soles: Array=[]
			for foot: Dictionary in visual.contact.feet:soles.append(visual.contact.sole(foot))
			modified["soles"]=soles;modified["lengths"]=lengths(rig,visual.contact.feet);modified["serial"]=int(modified.serial)+1
			if bool(modified.capture_skin):modified["box"]=Geometry.deformed_bounds(mesh,rig);modified["pick_bounds"]=visual.get_meta("pick_bounds");modified["staff_transform"]=visual.staff.global_transform;modified["staff_gap"]=visual.staff_gap(visual.staff.global_transform,visual.support_normal());modified["capture_skin"]=false
		)
		var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(10.,.1,10.);collider.shape=box;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground)
		actor.set_physics_process(true);visual.set_process(true);visual.set_physics_process(true);visual.contact.active=true
		for slope in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,-.08)]:
			for yaw in [0.,PI/2.]:
				for clip: String in Categories:
					for phase: float in phases:
						var prior:=int(modified.serial);ground.position.y=-.15 if yaw==0. else .18;ground.rotation=Vector3(slope.x,0.,slope.y);actor.rotation.y=yaw;visual.current_clip=clip;visual.action_remaining=1000.;visual.dead=false;visual.contact.enabled=clip not in ["Death","LieDown"];visual.play(clip,0.)
						var frames:=0
						for frame in 30:
							await physics_frame;actor.animate(false,yaw,1./60.,0.);visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();await process_frame;frames=frame+1
							var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1))
							if frame<2 or hit.is_empty() or absf(actor.ground_offset-float(hit.position.y))>.002:continue
							var normal: Vector3=(visual.global_basis.inverse()*hit.normal).normalized();var target: Basis=Basis.from_euler(Vector3(clampf(atan2(normal.z,normal.y),-.2,.2),0.,clampf(-atan2(normal.x,normal.y),-.15,.15)))*visual.source_model_basis
							if visual.model.basis.orthonormalized().get_rotation_quaternion().angle_to(target.get_rotation_quaternion())<.002:break
						modified.capture_skin=true
						for frame in 3:await process_frame
						var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1));check(not hit.is_empty(),"Real finite raised/lowered collider sampled")
						if hit.is_empty():continue
						check(actor.global_position.is_zero_approx() and absf(actor.ground_offset-float(hit.position.y))<.015,"Terrain support preserves native world coordinates")
						check(int(modified.serial)>prior and not bool(modified.capture_skin),"Fresh render-stage modified source skin captured")
						var reference: Dictionary=references[clip][str(phase)];var feet: Array=[]
						for i in visual.contact.feet.size():
							var point: Vector3=modified.soles[i];var gap: float=hit.normal.dot(point-hit.position);var authored:=float(reference.soles[i]);var current: Array=modified.lengths[i];var baseline: Array=reference.lengths[i]
							if clip not in ["Death","LieDown"]:
								if authored>=.03:lifted+=1;check(absf(gap-authored)<.009,"Lifted source foot preserved: %s/%s/%s gap%f lift%f"%[kind,clip,phase,gap,authored])
								elif authored<.015:planted+=1;maximum_planted_gap=maxf(maximum_planted_gap,absf(gap));check(absf(gap)<.008,"Planted source foot within8mm: %s/%s/%s gap%f"%[kind,clip,phase,gap])
								else:check(gap>-.008 and gap<authored+.009,"Transition sole bounded")
							check(absf(float(current[0])-float(baseline[0]))<.001 and absf(float(current[1])-float(baseline[1]))<.001,"Measured source thigh/calf lengths preserved")
							feet.append({"foot":i,"gap":gap,"authored_lift":authored})
						var actual: AABB=modified.box;var bounds: AABB=modified.pick_bounds
						check(actual.position.is_finite() and actual.size.is_finite() and actual.size.length()>.5,"Actual complete render-stage skin finite")
						check((visual.global_transform*bounds).grow(.001).encloses(actual),"Render-stage full skin lies inside dynamic picking bounds")
						check(plate.global_position.y>actual.end.y+.015,"Actual nameplate clears complete source skin")
						check(pick_shape.shape.size.is_equal_approx((visual.get_meta("pick_bounds") as AABB).size),"Actual dynamic selection collider tracks amended source skin/prop")
						check(float(modified.staff_gap)>-.008,"Actual rendered staff stays above source support plane")
						terrain.append({"kind":kind,"clip":clip,"phase":phase,"slope":str(slope),"yaw":yaw,"height":ground.position.y,"feet":feet,"staff_gap":modified.staff_gap,"settling_frames":frames})
		actor.set_physics_process(false);visual.set_physics_process(false);visual.contact.active=false;ground.free();actor.free()
		for identity: Dictionary in record.bodies:
			for hue in [0,53,0x8035]:
				var corpse:=Corpses.build(int(identity.body),hue);check(corpse!=null,"Native0x2006/body Lich corpse exists")
				if corpse==null:continue
				viewport.add_child(corpse);var bounds: AABB=corpse.get_meta("corpse_bounds")
				check(corpse.get_meta("corpse_body")==int(identity.body) and corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("native_hue")==hue,"Static corpse retains exact native body/graphic/raw hue")
				check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and bounds.position.y==0. and bounds.size.y<1.1,"Grounded corpse retains no rig/upright staff spike")
				var image:=await capture();image.save_png(ProjectSettings.globalize_path(output+"/corpse-%04x-%04x.png"%[int(identity.body),hue]));cadavers.append({"body":identity.body,"hue":hue,"height":bounds.size.y});corpse.free()
		models.append({"kind":kind,"body":body,"hues":hues,"staff_visible_pixels":staff_pixels,"partial_full_difference_pixels":partial_pixels,"source_cutout_pixels":cutout_pixels,"modern_texture_pixels":texture_pixels,"lord_accent_pixels":accent_pixels,"asset_sha256":FileAccess.get_sha256(Registry.asset_path(record)),"import_sha256":FileAccess.get_sha256(Registry.asset_path(record)+".import")})
	check(lifted>20 and planted>20,"Terrain includes actual lifted and planted source feet")
	var runtime: Dictionary={}
	for name in INPUTS:runtime["res://Presentation/"+name]=FileAccess.get_sha256("res://Presentation/"+name)
	var report:={"checks":checks,"failures":failures,"models":models,"terrain":terrain,"cadavers":cadavers,"maximum_planted_gap_m":maximum_planted_gap,"lifted_foot_cases":lifted,"planted_foot_cases":planted,"runtime_sha256":runtime,"renderer":RenderingServer.get_current_rendering_method(),"preparation_sha256":FileAccess.get_sha256(preparation),"scope":"Actual in-memory candidate registry and avatar; two original skins/36joint rigs, source alpha/detailed RGB, authored Lord accent/full/partial dyes, render-stage finite-plane source lift/limb lengths, dynamic picking/nameplate, held original prop and static corpses. Body82 compatibility only. No accepted route/native-server/original full choreography/autonomous gameplay/final art claim."}
	FileAccess.open(output+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("LICH PRESENTATION: ",checks," / ",failures," failures / ",terrain.size()," terrain poses / ",cadavers.size()," corpse variants");quit(1 if failures else 0)
