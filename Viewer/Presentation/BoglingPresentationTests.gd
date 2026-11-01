extends SceneTree
## Actual registered avatar: preserve short source steps while planting soles.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Biped=preload("res://Presentation/BoglingVisual.gd")
const Support=preload("res://Presentation/BoglingSupport.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const INPUTS=["BoglingPresentationTests.gd","BoglingVisual.gd","BoglingSupport.gd","BoglingSurface.gdshader","MeasuredCreatureVisual.gd","MeasuredCreatureSupport.gd","SourceBipedVisual.gd","SourceBipedSupport.gd","CreatureRegistry.gd","CreatureVisual.gd","SourceMountContact.gd","FootContact.gd","OstardVisual.gd","OstardSurface.gdshader","HumanAvatar.gd","LegacyAvatar.gd","HumanHue.gd","HumanActions.gd","MountVisual.gd","AnimalVisual.gd","AnimalPoseLibrary.gd","SkinGeometry.gd","CorpseModels.gd"]
var checks:=0
var failures:=0
var viewport: SubViewport
var kind:="bogling"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):kind=arg.trim_prefix("--kind=")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<25:push_error(label)
func capture() -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw;return viewport.get_texture().get_image()
func difference(a: Image,b: Image,threshold: float=.025) -> int:
	var count:=0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var d:=a.get_pixel(x,y)-b.get_pixel(x,y)
			if absf(d.r)+absf(d.g)+absf(d.b)>threshold:count+=1
	return count
func lengths(rig: Skeleton3D,feet: Array) -> Array:
	var result: Array=[]
	for foot: Dictionary in feet:
		var a:=rig.to_global(rig.get_bone_global_pose(foot.a).origin);var b:=rig.to_global(rig.get_bone_global_pose(foot.b).origin);var c:=rig.to_global(rig.get_bone_global_pose(foot.c).origin)
		result.append([a.distance_to(b),b.distance_to(c)])
	return result
func run() -> void:
	var family:="boglings";var preparation:="res://local-art/bogling/preparation.json";var candidate_path:="res://Art/Creatures/index.json" if not Registry.entry(779).is_empty() and Registry.asset_path(Registry.entry(779)).begins_with("res://Art/") else "res://local-art/bogling/candidate.json";var record: Dictionary=Registry.entry(779) if candidate_path=="res://Art/Creatures/index.json" else JSON.parse_string(FileAccess.get_file_as_string(candidate_path));var body:=779
	Registry.load_index();Registry.entries[body]=record
	var output:="res://../outputs/creatures/bogling-trial";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=Vector2i(1000,750);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.7;viewport.add_child(camera);camera.position=Vector3(2.,1.3,3.);camera.look_at(Vector3(0.,.62,0.))
	var actor:=Avatar.new();actor.initial_body=body;actor.set_meta("own",true);var plate:=Node3D.new();plate.name="Nameplate";actor.add_child(plate);viewport.add_child(actor)
	actor.apply_server_appearance({"body":body,"hue":0},[]);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false;visual.contact.active=false
	var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
	var modified: Dictionary={"serial":0}
	# Godot restores animation poses after passing modified bones to the skin.
	# Capture at the documented modifier signal, while those final poses exist.
	visual.contact.modification_processed.connect(func():
		var soles: Array=[]
		for foot: Dictionary in visual.contact.feet:soles.append(visual.contact.sole(foot))
		modified["soles"]=soles;modified["lengths"]=lengths(rig,visual.contact.feet);modified["serial"]=int(modified.serial)+1
	)
	check(visual is Biped and visual.contact is Support and visual.contact.feet.size()==(4 if record.get("limb_support","")=="quadruped" else 2),"Actual registered avatar configures all measured source limbs")
	check(visual.native_body==body and visual.action_profile==record.profile and rig.get_bone_count()==int(record.stats.original.bones),"Native identity/profile and all original source mesh bones retained")
	visual.play("Idle",0.);visual.animator.seek(0.,true);visual.animator.pause();var base:=await capture();base.save_png(ProjectSettings.globalize_path(output+"/default.png"))
	var material:=mesh.get_active_material(0) as ShaderMaterial
	check(bool(material.get_shader_parameter("use_normal")) and material.get_shader_parameter("normal_texture")!=null,"Original source normal map is bound")
	material.set_shader_parameter("use_normal",false);var flat:=await capture();var normal_pixels:=difference(base,flat,.005)
	check(normal_pixels>100,"Original normal map changes actual rendered bark lighting")
	flat.save_png(ProjectSettings.globalize_path(output+"/without-normal.png"));material.set_shader_parameter("use_normal",true)
	check(material!=null and material.get_shader_parameter("albedo_texture")!=null,"Original independent-donor UV atlas is bound on actual source mesh")
	var texture:=material.get_shader_parameter("albedo_texture") as Texture2D;check(texture.get_width()==2048 and texture.get_height()==2048,"Original atlas resolution retained")
	var hues: Array=[];var instance:=rig.get_instance_id()
	for hue in [53,0x8035,0x901]:
		actor.apply_server_appearance({"body":body,"hue":hue},[]);var image:=await capture();var pixels:=difference(base,image)
		check(visual.native_hue==hue and rig.get_instance_id()==instance,"Raw full/partial hue preserves rig and exact bits")
		var dyed:=mesh.get_active_material(0) as ShaderMaterial
		check(dyed.get_shader_parameter("use_hue") and bool(dyed.get_shader_parameter("partial_hue"))==bool(hue&0x8000),"Actual hue palette and partial flag are bound")
		if hue==53:check(pixels>100,"Full native dye changes actual visible creature skin")
		hues.append({"hue":hue,"changed_pixels":pixels});image.save_png(ProjectSettings.globalize_path(output+"/hue-%04x.png"%hue))
	actor.apply_server_appearance({"body":body,"hue":0},[])
	for category in ["Walk","Run"]:
		visual.play(category,0.)
		for phase in [.25,.5,.75]:
			visual.animator.seek(float(visual.animator.current_animation_length)*phase,true);visual.animator.pause()
			var image:=await capture();image.save_png(ProjectSettings.globalize_path(output+"/"+category.to_lower()+"-"+str(phase)+".png"))
	var action_skins: Array=[]
	for category: String in visual.animator.get_animation_list():
		visual.play(category,0.)
		for step in 17:
			var phase:=float(step)/16.;visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();rig.force_update_all_bone_transforms();visual.update_landmarks()
			var box:=Geometry.deformed_bounds(mesh,rig)
			check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.1 and box.size.length()<6.,"Complete saved action skin is finite and nonempty")
			check((visual.global_transform*(visual.get_meta("pick_bounds") as AABB)).grow(.01).encloses(box),"Full action skin lies inside the conservative picking envelope")
			check(float(visual.get_meta("nameplate_height"))>box.end.y+.015,"Animated upper landmarks clear the complete action skin")
			action_skins.append({"clip":category,"phase":phase,"position":[box.position.x,box.position.y,box.position.z],"size":[box.size.x,box.size.y,box.size.z]})
	check(is_equal_approx(float(actor.get_meta("camera_height")),float(record.camera_height)),"Source body uses declared camera scale")
	# Reference the actual unmodified imported feet/segments at each gait pose.
	var references: Dictionary={};var phases: Array=[0.,.125,.25,.375,.5,.625,.75,.875]
	var supported_clips: Array[String]=["Idle","Walk","Run"]
	for action: String in ["Attack","Cast","Pillage","Stomp"]:
		if visual.animator.has_animation(action):supported_clips.append(action)
	for clip: String in supported_clips:
		var rows: Dictionary={}
		for phase: float in ([0.] if clip=="Idle" else phases if clip in ["Walk","Run"] else [.2,.35,.5]):
			visual.play(clip,0.);visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();for frame in 2:await process_frame
			var soles: Array=[]
			for foot: Dictionary in visual.contact.feet:soles.append(visual.contact.sole(foot).y)
			rows[str(phase)]={"soles":soles,"lengths":lengths(rig,visual.contact.feet)}
		references[clip]=rows
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(10.,.1,10.);collider.shape=box;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground)
	actor.set_physics_process(true);visual.set_process(true);visual.set_physics_process(true);visual.contact.active=true
	var terrain: Array=[];var lifted:=0;var planted:=0
	for slope in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,-.08)]:
		for yaw in [0.,PI/2.]:
			for clip: String in supported_clips:
				for phase: float in ([0.] if clip=="Idle" else phases if clip in ["Walk","Run"] else [.2,.35,.5]):
					var prior_sample:=int(modified.serial)
					ground.position.y=-.15 if yaw==0. else .18;ground.rotation=Vector3(slope.x,0.,slope.y);visual.current_clip=clip;visual.action_remaining=1000.;visual.dead=false;visual.contact.enabled=true;visual.play(clip,0.)
					for frame in 25:
						await physics_frame;actor.animate(false,yaw,1./60.,0.);visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();await process_frame
					var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1))
					check(not hit.is_empty(),"Real raised/lowered sloped finite collider sampled")
					if hit.is_empty():continue
					check(actor.global_position.is_zero_approx() and absf(actor.ground_offset-float(hit.position.y))<.015,"Support adjusts presentation while preserving native coordinates")
					check(int(modified.serial)>prior_sample,"Actual render-stage modifier produced a fresh corrected skin sample")
					var reference: Dictionary=references[clip][str(phase)];var current_lengths: Array=modified.lengths;var feet: Array=[]
					for i in visual.contact.feet.size():
						var point: Vector3=modified.soles[i];var gap: float=hit.normal.dot(point-hit.position);var authored:=float(reference.soles[i])
						if authored>=.03:lifted+=1;check(absf(gap-authored)<.009,"Actual avatar preserves lifted source foot above terrain")
						elif authored<.015:planted+=1;check(absf(gap)<.008,"Actual planted source sole stays within8mm")
						else:check(gap>-.008 and gap<authored+.009,"Transition foot stays bounded")
						check(absf(float(current_lengths[i][0])-float(reference.lengths[i][0]))<.001 and absf(float(current_lengths[i][1])-float(reference.lengths[i][1]))<.001,"Support preserves original thigh/calf/foot segment lengths")
						feet.append({"foot":i,"gap":gap,"authored_lift":authored})
					var actual_box:=Geometry.deformed_bounds(mesh,rig);check(plate.global_position.y>actual_box.end.y+.015,"Nameplate stays above the actual animated source skin")
					check((visual.global_transform*(visual.get_meta("pick_bounds") as AABB)).grow(.01).encloses(actual_box),"Declared selection envelope contains the actual skin")
					terrain.append({"clip":clip,"phase":phase,"slope":str(slope),"yaw":yaw,"height":ground.position.y,"feet":feet})
	check(lifted>=20 and planted>=20,"Finite-plane cases include lifted and planted feet")
	actor.set_physics_process(false);visual.set_physics_process(false);visual.contact.active=false;ground.free();actor.free()
	for hue in [0,53,0x8035]:
		var corpse:=Corpses.build(body,hue);check(corpse!=null,"Native0x2006/body corpse exists")
		if corpse==null:continue
		viewport.add_child(corpse);var bounds: AABB=corpse.get_meta("corpse_bounds")
		check(corpse.get_meta("corpse_body")==body and corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("native_hue")==hue,"Native cadaver preserves native body/graphic/hue")
		check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and bounds.position.y==0. and bounds.size.y<float(record.stats.original.height_m),"Native cadaver is grounded static geometry")
		var image:=await capture();image.save_png(ProjectSettings.globalize_path(output+"/corpse-%04x.png"%hue));corpse.free()
	var runtime: Dictionary={}
	for name in INPUTS:runtime["res://Presentation/"+name]=FileAccess.get_sha256("res://Presentation/"+name)
	var asset:=Registry.asset_path(record);var report:={"test_sha256":FileAccess.get_sha256("res://Presentation/BoglingPresentationTests.gd"),"candidate_sha256":FileAccess.get_sha256(candidate_path),"normal_pixels":normal_pixels,"checks":checks,"failures":failures,"kind":kind,"body":body,"action_skins":action_skins,"terrain":terrain,"lifted_foot_cases":lifted,"planted_foot_cases":planted,"hues":hues,"renderer":RenderingServer.get_current_rendering_method(),"runtime_sha256":runtime,"preparation_sha256":FileAccess.get_sha256(preparation),"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import"),"scope":"Actual registered avatar, generated UV material, complete declared action skins, raw full/partial hue bindings, preserved lifted feet and limb lengths over finite terrain, conservative branch landmarks and native static corpse. Partial hue uses authored brown-bark selection; no original mask recovery, native server or arbitrary-terrain certification."}
	FileAccess.open(output+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("TREE CANDIDATE / "+kind+": ",checks," / ",failures," failures; ",terrain.size()," terrain poses; ",lifted," lifted feet");quit(1 if failures else 0)
