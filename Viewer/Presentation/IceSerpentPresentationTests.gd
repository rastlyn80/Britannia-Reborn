extends SceneTree
## Actual legless source avatar, finite support planes and native static corpse.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const PlaneSupport=preload("res://Presentation/BirdGroundSupport.gd")
const INPUTS=["SmallSnakeVisual.gd","SourceGroundLookup.gd","IceSerpentMaterial.gd","IceSerpentSurface.gdshader","IceSerpentPresentationTests.gd","CreatureRegistry.gd","IceSerpentVisual.gd","CreatureVisual.gd","BirdGroundSupport.gd","SourceMountContact.gd","FootContact.gd","OstardVisual.gd","OstardSurface.gdshader","HumanAvatar.gd","LegacyAvatar.gd","HumanHue.gd","HumanActions.gd","MountVisual.gd","AnimalVisual.gd","AnimalPoseLibrary.gd","SkinGeometry.gd","CorpseModels.gd"]
var checks:=0
var failures:=0
var viewport: SubViewport
func _initialize() -> void:
	create_timer(900.).timeout.connect(func():push_error("Ice serpent presentation check exceeded its deadline");quit(1))
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<20:push_error(label)
func capture() -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw;return viewport.get_texture().get_image()
func points(mesh: MeshInstance3D,rig: Skeleton3D) -> PackedVector3Array:
	var matrices: Array[Transform3D]=[]
	for i in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(i)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(i))
		matrices.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(i))
	var result:=PackedVector3Array()
	for surface in mesh.mesh.get_surface_count():
		var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride:=bones.size()/vertices.size()
		for i in vertices.size():
			var point:=Vector3.ZERO
			for j in stride:point+=(matrices[bones[i*stride+j]]*vertices[i])*weights[i*stride+j]
			result.append(rig.to_global(point))
	return result
func difference(a: Image,b: Image) -> int:
	var count:=0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var d:=a.get_pixel(x,y)-b.get_pixel(x,y)
			if absf(d.r)+absf(d.g)+absf(d.b)>.025:count+=1
	return count
func run() -> void:
	var preparation:="res://local-art/creatures/ice_serpents/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation));var record: Dictionary=prep.models.filter(func(row: Dictionary):return row.kind=="serpents_snake_giant_ice")[0]
	Registry.load_index();Registry.entries[89]=record
	var output:="res://../outputs/creatures/ice_serpents/presentation";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=Vector2i(1000,750);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=7.8;viewport.add_child(camera);camera.position=Vector3(3.,3.,6.);camera.look_at(Vector3(0.,.08,0.))
	var actor:=Avatar.new();actor.initial_body=89;actor.set_meta("own",true);var plate:=Node3D.new();plate.name="Nameplate";actor.add_child(plate)
	var picker:=StaticBody3D.new();picker.set_meta("server_mobile",89);picker.collision_layer=2;var pick_shape:=CollisionShape3D.new();pick_shape.shape=BoxShape3D.new();picker.add_child(pick_shape);actor.add_child(picker)
	viewport.add_child(actor);actor.apply_server_appearance({"body":89,"hue":0},[]);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false;visual.contact.active=false
	var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
	check(visual.contact is PlaneSupport and visual.contact.feet.is_empty(),"Legless source uses terrain plane without invented foot chains")
	check(visual.native_body==89 and visual.action_profile=="monster" and rig.get_bone_count()==18,"Native monster profile and original eighteen mesh bones retained")
	check(record.authored_source_reuse.clip_stem=="serpents_snake_giant_silver" and record.source_motion_contract.bone_count==18,"Silver motions explicitly declared under measured compatible-rig contract")
	visual.play("Idle",0.);visual.animator.seek(0.,true);visual.animator.pause();var base:=await capture();base.save_png(ProjectSettings.globalize_path(output+"/default.png"))
	var material:=mesh.get_active_material(0) as ShaderMaterial;var texture:=material.get_shader_parameter("albedo_texture") as Texture2D
	check(texture!=null and texture.get_width()>1000 and texture.get_height()==texture.get_width(),"Detailed square atlas bound on retained source UVs")
	var hues: Array=[];var instance:=rig.get_instance_id()
	for hue in [53,0x8035,0x901]:
		actor.apply_server_appearance({"body":89,"hue":hue},[]);var image:=await capture();var changed:=difference(base,image);var dyed:=mesh.get_active_material(0) as ShaderMaterial
		check(visual.native_hue==hue and rig.get_instance_id()==instance,"Native full/partial hue retains raw bits and skeleton")
		check(dyed.get_shader_parameter("use_hue") and bool(dyed.get_shader_parameter("partial_hue"))==bool(hue&0x8000),"Actual hue palette and partial flag bound")
		check(changed>100,"Full and partial native hue visibly change serpent skin")
		hues.append({"hue":hue,"changed_pixels":changed});image.save_png(ProjectSettings.globalize_path(output+"/hue-%04x.png"%hue))
	actor.apply_server_appearance({"body":89,"hue":0},[])
	var full_image:=Image.load_from_file(ProjectSettings.globalize_path(output+"/hue-0035.png"));var partial_image:=Image.load_from_file(ProjectSettings.globalize_path(output+"/hue-8035.png"));var partial_difference:=difference(full_image,partial_image)
	check(partial_difference>100,"Authored partial neutral-ice region stays visibly distinct from full-body dye")
	var wide_position:=camera.position;var wide_rotation:=camera.rotation;var head_position:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 head")).origin)
	camera.position=head_position+Vector3(.8,.45,1.);camera.look_at(head_position);camera.size=1.3
	material=mesh.get_active_material(0) as ShaderMaterial
	check(material.get_shader_parameter("source_alpha_texture").get_width()==64 and is_equal_approx(float(material.get_shader_parameter("albedo_gain")),.62),"Original64-square opacity and restrained authored reflectance remain bound")
	material.set_shader_parameter("alpha_probe",true);var masked:=await capture();material.set_shader_parameter("use_source_alpha",false);var solid:=await capture();var cutout_pixels:=difference(masked,solid)
	check(cutout_pixels>0,"Actual original tooth/mouth opacity removes visible solid geometry")
	material.set_shader_parameter("use_source_alpha",true);material.set_shader_parameter("alpha_probe",false);var corrected_eye:=await capture();corrected_eye.save_png(ProjectSettings.globalize_path(output+"/head.png"));material.set_shader_parameter("eye_registration",Vector4(1.,0.,0.,0.));var shifted_eye:=await capture();var registered_pixels:=difference(corrected_eye,shifted_eye)
	check(registered_pixels>100,"Registered eye RGB sampling makes a measured visible head correction")
	var warp: Array=record.eye_registration;material.set_shader_parameter("eye_registration",Vector4(float(warp[0]),float(warp[1]),float(warp[2]),float(warp[3])))
	camera.position=wide_position;camera.rotation=wide_rotation;camera.size=7.8
	if "--appearance-only" in OS.get_cmdline_user_args():
		print("ICE APPEARANCE PROBE: ",checks," checks / ",failures," failures; partial/full ",partial_difference,"px; cutouts ",cutout_pixels,"px; registered head ",registered_pixels,"px");actor.free();quit(1 if failures else 0);return
	check(is_equal_approx(float(actor.get_meta("camera_height")),.48),"Camera follows declared source height")
	var pick_bounds: AABB=visual.get_meta("pick_bounds");check(pick_shape.shape is BoxShape3D and pick_shape.shape.size.is_equal_approx(pick_bounds.size) and pick_shape.position.is_equal_approx(pick_bounds.get_center()),"Actual mobile selection collider uses measured source locomotion envelope")
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(10.,.1,10.);collider.shape=box;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground)
	actor.set_physics_process(true);visual.set_process(true);visual.set_physics_process(true)
	var terrain: Array=[];var envelope:=AABB();var first:=true;var paths: Dictionary={};var death_size:=Vector3.ZERO
	for slope in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,-.08)]:
		for yaw in [0.,PI/2.]:
			for clip: String in ["Idle","Walk","Run","Attack","SourceAttack","Hit","Death","Fidget","Eat","LieDown"]:
				for phase_index in 11:
					var phase:=0. if phase_index==0 else 1. if phase_index==10 else (float(phase_index-1)+.371)/9.;actor.rotation.y=yaw;ground.position.y=-.15 if yaw==0. else .18;ground.rotation=Vector3(slope.x,0.,slope.y);visual.current_clip=clip;visual.action_remaining=1000.;visual.dead=false;visual.contact.enabled=true;visual.play(clip,0.)
					var settling_frames:=0
					for frame in 22:
						await physics_frame;actor.animate(false,yaw,1./60.,0.);visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();await process_frame
						settling_frames=frame+1
						# Consecutive poses share this collider. Wait for actual support
						# convergence, rather than repeating22 already-settled frames.
						var support:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1))
						if frame<2 or support.is_empty() or absf(actor.ground_offset-float(support.position.y))>.002:continue
						var normal: Vector3=(visual.global_basis.inverse()*support.normal).normalized()
						var expected: Basis=Basis.from_euler(Vector3(clampf(atan2(normal.z,normal.y),-.2,.2),0.,clampf(-atan2(normal.x,normal.y),-.15,.15)))*visual.source_model_basis
						if visual.model.basis.orthonormalized().get_rotation_quaternion().angle_to(expected.get_rotation_quaternion())<.002:break
					for frame in 2:await process_frame
					var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1))
					check(not hit.is_empty(),"Real raised/lowered flat/sloped collider sampled")
					if hit.is_empty():continue
					check(actor.global_position.is_zero_approx() and absf(actor.ground_offset-float(hit.position.y))<.015,"Plane support preserves native actor coordinates")
					var lowest:=INF;var highest:=-INF;var finite:=true;var pick_contains:=true
					for point in points(mesh,rig):
						var gap: float=hit.normal.dot(point-hit.position);lowest=minf(lowest,gap);highest=maxf(highest,gap)
						finite=finite and point.is_finite()
						if slope==Vector2.ZERO and yaw==0.:
							pick_bounds=visual.get_meta("pick_bounds");var local:=visual.to_local(point);envelope=AABB(local,Vector3.ZERO) if first else envelope.expand(local);first=false
							pick_contains=pick_contains and pick_bounds.has_point(local)
					check(finite,"All actual weighted serpent vertices finite")
					if slope==Vector2.ZERO and yaw==0.  :check(pick_contains,"Measured selection envelope contains actual source gait skin")
					check(lowest>-.008 and lowest<.008,"Actual weighted underside within8mm of plane: %s/%s gap%f"%[clip,phase,lowest])
					check(highest<float(record.stats.original.height_m)*4.,"Original striking/raised body remains bounded above support")
					var head:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 head")).origin)
					check(plate.global_position.y>Geometry.deformed_bounds(mesh,rig).end.y+.02,"Weighted upper landmarks clear every complete action skin")
					if slope==Vector2.ZERO and yaw==0.:
						if not paths.has(clip):paths[clip]=[]
						paths[clip].append(visual.to_local(head))
						if clip=="Death" and phase_index==10:death_size=Geometry.deformed_bounds(mesh,rig).size
					terrain.append({"clip":clip,"phase":phase,"slope":str(slope),"yaw":yaw,"height":ground.position.y,"lowest_plane_gap":lowest,"highest_plane_gap":highest,"settling_frames":settling_frames})
	for clip: String in ["Walk","Run","Attack"]:
		var span:=0.
		for point: Vector3 in paths[clip]:span=maxf(span,point.distance_to(paths[clip][0]))
		check(span>.009,"Recovered %s is genuinely moving skeletal source motion"%clip)
	var feeding_low:=INF
	for point: Vector3 in paths.Eat:feeding_low=minf(feeding_low,point.y)
	check(feeding_low<float(paths.Idle[0].y)-.018,"Authored feeding lowers the original skull without generic deep-neck penetration")
	actor.set_physics_process(false);visual.set_physics_process(false);ground.free();actor.free()
	for hue in [0,53,0x8035]:
		var corpse:=Corpses.build(89,hue);check(corpse!=null,"Native0x2006/amount89 static serpent corpse exists")
		if corpse==null:continue
		viewport.add_child(corpse);var bounds: AABB=corpse.get_meta("corpse_bounds")
		check(corpse.get_meta("corpse_body")==89 and corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("native_hue")==hue,"Serpent corpse retains native body/graphic/hue")
		check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and bounds.position.y==0. and bounds.size.distance_to(death_size)<.001,"Grounded static cadaver matches actual final source death skin within1mm")
		var image:=await capture();image.save_png(ProjectSettings.globalize_path(output+"/corpse-%04x.png"%hue));corpse.free()
	var runtime: Dictionary={}
	for name in INPUTS:runtime["res://Presentation/"+name]=FileAccess.get_sha256("res://Presentation/"+name)
	var asset:="res://local-art/creatures/serpents_snake_giant_ice-modern.gltf";var report:={"checks":checks,"failures":failures,"terrain":terrain,"hues":hues,"partial_full_difference_pixels":partial_difference,"source_cutout_pixels":cutout_pixels,"registered_head_pixels":registered_pixels,"motion_head_paths":paths,"local_motion_envelope":{"position":[envelope.position.x,envelope.position.y,envelope.position.z],"size":[envelope.size.x,envelope.size.y,envelope.size.z]},"renderer":RenderingServer.get_current_rendering_method(),"runtime_sha256":runtime,"preparation_sha256":FileAccess.get_sha256(preparation),"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import"),"ground_lookup_sha256":FileAccess.get_sha256(str(record.ground_lookup)),"scope":"Actual registered ice-serpent legless source avatar, weighted skin support on six finite flat/sloped planes across ten source/authored categories, full/partial hue pixels and raw bindings, original skull anchor and native static corpse. Silver motion reuse explicitly authored. Not arbitrary terrain, exact original partial masks, native server, complete original choreography or final art certification."}
	FileAccess.open(output+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("ICE SERPENT PRESENTATION: ",checks," / ",failures," failures; ",terrain.size()," terrain poses");quit(1 if failures else 0)
