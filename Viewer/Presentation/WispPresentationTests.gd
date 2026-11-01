extends SceneTree
## Actual avatar, deterministic shader phase, finite hover planes and static skin.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Wisp=preload("res://Presentation/WispVisual.gd")
var checks:=0
var failures:=0
var viewport: SubViewport
var output:="res://../outputs/creatures/wisp-trial"
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<20:push_error(label)
func capture() -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw;return viewport.get_texture().get_image()
func changed(a: Image,b: Image) -> int:
	var count:=0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var d:=a.get_pixel(x,y)-b.get_pixel(x,y)
			if absf(d.r)+absf(d.g)+absf(d.b)>.06:count+=1
	return count
func bounds(visual: Node3D) -> AABB:
	var first:=true;var result:=AABB()
	for mesh: MeshInstance3D in visual.model.find_children("*","MeshInstance3D",true,false):
		var box:=Geometry.deformed_bounds(mesh,visual.skeleton);result=box if first else result.merge(box);first=false
	return result
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output));Registry.load_index()
	var candidate:="res://local-art/wisp/candidate.json";var record: Dictionary
	if "--public" in OS.get_cmdline_user_args():record=Registry.entry(58);candidate="res://Art/Creatures/index.json"
	else:record=JSON.parse_string(FileAccess.get_file_as_string(candidate))
	Registry.entries[58]=record
	viewport=SubViewport.new();viewport.size=Vector2i(900,700);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.1;camera.position=Vector3(1.3,1.35,2.);viewport.add_child(camera);camera.look_at(Vector3(0.,.9,0.))
	var actor:=Avatar.new();actor.initial_body=58;actor.set_meta("own",true)
	var plate:=Node3D.new();plate.name="Nameplate";actor.add_child(plate)
	var picker:=StaticBody3D.new();picker.collision_layer=2;picker.set_meta("server_mobile",58);var pick_shape:=CollisionShape3D.new();pick_shape.shape=CapsuleShape3D.new();picker.add_child(pick_shape);actor.add_child(picker)
	viewport.add_child(actor);actor.apply_server_appearance({"body":58,"hue":0},[])
	var visual: Node3D=actor.horse_visual;check(visual is Wisp and actor.human_visual==null,"Actual avatar selects the Wisp energy presenter")
	visual.set_process(false);visual.set_physics_process(false);actor.set_physics_process(false)
	var rig: Skeleton3D=visual.skeleton;var instance:=rig.get_instance_id();check(rig.get_bone_count()==7,"Actual presenter keeps all seven authored bones")
	visual.play("Idle",0.);visual.animator.seek(.6,true);visual.animator.pause();var base:=await capture();base.save_png(ProjectSettings.globalize_path(output+"/avatar-default.png"))
	var hues: Array=[]
	for hue in [0x482,53,0x8035]:
		actor.apply_server_appearance({"body":58,"hue":hue},[]);var image:=await capture();var pixels:=changed(base,image)
		check(visual.native_hue==hue and rig.get_instance_id()==instance,"Native hue flags keep exact bits and original rig")
		check(pixels>80,"Full/partial native palettes visibly change the energy rays")
		for mesh: MeshInstance3D in visual.model.find_children("*","MeshInstance3D",true,false):
			var material:=mesh.get_active_material(0) as ShaderMaterial
			check(material.shader==preload("res://Presentation/WispSurface.gdshader") and material.get_meta("snapshot_uniform_time",false),"Real energy surfaces support explicit static snapshots")
		hues.append({"hue":hue,"changed_pixels":pixels});image.save_png(ProjectSettings.globalize_path(output+"/hue-%04x.png"%hue))
	actor.apply_server_appearance({"body":58,"hue":0},[])
	for code in [4,5,6,10,11,12,17,18]:
		visual.dead=false;visual.action_remaining=0.
		check(visual.receive_action({"protocol":"classic","action":code,"frame_count":6,"repeat_count":1,"delay":0}),"Explicit Wisp classic action consumed: "+str(code))
		check(visual.current_clip=={4:"Attack",5:"Attack2",6:"Attack3",10:"Hit",11:"Pillage",12:"Cast",17:"Fidget",18:"Fidget"}[code],"Native category selects the authored Wisp action")
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(8.,.1,8.);collider.shape=shape;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground)
	actor.set_physics_process(true);visual.set_physics_process(true);visual.dead=false;var terrain: Array=[]
	for height in [-.2,.25]:
		for slope in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,-.08)]:
			for yaw in [0.,PI/2.]:
				for category in ["Idle","Run","Cast"]:
					for phase in [.2,.65]:
						ground.position.y=height;ground.rotation=Vector3(slope.x,0.,slope.y);actor.rotation.y=yaw;visual.current_clip=category;visual.action_remaining=1000.;visual.play(category,0.)
						for frame in 18:
							await physics_frame;actor.animate(false,yaw,1./60.,0.);visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();await process_frame
						var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,2.,0.),Vector3(0.,-2.,0.),1))
						check(not hit.is_empty(),"Finite raised/lowered plane exists")
						if hit.is_empty():continue
						var root_pose:=rig.get_bone_global_pose(0).origin;var root_world:=rig.to_global(root_pose)
						var error:=absf(root_world.y-float(hit.position.y)-root_pose.y)
						check(actor.global_position.is_zero_approx(),"Hover never moves authoritative body coordinates")
						check(error<.004,"Actual energy root retains its authored height above the sampled plane")
						var box:=bounds(visual)
						check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.5,"All actual energy skins stay finite and nonempty")
						check(plate.global_position.y>box.end.y+.045,"Nameplate remains above the animated upper ray")
						var pick: AABB=visual.get_meta("pick_bounds");var pick_world: AABB=visual.global_transform*pick
						check(pick_world.grow(.01).encloses(box),"Conservative selection bounds contain the actual effect at both tested orientations")
						check(absf(visual.energy_phase-TAU*phase)<.001,"Shader phase follows the actual normalized animation phase")
						terrain.append({"height":height,"slope":[slope.x,slope.y],"yaw":yaw,"clip":category,"phase":phase,"hover_error":error})
	actor.free();ground.free();await process_frame
	var posed:=Corpses.posed(58,53);var expected_death:=bounds(posed);posed.free()
	var corpse:=Corpses.build(58,53);check(corpse!=null,"Native body58 produces an actual frozen energy cadaver")
	if corpse!=null:
		check((corpse.get_meta("corpse_bounds") as AABB).size.distance_to(expected_death.size)<.001,"Actual final weighted Death and frozen corpse dimensions match within one millimetre")
		check(corpse.find_children("*","Skeleton3D",true,false).is_empty(),"Spent Wisp corpse has no live skeleton")
		var surfaces:=0
		for mesh: MeshInstance3D in corpse.get_children():
			for surface in mesh.mesh.get_surface_count():
				surfaces+=1;var material:=mesh.get_active_material(surface) as ShaderMaterial
				check(absf(float(material.get_shader_parameter("phase"))-TAU)<.001,"Synchronous final Death seek freezes the actual final shader phase")
		check(surfaces==8,"All eight actual corpse skin surfaces survive freezing")
		camera.look_at(Vector3(0.,.2,0.));var empty:=await capture();viewport.add_child(corpse);var frozen:=await capture()
		check(changed(empty,frozen)>60,"The static energy corpse occupies actual rendered pixels, not only metadata")
		check(changed(frozen,await capture())==0,"Frozen corpse image stays static after further rendered frames")
		frozen.save_png(ProjectSettings.globalize_path(output+"/corpse.png"));corpse.free()
	var hashes: Dictionary={}
	for name in ["WispPresentationTests.gd","WispVisual.gd","WispMaterial.gd","WispSurface.gdshader","PrepareWisp.gd","CreatureRegistry.gd","CreatureVisual.gd","HumanAvatar.gd","CorpseModels.gd","SkinGeometry.gd"]:hashes["res://Presentation/"+name]=FileAccess.get_sha256("res://Presentation/"+name)
	var report:={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"terrain":terrain,"hues":hues,"candidate_sha256":FileAccess.get_sha256(candidate),"asset_sha256":FileAccess.get_sha256(record.assets.modern),"runtime_sha256":hashes,"scope":"Actual candidate Wisp avatar, explicit authored actions, full/partial native hues, normalized shader phase, finite hover planes, pick/nameplate and eight-surface static corpse. No native constructor or distribution acceptance yet."}
	var file:=FileAccess.open(output+"/presentation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("WISP PRESENTATION: ",checks," / ",failures," failures / ",terrain.size()," finite planes");quit(1 if failures else 0)
