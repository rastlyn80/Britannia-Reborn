extends SceneTree
## Actual avatar, shader and collision-plane checks before enabling a public route.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Support=preload("res://Presentation/BirdGroundSupport.gd")
var checks:=0
var failures:=0
var viewport: SubViewport
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<15:push_error(label)
func capture() -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	var picture:=viewport.get_texture().get_image();picture.convert(Image.FORMAT_RGBA8);return picture
func difference(a: Image,b: Image) -> int:
	var count:=0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var first:=a.get_pixel(x,y);var second:=b.get_pixel(x,y)
			if first.a>.2 and Vector3(first.r-second.r,first.g-second.g,first.b-second.b).length()>.015:count+=1
	return count
func plane_gap(mesh: MeshInstance3D,rig: Skeleton3D,point: Vector3,normal: Vector3) -> float:
	var matrices: Array[Transform3D]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
		matrices.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var minimum:=INF;var arrays:=mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var stride:=indices.size()/vertices.size()
	for vertex in vertices.size():
		var position:=Vector3.ZERO
		for influence in stride:position+=(matrices[indices[vertex*stride+influence]]*vertices[vertex])*weights[vertex*stride+influence]
		minimum=minf(minimum,normal.dot(rig.to_global(position)-point))
	return minimum
func run() -> void:
	Registry.load_index()
	var record:=Registry.entry(6)
	var candidate_path:="res://Art/Creatures/index.json" if not record.is_empty() else "res://local-art/birds/candidate.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--candidate="):
			candidate_path=argument.trim_prefix("--candidate=");record=JSON.parse_string(FileAccess.get_file_as_string(candidate_path))
	if record.is_empty():record=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/birds/candidate.json"))
	Registry.entries[6]=record
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/bird-trial"))
	viewport=SubViewport.new();viewport.size=Vector2i(640,640);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.45;camera.near=.001;viewport.add_child(camera);camera.position=Vector3(.5,.28,.7);camera.look_at(Vector3(0.,.1,0.))
	var actor:=Avatar.new();actor.initial_body=6;actor.set_meta("own",true)
	var plate:=Node3D.new();plate.name="Nameplate";actor.add_child(plate)
	var picker:=StaticBody3D.new();picker.collision_layer=2;picker.collision_mask=0;picker.set_meta("server_mobile",42)
	var pick_shape:=CollisionShape3D.new();pick_shape.shape=BoxShape3D.new();picker.add_child(pick_shape);actor.add_child(picker)
	viewport.add_child(actor);actor.set_physics_process(false);actor.apply_server_appearance({"body":6,"hue":0},[])
	var visual: Node3D=actor.horse_visual;var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
	check(visual!=null and actor.human_visual==null and visual.native_body==6,"Native bird identity selects the licensed animal visual")
	check(visual.contact is Support and visual.contact.feet.is_empty(),"Independent foot-control roots receive support-plane fitting without invented wing IK")
	var initial_rig:=rig.get_instance_id()
	visual.animator.seek(.3,true);visual.animator.pause()
	var base:=await capture();var occupied:=0
	base.save_png(ProjectSettings.globalize_path("res://../outputs/creatures/bird-trial/pbr-default.png"))
	for y in range(0,640,2):
		for x in range(0,640,2):
			if base.get_pixel(x,y).a>.2:occupied+=1
	check(occupied>500,"Actual feather surface occupies the rendered view")
	var material:=mesh.get_surface_override_material(0) as ShaderMaterial
	check(material!=null and material.shader==preload("res://Presentation/CreatureFeatherSurface.gdshader"),"Feather PBR shader is active on the actual mesh")
	check(material.get_shader_parameter("normal_texture")!=null and material.get_shader_parameter("roughness_texture")!=null,"Real normal and roughness maps stay bound after native appearance")
	material.set_shader_parameter("normal_strength",0.);var flat:=await capture();var normal_pixels:=difference(base,flat)
	check(normal_pixels>10,"Imported normal map changes actual surface lighting")
	material.set_shader_parameter("normal_strength",.65);material.set_shader_parameter("roughness_gain",.05);var polished:=await capture();var rough_pixels:=difference(base,polished)
	check(rough_pixels>10,"Imported roughness map has measurable material response")
	actor.apply_server_appearance({"body":6,"hue":0},[])
	var hue_samples: Array=[]
	for hue in [53,0x8035,0x901]:
		actor.apply_server_appearance({"body":6,"hue":hue},[]);var dyed:=await capture();var pixels:=difference(base,dyed)
		print("BIRD HUE ",hue,": ",pixels," changed pixels")
		check(visual.native_hue==hue and rig.get_instance_id()==initial_rig,"Raw hue update retains exact bits and the animated rig")
		check(pixels>10,"Native bird hue changes actual pixels")
		if hue==0x8035:check(pixels<occupied*.9,"Partial hue preserves part of the original feather/beak palette")
		hue_samples.append({"hue":hue,"changed_pixels":pixels})
		dyed.save_png(ProjectSettings.globalize_path("res://../outputs/creatures/bird-trial/hue-%04x.png"%hue))
	actor.apply_server_appearance({"body":6,"hue":0},[])
	check(pick_shape.shape is BoxShape3D and pick_shape.shape.size.x<.6 and pick_shape.shape.size.y<.6 and pick_shape.shape.size.z<.6,"Own bird uses measured small bounds rather than a rider/mount box")
	check(is_equal_approx(float(actor.get_meta("camera_height")),.25),"Polymorphed bird camera uses its presentation height")
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(20.,.1,20.);collider.shape=shape;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground)
	actor.set_physics_process(true)
	var supports: Array=[]
	for level in [-.18,.21]:
		for slope in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,.06)]:
			for yaw in [0.,PI/2.]:
				ground.position.y=level;ground.rotation=Vector3(slope.x,0.,slope.y)
				for frame in 70:
					await physics_frame;actor.animate(false,yaw,1./60.,0.);visual.animator.seek(.3,true);visual.animator.pause();await process_frame
				var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1))
				check(not hit.is_empty(),"Actual support collider is sampled")
				if hit.is_empty():continue
				var normal: Vector3=hit.normal;var gap:=plane_gap(mesh,rig,hit.position,normal)
				check(gap>-.012 and gap<.012,"Actual skinned bird rests on the sampled slope")
				check(absf(actor.ground_offset-float(hit.position.y))<.015 and actor.global_position.is_zero_approx(),"Support follows presentation height without moving native entity coordinates")
				for side in ["L","R"]:
					var toe:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("t_middle.003."+side)).origin)
					check(absf(normal.dot(toe-hit.position))<.015,"Toes remain close to real terrain on both facings")
				var head:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("head")).origin)
				check(absf(plate.global_position.y-head.y-.08)<.004,"Name/overhead anchor follows the rendered bird head")
				var centre: Vector3=(visual.get_meta("pick_bounds") as AABB).get_center()+Vector3.UP*actor.visual_root.position.y
				check(pick_shape.position.distance_to(centre)<.001,"Measured selection centre follows support height through frame updates")
				supports.append({"height":level,"slope":str(slope),"facing":yaw,"skin_clearance":gap})
	base.save_png(ProjectSettings.globalize_path("res://../outputs/creatures/bird-trial/pbr-default.png"))
	# Exercise every animal action group and modern action type on the actual
	# visual, including runtime LieDown and the authored call/cast category.
	for protocol in ["classic","new"]:
		for action in range(13) if protocol=="classic" else [0,3,4,11]:
			visual.dead=false;visual.action_remaining=0.
			var request:={"protocol":protocol,"action":action,"type":action}
			check(visual.receive_action(request),"Actual bird accepts "+protocol+" action "+str(action))
	actor.free();ground.free()
	var report: Dictionary=preload("res://Presentation/BirdEvidence.gd").capture(Registry.asset_path(record),record)
	report["candidate_sha256"]=FileAccess.get_sha256(candidate_path)
	report["partial_hue_mask_sha256"]=FileAccess.get_sha256(str(record.partial_hue_mask))
	report.merge({"checks":checks,"failures":failures,"normal_response_pixels":normal_pixels,"roughness_response_pixels":rough_pixels,"hues":hue_samples,"support_cases":supports,"scope":"Actual Forward+ avatar and PBR maps, raw hue updates, measured interaction/camera/overhead anchors, finite raised/lowered flat/sloped collision planes and category routes. Native server and arbitrary obstacles remain separate."})
	preload("res://Presentation/BirdEvidence.gd").output("presentation-validation",report)
	print("BIRD PRESENTATION: ",checks-failures," / ",checks,"; ",supports.size()," support cases");quit(1 if failures else 0)
