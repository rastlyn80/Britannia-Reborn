extends SceneTree
## Bounded candidate render and deformation audit; this does not accept a route.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const FILES=["PrepareWaterElemental.gd","WaterElementalFidgets.gd","WaterElementalTrial.gd","WaterElementalMaterial.gd","WaterElementalSurface.gdshader","CreatureRegistry.gd","CreatureVisual.gd","OstardVisual.gd","HumanAvatar.gd","LegacyAvatar.gd","BirdGroundSupport.gd","SourceMountContact.gd","MountVisual.gd","AnimalPoseLibrary.gd","SkinGeometry.gd","CorpseModels.gd","HumanHue.gd","HumanActions.gd","ItemStudio.gd"]
var checks:=0
var failures:=0
var viewport: SubViewport
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func capture(path: String) -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	var picture:=viewport.get_texture().get_image();picture.convert(Image.FORMAT_RGBA8)
	if not path.is_empty():picture.save_png(path)
	return picture
func difference(a: Image,b: Image) -> int:
	var result:=0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var first:=a.get_pixel(x,y);var second:=b.get_pixel(x,y)
			if first.a>.2 and Vector3(first.r-second.r,first.g-second.g,first.b-second.b).length()>.02:result+=1
	return result
func run() -> void:
	var runtime: Dictionary={}
	for name in FILES:runtime["Viewer/Presentation/"+name]=FileAccess.get_sha256("res://Presentation/"+name)
	var asset_sha:=FileAccess.get_sha256("res://local-art/water-elemental/trial.scn")
	var candidate_sha:=FileAccess.get_sha256("res://local-art/water-elemental/candidate.json")
	Registry.load_index();var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/water-elemental/candidate.json"));Registry.entries[16]=record
	var output:=ProjectSettings.globalize_path("res://../outputs/creatures/water-trial")
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new();viewport.size=Vector2i(768,768);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	for environment: WorldEnvironment in viewport.find_children("*","WorldEnvironment",true,false):preload("res://Presentation/CreatureMineralMaterial.gd").studio_reflections(environment.environment)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.35;camera.near=.001;viewport.add_child(camera);camera.position=Vector3(3.,1.9,4.);camera.look_at(Vector3(0.,.9,0.))
	var avatar:=Avatar.new();avatar.initial_body=16;avatar.set_meta("own",true);viewport.add_child(avatar);avatar.set_physics_process(false);avatar.apply_server_appearance({"body":16,"hue":0},[])
	var visual: Node3D=avatar.horse_visual;visual.set_process(false);visual.set_physics_process(false)
	check(visual.native_body==16 and avatar.human_visual==null,"Native body 16 selects actual creature visual")
	check(visual.contact.feet.is_empty(),"Vortex receives plane support without imaginary foot IK")
	var actor: Node3D=visual.model
	var rig: Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0]
	var mesh: MeshInstance3D=actor.find_children("*","MeshInstance3D",true,false)[0]
	var player: AnimationPlayer=actor.find_children("*","AnimationPlayer",true,false)[0]
	var material:=mesh.get_active_material(0) as ShaderMaterial
	check(rig.get_bone_count()==65,"Retains licensed 65-bone rig")
	check(player.get_animation_list().size()>=19,"Nineteen explicitly mapped/authored categories")
	check(mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES].size()==mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()*8,"Eight-influence joined fluid skin")
	var rows: Array=[];var still: Image
	for clip in record.stats.modern.clips:
		print("WATER SAMPLE ",clip)
		var animation:=player.get_animation(clip)
		var samples: Array=[]
		var first_left := Vector3.ZERO
		var first_right := Vector3.ZERO
		for frame in 9:
			var time:=animation.length*float(frame)/8.
			player.play(clip,0.);player.seek(time,true);player.pause();rig.force_update_all_bone_transforms()
			var bounds:=Geometry.deformed_bounds(mesh,rig)
			if clip in ["WaterArmSettle", "Fidget2"]:
				var left := rig.to_global(rig.get_bone_global_pose(rig.find_bone("hand_l")).origin)
				var right := rig.to_global(rig.get_bone_global_pose(rig.find_bone("hand_r")).origin)
				if frame == 0:
					first_left = left
					first_right = right
				elif frame == 4:
					check(left.y - first_left.y < -0.12 and absf(right.y - first_right.y) < 0.06
						if clip == "WaterArmSettle" else left.z - first_left.z > 0.09 and right.z - first_right.z > 0.10,
						clip + " preserves the distinct Classic arm motion")
				elif frame == 8:
					check(left.is_equal_approx(first_left) and right.is_equal_approx(first_right),
						clip + " returns both hands to their initial pose")
			if frame == 4 and clip in ["OverheadSurge", "WaterHold"]:
				var wrist := rig.get_bone_global_pose(rig.find_bone("hand_r")).origin.y
				var shoulder := rig.get_bone_global_pose(rig.find_bone("upperarm_r")).origin.y
				check(wrist - shoulder > 0.25 if clip == "OverheadSurge" else shoulder - wrist > 0.25,
					clip + " preserves the distinct legacy wrist height")
			check(bounds.position.is_finite() and bounds.size.is_finite(),clip+" finite actual skin")
			check(bounds.position.y>-.025 and bounds.position.y<.025,clip+" anchored fluid base")
			check(bounds.size.length()<4.,clip+" bounded skin, no retarget explosion")
			if frame==0:check(bounds.size.y>1.5,clip+" restores living height after other actions")
			if frame==8 and clip in ["Death","Death2"]:check(bounds.size.y<.2 and not mesh.visible and actor.get_node("Puddle").visible,clip+" ends in a visible puddle rather than a flattened human")
			samples.append({"time":time,"position":[bounds.position.x,bounds.position.y,bounds.position.z],"size":[bounds.size.x,bounds.size.y,bounds.size.z]})
			if frame in [0,4,8]:
				material.set_shader_parameter("water_time",time)
				var image:=await capture(output+"/"+clip+"-%02d.png"%frame)
				var occupied:=0
				for y in range(0,768,3):
					for x in range(0,768,3):
						if image.get_pixel(x,y).a>.2:occupied+=1
				check(occupied>150,clip+" actual rendered surface is visible")
				if clip=="Idle" and frame==4:still=image
		rows.append({"clip":clip,"samples":samples})
	player.play("Idle",0.);player.seek(player.get_animation("Idle").length*.5,true);player.pause()
	material.set_shader_parameter("water_time",.75);var first:=await capture("")
	material.set_shader_parameter("water_time",2.);var flow:=await capture(output+"/flow.png")
	var flow_pixels:=difference(first,flow);check(flow_pixels>500,"Explicit flow phase changes actual pixels")
	material.set_shader_parameter("roughness",.95);var rough:=await capture(output+"/rough-control.png")
	var wet_pixels:=difference(flow,rough);check(wet_pixels>500,"Wet PBR differs measurably from rough control")
	print("WATER MATERIALS")
	# The server's raw full/partial hue fields tint actual shader pixels without
	# replacing the rig. Foam-only partial zones are explicitly authored.
	var rig_id:=rig.get_instance_id();var hues: Array=[]
	visual.set_hue(0);material=mesh.get_active_material(0);material.set_shader_parameter("water_time",1.)
	var undyed:=await capture("")
	for hue in [53,0x8035,0x901]:
		avatar.apply_server_appearance({"body":16,"hue":hue},[]);material=mesh.get_active_material(0);material.set_shader_parameter("water_time",1.)
		var dyed:=await capture(output+"/hue-%04x.png"%hue);var pixels:=difference(undyed,dyed)
		check(visual.native_hue==hue and rig.get_instance_id()==rig_id,"Exact native hue retains rig")
		check(pixels>20,"Native full/partial hue changes actual water pixels")
		hues.append({"hue":hue,"changed_pixels":pixels})
	check(int(hues[1].changed_pixels)<int(hues[0].changed_pixels)*.75,"Partial foam hue preserves most water")
	for request in [{"protocol":"classic","action":4},{"protocol":"classic","action":5},{"protocol":"classic","action":6},{"protocol":"classic","action":12},{"protocol":"new","type":11},{"protocol":"new","type":2},{"protocol":"new","type":14}]:check(avatar.receive_native_action(request),"Actual native combat category is consumed")
	for action: int in [17, 18]:
		check(avatar.receive_native_action({"protocol": "classic", "action": action})
			and visual.current_clip == ("WaterArmSettle" if action == 17 else "Fidget2"),
			"Actual avatar selects the distinct water fidget")
	visual.action_remaining=0.;visual.dead=false;visual.contact.enabled=true
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(20.,.1,20.);collider.shape=shape;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground)
	avatar.set_physics_process(true);visual.set_physics_process(true)
	var planes: Array=[]
	print("WATER SUPPORT")
	for level in [-.18,.21]:
		for slope in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,.06)]:
			for yaw in [0.,PI/2.]:
				ground.position.y=level;ground.rotation=Vector3(slope.x,0.,slope.y)
				for frame in 70:
					await physics_frame;avatar.animate(false,yaw,1./60.,0.);player.seek(.3,true);player.pause();await process_frame
				var hit:=avatar.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,1.,0.),Vector3(0.,-1.,0.),1))
				check(not hit.is_empty(),"Actual water support collider is sampled")
				if hit.is_empty():continue
				var arrays:=mesh.mesh.surface_get_arrays(0);var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var gap:=INF
				# The exactly root-bound bottom ring is immune to torso motion.
				for point in positions:
					if point.y<.001:gap=minf(gap,hit.normal.dot(mesh.global_transform*point-hit.position))
				check(gap>-.018 and gap<.018,"Vortex base fits finite sampled support plane")
				check(avatar.global_position.is_zero_approx(),"Support preserves server entity coordinates")
				planes.append({"level":level,"slope":[slope.x,slope.y],"yaw":yaw,"gap":gap})
	avatar.set_physics_process(false);visual.set_physics_process(false);avatar.ground_offset=0.;visual.model.transform=Transform3D.IDENTITY;avatar.visual_root.position=Vector3.ZERO;avatar.visual_root.rotation=Vector3.ZERO;avatar.rotation=Vector3.ZERO
	ground.free();avatar.visible=false
	print("WATER CORPSE")
	var posed:=Corpses.posed(16,53);posed.set_process(false)
	for child: MeshInstance3D in posed.find_children("*","MeshInstance3D",true,false):child.get_active_material(0).set_shader_parameter("water_time",1.25)
	var corpse:=Corpses.freeze(posed);viewport.add_child(corpse)
	check(corpse.get_meta("corpse_body")==16 and corpse.find_children("*","Skeleton3D",true,false).is_empty(),"Native body acquires matching rig-free static cadaver")
	check(corpse.get_child_count()==1 and corpse.get_child(0).name=="Puddle","Death cadaver is a puddle with no flattened human parts")
	var frozen: ShaderMaterial=corpse.get_child(0).get_active_material(0)
	var original: ShaderMaterial=posed.model.get_node("Puddle").get_active_material(0)
	check(frozen!=original and is_equal_approx(frozen.get_shader_parameter("water_time"),1.25),"Corpse owns an independent snapshot of the exact water phase")
	var frozen_before:=await capture(output+"/corpse.png")
	original.set_shader_parameter("water_time",99.);for frame in 6:await process_frame
	var frozen_after:=await capture("")
	check(difference(frozen_before,frozen_after)==0,"Corpse stays visually static while the former actor's phase changes")
	posed.free();corpse.free()
	for relative in runtime:check(runtime[relative]==FileAccess.get_sha256("res://../"+relative),"Validated input unchanged: "+relative)
	check(asset_sha==FileAccess.get_sha256("res://local-art/water-elemental/trial.scn") and candidate_sha==FileAccess.get_sha256("res://local-art/water-elemental/candidate.json"),"Candidate remains unchanged throughout validation")
	var file:=FileAccess.open(output+"/validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"asset_sha256":asset_sha,"candidate_sha256":candidate_sha,"runtime":runtime,"flow_pixels":flow_pixels,"wet_pixels":wet_pixels,"hues":hues,"planes":planes,"samples":rows},"  "));file.close()
	print("WATER TRIAL ",checks," checks, ",failures," failures; flow ",flow_pixels," wet ",wet_pixels)
	avatar.free();quit(0 if failures==0 else 1)
