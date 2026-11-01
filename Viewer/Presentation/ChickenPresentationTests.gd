extends SceneTree
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Visual=preload("res://Presentation/ChickenVisual.gd")
const Support=preload("res://Presentation/BirdGroundSupport.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const INPUTS=["ChickenPresentationTests.gd","ChickenVisual.gd","ChickenMaterial.gd","ChickenSurface.gdshader","CreatureRegistry.gd","CreatureVisual.gd","BirdGroundSupport.gd","SourceMountContact.gd","FootContact.gd","OstardVisual.gd","HumanAvatar.gd","LegacyAvatar.gd","HumanHue.gd","HumanActions.gd","MountVisual.gd","AnimalPoseLibrary.gd","CorpseModels.gd","SkinGeometry.gd"]
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
func difference(a: Image,b: Image,threshold: float=.025) -> int:
	var result:=0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var d:=a.get_pixel(x,y)-b.get_pixel(x,y)
			if absf(d.r)+absf(d.g)+absf(d.b)>threshold:result+=1
	return result
func skin(meshes: Array,rig: Skeleton3D) -> AABB:
	var result:=Geometry.deformed_bounds(meshes[0],rig)
	for i in range(1,meshes.size()):result=result.merge(Geometry.deformed_bounds(meshes[i],rig))
	return result
func points(meshes: Array,rig: Skeleton3D) -> PackedVector3Array:
	var result:=PackedVector3Array()
	for mesh: MeshInstance3D in meshes:
		var matrices: Array[Transform3D]=[]
		for i in mesh.skin.get_bind_count():
			var bone:=mesh.skin.get_bind_bone(i)
			if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(i))
			matrices.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(i))
		for surface in mesh.mesh.get_surface_count():
			var a:=mesh.mesh.surface_get_arrays(surface);var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var b: PackedInt32Array=a[Mesh.ARRAY_BONES];var w: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride:=b.size()/v.size()
			for i in v.size():
				var p:=Vector3.ZERO
				for j in stride:p+=(matrices[b[i*stride+j]]*v[i])*w[i*stride+j]
				result.append(rig.to_global(p))
	return result
func run() -> void:
	Registry.load_index();var candidate:="res://local-art/chicken/candidate.json";var record: Dictionary
	if "--public" in OS.get_cmdline_user_args():record=Registry.entry(208);candidate="res://Art/Creatures/index.json"
	else:record=JSON.parse_string(FileAccess.get_file_as_string(candidate))
	Registry.entries[208]=record;var output:="res://../outputs/creatures/chicken-trial";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=Vector2i(1000,750);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.85;camera.near=.001;viewport.add_child(camera);camera.position=Vector3(.7,.4,1.);camera.look_at(Vector3(0.,.23,0.))
	var actor:=Avatar.new();actor.initial_body=208;actor.set_meta("own",true);var plate:=Node3D.new();plate.name="Nameplate";actor.add_child(plate);var picker:=StaticBody3D.new();picker.set_meta("server_mobile",208);picker.collision_layer=2;var pick_shape:=CollisionShape3D.new();pick_shape.shape=BoxShape3D.new();picker.add_child(pick_shape);actor.add_child(picker);viewport.add_child(actor);actor.apply_server_appearance({"body":208,"hue":0},[]);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false;visual.contact.active=false;var rig: Skeleton3D=visual.skeleton;var meshes: Array=visual.model.find_children("*","MeshInstance3D",true,false)
	check(visual is Visual and visual.native_body==208 and visual.action_profile=="animal" and rig.get_bone_count()==47 and meshes.size()==2,"Actual native208 avatar uses original body/eyes, source40 plus seven segment joints")
	check(visual.contact is Support and visual.contact.feet.is_empty(),"Original independent foot roots use plane support without invented leg chains")
	visual.play("Idle",0.);visual.animator.seek(0.,true);visual.animator.pause();var base:=await capture();base.save_png(ProjectSettings.globalize_path(output+"/default.png"));var maps:=0;var eyes:=0
	for mesh: MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D;var active:=mesh.get_active_material(surface)
			if source.normal_texture!=null:
				maps+=1;check(active is ShaderMaterial and active.get_shader_parameter("normal_texture")==source.normal_texture and active.get_shader_parameter("albedo_texture")==source.albedo_texture,"Original feather albedo/normal maps retained on actual source UVs")
			if source.albedo_texture==null and source.roughness<.5:eyes+=1;check(active==source,"Original dark eye material protected from dye")
	check(maps==1 and eyes==1,"Separate source normal-mapped coat and dark eye surfaces preserved")
	var hues: Array=[];var previous: Image;var instance:=rig.get_instance_id()
	for hue in [53,0x8035,0x901]:
		actor.apply_server_appearance({"body":208,"hue":hue},[]);var image:=await capture();var changed:=difference(base,image);check(visual.native_hue==hue and rig.get_instance_id()==instance,"Raw hue/partial bits retain native identity and source skeleton");check(changed>100,"Full and partial colours visibly change the coat")
		if hue==0x8035:check(difference(previous,image)>5,"Authored partial body region preserves distinct comb/feature colour")
		previous=image;hues.append({"hue":hue,"changed_pixels":changed});image.save_png(ProjectSettings.globalize_path(output+"/hue-%04x.png"%hue))
	actor.apply_server_appearance({"body":208,"hue":0},[])
	for mesh: MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():
			var material:=mesh.get_active_material(surface) as ShaderMaterial
			if material!=null:material.set_shader_parameter("use_normal",false)
	var flat:=await capture();var normal_pixels:=difference(base,flat,.012);check(normal_pixels>50,"Actual source normal map changes lit feather detail")
	actor.apply_server_appearance({"body":208,"hue":0},[]);check(absf(float(actor.get_meta("camera_height"))-.32)<.0001,"Camera follows the small native body height")
	var flat_gaps: Dictionary={};var death_size:=Vector3.ZERO
	for clip in ["Idle","Walk","Run","Attack","Hit","Death","Fidget","Eat"]:
		flat_gaps[clip]=[]
		for step in 6:
			visual.play(clip,0.);visual.animator.seek(visual.animator.current_animation_length*float(step)/5.,true);visual.animator.pause();rig.force_update_all_bone_transforms();flat_gaps[clip].append(skin(meshes,rig).position.y)
			if clip=="Death" and step==5:death_size=skin(meshes,rig).size
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(10.,.1,10.);collider.shape=box;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground);actor.set_physics_process(true);visual.set_process(true);visual.set_physics_process(true);var terrain: Array=[];var airborne:=0
	for slope in [Vector2.ZERO,Vector2(.08,-.06)]:
		for yaw in [0.,PI/2.]:
			for clip in ["Idle","Walk","Run","Attack","Hit","Death","Fidget","Eat"]:
				for step in 6:
					var phase:=float(step)/5.;ground.position.y=-.15 if yaw==0. else .18;ground.rotation=Vector3(slope.x,0.,slope.y);actor.rotation.y=yaw;visual.current_clip=clip;visual.action_remaining=1000.;visual.dead=false;visual.contact.enabled=true;visual.play(clip,0.)
					for frame in 28:await physics_frame;actor.animate(false,yaw,1./60.,0.);visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();await process_frame
					for frame in 2:await process_frame
					var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1));check(not hit.is_empty(),"Actual finite plane sampled")
					if hit.is_empty():continue
					visual.update_landmarks();var bounds: AABB=visual.get_meta("pick_bounds");var low:=INF;var high:=-INF;var contained:=true;var finite:=true;var picked:=true;var pick_box: AABB=pick_shape.global_transform*AABB(-pick_shape.shape.size*.5,pick_shape.shape.size)
					for p in points(meshes,rig):var gap: float=hit.normal.dot(p-hit.position);low=minf(low,gap);high=maxf(high,gap);finite=finite and p.is_finite();contained=contained and bounds.has_point(visual.to_local(p));picked=picked and pick_box.has_point(p)
					check(finite and contained,"Dynamic bounds contain every weighted body/eye vertex")
					check(actor.global_position.is_zero_approx() and absf(actor.ground_offset-float(hit.position.y))<.015,"Support preserves native entity coordinates")
					check(absf(low-float(flat_gaps[clip][step]))<.01,"Terrain support preserves actual source floor and authored positive lift")
					check(plate.global_position.y>skin(meshes,rig).end.y+.025,"Actual nameplate clears the full skin in every category")
					check(picked,"Actual world-space mobile selection contains every rendered skin vertex")
					if clip=="Run" and low>.008:airborne+=1
					terrain.append({"clip":clip,"phase":phase,"slope":str(slope),"yaw":yaw,"minimum_plane_gap_m":low,"source_flat_gap_m":flat_gaps[clip][step],"highest_plane_gap_m":high})
	check(airborne>0,"Actual running avatar retains positive airborne skin clearance on terrain")
	actor.set_physics_process(false);visual.set_physics_process(false);ground.free();actor.free()
	for hue in [0,53,0x8035]:
		var corpse:=Corpses.build(208,hue);check(corpse!=null,"Native208/graphic0x2006 static cadaver exists")
		if corpse==null:continue
		viewport.add_child(corpse);var bounds: AABB=corpse.get_meta("corpse_bounds");check(corpse.get_meta("corpse_body")==208 and corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("native_hue")==hue,"Static corpse retains native body, graphic and exact hue");check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and bounds.position.y==0. and bounds.size.distance_to(death_size)<.001,"Rig-free grounded cadaver matches the actual final source death skin");var image:=await capture();image.save_png(ProjectSettings.globalize_path(output+"/corpse-%04x.png"%hue));corpse.free()
	var runtime: Dictionary={}
	for name in INPUTS:runtime["res://Presentation/"+name]=FileAccess.get_sha256("res://Presentation/"+name)
	var asset: String=record.assets.modern;FileAccess.open(output+"/presentation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"terrain":terrain,"airborne_cases":airborne,"hues":hues,"normal_map_pixels":normal_pixels,"renderer":RenderingServer.get_current_rendering_method(),"runtime_sha256":runtime,"candidate_sha256":FileAccess.get_sha256(candidate),"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import"),"scope":"Actual native-body avatar, original PBR maps, full/partial colours/protected eyes, dynamic body+eye bounds,192 finite-plane poses retaining source/positive root lift and native static cadavers. Not arbitrary terrain, original UO choreography or autonomous gameplay certification."},"  "));print("CHICKEN PRESENTATION: ",checks," / ",failures," failures; ",terrain.size()," terrain poses");quit(1 if failures else 0)
