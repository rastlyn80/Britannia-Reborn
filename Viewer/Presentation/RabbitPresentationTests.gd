extends SceneTree
## Actual registered rabbit, source maps, physical gaits and render-stage paws.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Visual=preload("res://Presentation/RabbitVisual.gd")
const Support=preload("res://Presentation/RabbitGroundSupport.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const INPUTS=["RabbitPresentationTests.gd","RabbitVisual.gd","RabbitGroundSupport.gd","RabbitMaterial.gd","RabbitSurface.gdshader","CatGroundSupport.gd","CreatureRegistry.gd","CreatureVisual.gd","SourceMountContact.gd","FootContact.gd","OstardVisual.gd","HumanAvatar.gd","LegacyAvatar.gd","HumanHue.gd","HumanActions.gd","MountVisual.gd","AnimalPoseLibrary.gd","CorpseModels.gd","SkinGeometry.gd"]
var checks:=0
var failures:=0
var viewport: SubViewport
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<24:push_error(label)
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
		var values: Array=[]
		for pair in [[foot.a,foot.b],[foot.b,foot.c],[foot.c,foot.end]]:values.append(rig.to_global(rig.get_bone_global_pose(pair[0]).origin).distance_to(rig.to_global(rig.get_bone_global_pose(pair[1]).origin)))
		result.append(values)
	return result
func skin_bounds(meshes: Array,rig: Skeleton3D) -> AABB:
	var result:=Geometry.deformed_bounds(meshes[0],rig)
	for i in range(1,meshes.size()):result=result.merge(Geometry.deformed_bounds(meshes[i],rig))
	return result
func run() -> void:
	Registry.load_index();var candidate:="res://local-art/rabbit/candidate.json";var record: Dictionary
	if "--public" in OS.get_cmdline_user_args():record=Registry.entry(205);candidate="res://Art/Creatures/index.json"
	else:record=JSON.parse_string(FileAccess.get_file_as_string(candidate))
	Registry.entries[205]=record
	var motion: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../outputs/creatures/rabbit-trial/motion.json"));var output:="res://../outputs/creatures/rabbit-trial";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=Vector2i(1000,800);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.85;camera.near=.001;viewport.add_child(camera);camera.position=Vector3(.7,.4,1.);camera.look_at(Vector3(0.,.23,0.))
	var actor:=Avatar.new();actor.initial_body=205;actor.set_meta("own",true);var plate:=Node3D.new();plate.name="Nameplate";actor.add_child(plate);var picker:=StaticBody3D.new();picker.collision_layer=2;picker.set_meta("server_mobile",205);var pick_shape:=CollisionShape3D.new();pick_shape.shape=CapsuleShape3D.new();picker.add_child(pick_shape);actor.add_child(picker);viewport.add_child(actor);actor.apply_server_appearance({"body":205,"hue":0},[]);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false;visual.contact.active=false
	var rig: Skeleton3D=visual.skeleton;var meshes: Array=visual.model.find_children("*","MeshInstance3D",true,false)
	check(visual is Visual and visual.contact is Support and visual.contact.feet.size()==4 and visual.contact.stride==8,"Actual registered avatar uses source rabbit and four eight-weight paws")
	check(visual.native_body==205 and visual.action_profile=="animal" and rig.get_bone_count()==37 and meshes.size()==2,"Native205 animal profile and original body/fur rig retained")
	var bounds: AABB=visual.get_meta("pick_bounds");check(pick_shape.shape is BoxShape3D and pick_shape.shape.size.is_equal_approx(bounds.size),"Actual mobile selection uses measured small-body volume")
	check(absf(float(actor.get_meta("camera_height"))-.4)<.0001,"Small rabbit camera height is declared")
	var modified: Dictionary={"serial":0}
	visual.contact.modification_processed.connect(func():
		var paws: Array=[]
		for foot: Dictionary in visual.contact.feet:paws.append(visual.contact.sole(foot))
		modified["paws"]=paws;modified["lengths"]=lengths(rig,visual.contact.feet);modified["serial"]=int(modified.serial)+1
	)
	visual.play("Idle",0.);visual.animator.seek(0.,true);visual.animator.pause();var base:=await capture();base.save_png(ProjectSettings.globalize_path(output+"/coat-default.png"))
	var normals:=0;var fur:=0
	for mesh: MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():
			var original:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D;var active:=mesh.get_active_material(surface) as ShaderMaterial
			check(active!=null and active.shader==preload("res://Presentation/RabbitSurface.gdshader") and active.get_shader_parameter("albedo_texture")==original.albedo_texture,"Both original alpha/albedo textures bound on real skins")
			if original.normal_texture!=null:normals+=1;check(active.get_shader_parameter("normal_texture")==original.normal_texture and active.get_shader_parameter("use_normal_texture"),"Artist's actual normal map retained")
			if bool(active.get_shader_parameter("fur_cards")):fur+=1
	check(normals==1 and fur==1,"Separate original normal-mapped body and alpha fur preserved")
	var hues: Array=[];var instance:=rig.get_instance_id()
	for hue in [0x1BB,53,0x8035]:
		actor.apply_server_appearance({"body":205,"hue":hue},[]);var image:=await capture();var pixels:=difference(base,image)
		check(visual.native_hue==hue and rig.get_instance_id()==instance,"Raw native/full/partial colour preserves exact bits and original rig")
		check(pixels>150,"Native dye visibly changes actual rabbit fur")
		for mesh: MeshInstance3D in meshes:
			var material:=mesh.get_active_material(0) as ShaderMaterial;check(material.get_shader_parameter("use_hue") and bool(material.get_shader_parameter("partial_hue"))==bool(hue&0x8000),"Palette and partial flag applied on both body/fur")
		hues.append({"hue":hue,"changed_pixels":pixels});image.save_png(ProjectSettings.globalize_path(output+"/hue-%04x.png"%hue))
	actor.apply_server_appearance({"body":205,"hue":0},[])
	for mesh: MeshInstance3D in meshes:mesh.get_active_material(0).set_shader_parameter("use_normal_texture",false)
	var flat:=await capture();check(difference(base,flat,.012)>50,"Actual source normal map changes the lit surface")
	for mesh: MeshInstance3D in meshes:
		var original:=mesh.mesh.surface_get_material(0) as StandardMaterial3D;mesh.get_active_material(0).set_shader_parameter("use_normal_texture",original.normal_texture!=null);mesh.get_active_material(0).set_shader_parameter("alpha_probe",true)
	var masked:=await capture()
	for mesh: MeshInstance3D in meshes:mesh.get_active_material(0).set_shader_parameter("use_source_alpha",false)
	var solid:=await capture();var gaps:=0
	for y in range(0,solid.get_height(),2):
		for x in range(0,solid.get_width(),2):
			if solid.get_pixel(x,y).a>.5 and masked.get_pixel(x,y).a<.35:gaps+=1
	check(gaps>100,"Original alpha creates real visible fur/whisker gaps instead of solid cards")
	for mesh: MeshInstance3D in meshes:mesh.get_active_material(0).set_shader_parameter("use_source_alpha",true);mesh.get_active_material(0).set_shader_parameter("alpha_probe",false)
	var gait_rows: Array=[]
	for speed in [1.8,2.44,5.5,6.8]:
		visual.action_remaining=0.;visual.current_clip="Idle";actor.animate(true,0.,1./60.,speed);var clip: String="Walk" if speed<3.6 else "Run";var effective: float=motion.gaits[clip].median_stance_speed_mps*visual.animator.speed_scale
		check(visual.current_clip==clip and absf(effective-speed)<.15,"Actual avatar gait/paw speed matches native travel")
		check(visual.animator.get_animation(clip).loop_mode==Animation.LOOP_LINEAR,"Both original-pose gaits keep looping")
		gait_rows.append({"native_speed":speed,"clip":clip,"playback_rate":visual.animator.speed_scale,"effective_stance_speed":effective})
	for frame in 40:await physics_frame;await process_frame
	check(visual.animator.is_playing() and visual.current_clip=="Run","Fast gait continues beyond repeated complete cycles")
	var phases: Dictionary={"Idle":[0.],"Walk":[0.,.125,.25,.375,.5,.625,.75,.875],"Run":[0.,.125,.25,.375,.5,.625,.75,.875],"Eat":[0.,.5,1.],"Attack":[.5],"Hit":[.5],"Fidget":[.5],"Alert":[.5],"Jump":[.25,.5,.75]};var references: Dictionary={}
	for clip: String in phases:
		for phase: float in phases[clip]:
			visual.play(clip,0.);visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();for frame in 2:await process_frame
			var paws: Array=[]
			for foot: Dictionary in visual.contact.feet:paws.append(visual.contact.sole(foot).y)
			references[clip+"/"+str(phase)]={"paws":paws,"lengths":lengths(rig,visual.contact.feet)}
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(8.,.1,8.);collider.shape=shape;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground);actor.set_physics_process(true);visual.set_process(true);visual.set_physics_process(true);visual.contact.active=true
	var terrain: Array=[];var airborne:=0;var planted:=0
	for slope in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,-.08)]:
		for yaw in [0.,PI/2.]:
			for clip: String in phases:
				for phase: float in phases[clip]:
					actor.rotation.y=yaw;ground.position.y=-.15 if yaw==0. else .18;ground.rotation=Vector3(slope.x,0.,slope.y);visual.current_clip=clip;visual.action_remaining=1000.;visual.dead=false;visual.contact.enabled=true;visual.play(clip,0.);var serial:=int(modified.serial)
					for frame in 32:await physics_frame;actor.animate(false,yaw,1./60.,0.);visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();await process_frame
					for frame in 2:await process_frame
					var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1));check(not hit.is_empty(),"Actual finite raised/lowered collider sampled")
					if hit.is_empty():continue
					check(actor.global_position.is_zero_approx() and absf(actor.ground_offset-float(hit.position.y))<.015,"Support never moves authoritative entity coordinates")
					check(int(modified.serial)>serial,"Actual final render-stage paw sample is fresh")
					var reference: Dictionary=references[clip+"/"+str(phase)];var paws: Array=[]
					for i in visual.contact.feet.size():
						var point: Vector3=modified.paws[i];var gap: float=hit.normal.dot(point-hit.position);var authored: float=reference.paws[i]
						if authored>.024:airborne+=1;check(absf(gap-authored)<.010,"Actual source swing/airborne paw remains lifted")
						elif authored<.008:planted+=1;check(absf(gap)<.007,"Actual source stance paw stays within7mm of plane")
						else:check(gap>-.007 and gap<authored+.010,"Transition paw remains bounded")
						for segment in 3:check(absf(float(modified.lengths[i][segment])-float(reference.lengths[i][segment]))<.001,"All original fore/hind segment lengths retained under support")
						paws.append({"paw":i,"gap":gap,"authored_lift":authored})
					var visible_bounds:=skin_bounds(meshes,rig);var plate_gap:=plate.global_position.y-visible_bounds.end.y;check(plate_gap>.01,"Nameplate remains above long animated ears and body: %s/%s gap%f"%[clip,phase,plate_gap])
					terrain.append({"clip":clip,"phase":phase,"slope":str(slope),"yaw":yaw,"height":ground.position.y,"paws":paws,"nameplate_clearance":plate_gap})
	check(airborne>=12 and planted>=12,"Finite-plane set includes real airborne and planted paws")
	visual.contact.active=false;actor.set_physics_process(false);visual.set_physics_process(false);visual.set_process(false);ground.free();actor.rotation=Vector3.ZERO;actor.visual_root.position=Vector3.ZERO;visual.model.basis=visual.source_model_basis.scaled(visual.default_model_scale);visual.model.position=Vector3.ZERO;visual.play("Death",0.);visual.animator.seek(visual.animator.current_animation_length,true);visual.animator.pause();for frame in 2:await process_frame
	var death_size:=skin_bounds(meshes,rig).size;actor.free()
	for hue in [0,0x1BB,0x8035]:
		var corpse:=Corpses.build(205,hue);check(corpse!=null,"Native0x2006/amount205 static corpse exists")
		if corpse==null:continue
		viewport.add_child(corpse);var box: AABB=corpse.get_meta("corpse_bounds");check(corpse.get_meta("corpse_body")==205 and corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("native_hue")==hue,"Corpse retains exact native body/graphic/hue")
		check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and box.position.y==0. and box.size.distance_to(death_size)<.001,"Grounded rig-free cadaver matches actual final body/fur death skin within1mm")
		var frozen:=corpse.find_children("*","MeshInstance3D",true,false);check(frozen.size()==2 and frozen.all(func(mesh: MeshInstance3D):return mesh.mesh.get_surface_count()>0),"Both body/fur cadaver surfaces exist with valid source UV formats")
		var image:=await capture();var occupied:=0
		for y in range(0,image.get_height(),2):
			for x in range(0,image.get_width(),2):
				if image.get_pixel(x,y).a>.5:occupied+=1
		check(occupied>300,"Actual static corpse visibly renders; metadata alone cannot pass")
		image.save_png(ProjectSettings.globalize_path(output+"/corpse-%04x.png"%hue));corpse.free()
	var runtime: Dictionary={}
	for name in INPUTS:runtime["res://Presentation/"+name]=FileAccess.get_sha256("res://Presentation/"+name)
	var path:=Registry.asset_path(record);var report:={"checks":checks,"failures":failures,"terrain":terrain,"airborne_paw_cases":airborne,"planted_paw_cases":planted,"hues":hues,"gaits":gait_rows,"alpha_gap_pixels":gaps,"renderer":RenderingServer.get_current_rendering_method(),"candidate_sha256":FileAccess.get_sha256(candidate),"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import"),"runtime_sha256":runtime,"scope":"Actual registered rabbit avatar, original normals/alpha fur, raw native hues, calibrated source-pose gaits, render-stage planted/lifted paws and segment lengths on finite support planes, long-ear nameplate and matching native static corpse. Not native gameplay, arbitrary obstacles, exact UO partial masks or final anatomy certification."}
	FileAccess.open(output+"/presentation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("RABBIT PRESENTATION: ",checks," / ",failures," failures; ",terrain.size()," terrain cases");quit(1 if failures else 0)
