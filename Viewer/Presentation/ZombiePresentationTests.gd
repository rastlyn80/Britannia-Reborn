extends SceneTree
## Actual registered avatar: preserve short source steps while planting soles.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Biped=preload("res://Presentation/SourceBipedVisual.gd")
const Support=preload("res://Presentation/SourceBipedSupport.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const INPUTS=["ZombiePresentationTests.gd","SourceBipedVisual.gd","SourceBipedSupport.gd","CreatureRegistry.gd","CreatureVisual.gd","SourceMountContact.gd","FootContact.gd","OstardVisual.gd","OstardSurface.gdshader","HumanAvatar.gd","LegacyAvatar.gd","HumanHue.gd","HumanActions.gd","MountVisual.gd","AnimalVisual.gd","AnimalPoseLibrary.gd","SkinGeometry.gd","CorpseModels.gd"]
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
	var preparation:="res://local-art/creatures/walking/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation));var record: Dictionary=prep.models.filter(func(row: Dictionary):return row.kind=="walking_dead_zombie")[0]
	Registry.load_index();Registry.entries[3]=record
	var output:="res://../outputs/creatures/walking/zombie-presentation";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=Vector2i(1000,750);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.8;viewport.add_child(camera);camera.position=Vector3(2.,1.5,3.);camera.look_at(Vector3(0.,.85,0.))
	var actor:=Avatar.new();actor.initial_body=3;actor.set_meta("own",true);var plate:=Node3D.new();plate.name="Nameplate";actor.add_child(plate);viewport.add_child(actor)
	actor.apply_server_appearance({"body":3,"hue":0},[]);actor.set_physics_process(false)
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
	check(visual is Biped and visual.contact is Support and visual.contact.feet.size()==2,"Actual Zombie3 avatar uses only two measured source legs")
	check(visual.native_body==3 and visual.action_profile=="monster" and rig.get_bone_count()==34,"Native monster identity and all original mesh bones retained")
	visual.play("Idle",0.);visual.animator.seek(0.,true);visual.animator.pause();var base:=await capture();base.save_png(ProjectSettings.globalize_path(output+"/default.png"))
	var material:=mesh.get_active_material(0) as ShaderMaterial
	check(material!=null and material.get_shader_parameter("albedo_texture")!=null,"Generated UV atlas is bound on actual source mesh")
	var texture:=material.get_shader_parameter("albedo_texture") as Texture2D;check(texture.get_width()==1254 and texture.get_height()==1254,"Actual generated atlas resolution retained")
	var hues: Array=[];var instance:=rig.get_instance_id()
	for hue in [53,0x8035,0x901]:
		actor.apply_server_appearance({"body":3,"hue":hue},[]);var image:=await capture();var pixels:=difference(base,image)
		check(visual.native_hue==hue and rig.get_instance_id()==instance,"Raw full/partial hue preserves rig and exact bits")
		var dyed:=mesh.get_active_material(0) as ShaderMaterial
		check(dyed.get_shader_parameter("use_hue") and bool(dyed.get_shader_parameter("partial_hue"))==bool(hue&0x8000),"Actual hue palette and partial flag are bound")
		if hue==53:check(pixels>100,"Full native dye changes actual visible zombie skin")
		hues.append({"hue":hue,"changed_pixels":pixels});image.save_png(ProjectSettings.globalize_path(output+"/hue-%04x.png"%hue))
	actor.apply_server_appearance({"body":3,"hue":0},[])
	check(is_equal_approx(float(actor.get_meta("camera_height")),1.35),"Hunched source body uses declared camera scale")
	# Reference the actual unmodified imported feet/segments at each gait pose.
	var references: Dictionary={};var phases: Array=[0.,.125,.25,.375,.5,.625,.75,.875]
	for clip: String in ["Idle","Walk","Run"]:
		var rows: Dictionary={}
		for phase: float in ([0.] if clip=="Idle" else phases):
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
			for clip: String in ["Idle","Walk","Run"]:
				for phase: float in ([0.] if clip=="Idle" else phases):
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
					var head:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 head")).origin);check(absf(plate.global_position.y-head.y-.08)<.004,"Nameplate follows the actual hunched animated skull")
					terrain.append({"clip":clip,"phase":phase,"slope":str(slope),"yaw":yaw,"height":ground.position.y,"feet":feet})
	check(lifted>=20 and planted>=20,"Finite-plane cases include lifted and planted feet")
	actor.set_physics_process(false);visual.set_physics_process(false);visual.contact.active=false;ground.free();actor.free()
	for hue in [0,53,0x8035]:
		var corpse:=Corpses.build(3,hue);check(corpse!=null,"Native0x2006/amount3 zombie corpse exists")
		if corpse==null:continue
		viewport.add_child(corpse);var bounds: AABB=corpse.get_meta("corpse_bounds")
		check(corpse.get_meta("corpse_body")==3 and corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("native_hue")==hue,"Zombie cadaver preserves native body/graphic/hue")
		check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and bounds.position.y==0. and bounds.size.y<.7,"Zombie cadaver is grounded static geometry")
		var image:=await capture();image.save_png(ProjectSettings.globalize_path(output+"/corpse-%04x.png"%hue));corpse.free()
	var runtime: Dictionary={}
	for name in INPUTS:runtime["res://Presentation/"+name]=FileAccess.get_sha256("res://Presentation/"+name)
	var asset:="res://local-art/creatures/walking_dead_zombie-modern.gltf";var report:={"checks":checks,"failures":failures,"terrain":terrain,"lifted_foot_cases":lifted,"planted_foot_cases":planted,"hues":hues,"renderer":RenderingServer.get_current_rendering_method(),"runtime_sha256":runtime,"preparation_sha256":FileAccess.get_sha256(preparation),"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import"),"scope":"Actual registered avatar, generated UV material, raw full/partial hue bindings, preserved lifted feet and limb lengths over finite terrain, hunched skull anchor and native static corpse. Partial hue remains generic neutral-pixel heuristic; no original mask recovery, native server or arbitrary-terrain certification."}
	FileAccess.open(output+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("ZOMBIE PRESENTATION: ",checks," / ",failures," failures; ",terrain.size()," terrain poses; ",lifted," lifted feet");quit(1 if failures else 0)
