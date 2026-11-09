extends "res://Presentation/HumanNPCDeathTests.gd"
## Actual post-rider skin -> decoded0xAF -> grounded static corpse lifecycle.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
var output:="res://../work/creatures/ridgebacks/death"
func _initialize() -> void:
	if DisplayServer.get_name()=="headless":output+="-contact"
	if "--verification" in OS.get_cmdline_user_args():output+="-verification"
	create_timer(240.).timeout.connect(func():push_error("Mounted human death deadline");quit(1));call_deferred("run")
func body_skin(human: Node3D) -> PackedVector3Array:
	var result:=PackedVector3Array();var rig: Skeleton3D=human.skeleton
	for mesh: MeshInstance3D in human.find_children("Body*","MeshInstance3D",true,false):
		if not mesh.visible or mesh.skin==null:continue
		var transforms: Array[Transform3D]=[]
		for bind in mesh.skin.get_bind_count():
			var bone:=mesh.skin.get_bind_bone(bind)
			if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
			transforms.append(rig.global_transform*rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
		for surface in mesh.mesh.get_surface_count():
			var a:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var bones: PackedInt32Array=a[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride:=bones.size()/vertices.size()
			for vertex in vertices.size():
				var point:=Vector3.ZERO
				for slot in stride:point+=(transforms[bones[vertex*stride+slot]]*vertices[vertex])*weights[vertex*stride+slot]
				result.append(point)
	return result
func capture(viewport: SubViewport) -> void:
	for frame in 3:await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	Registry.load_index();Profiles.load_index();var saved:=Profiles.entries.duplicate(true)
	var prep_path:="res://local-art/creatures/source_preserving/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prep_path))
	for entry: Dictionary in prep.models:
		if str(entry.kind)=="ridgeback_savage":Registry.entries[188]=entry
	var rider_path:="res://local-art/human-npcs/savages/riders.json";var riders: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(rider_path))
	for profile: Dictionary in riders.profiles:Profiles.entries[int(profile.body)]=profile
	var viewport:=SubViewport.new();viewport.size=Vector2i(1000,900);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.4;camera.position=Vector3(4.,3.,6.);viewport.add_child(camera);camera.look_at(Vector3(0.,1.1,0.))
	var arena:=Arena.new();viewport.add_child(arena);var game:=Game.new();root.add_child(game);game.set_process(false);var items:=Items.new();arena.add_child(items);var deaths:=Deaths.new();arena.add_child(deaths);deaths.configure(arena,game,items);deaths.set_process(false)
	var floor:=StaticBody3D.new();arena.add_child(floor);var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(8.,.1,8.);collider.shape=shape;collider.position.y=-.05;floor.add_child(collider)
	var ground:=MeshInstance3D.new();var ground_mesh:=BoxMesh.new();ground_mesh.size=shape.size;ground.mesh=ground_mesh;ground.position.y=-.05;floor.add_child(ground);var material:=StandardMaterial3D.new();material.albedo_color=Color(.12,.15,.17);material.roughness=.9;ground.material_override=material
	var records: Array=[]
	for body: int in [185,186,400,401]:
		for hue: int in [0,0x8035]:
			for removed_first: bool in [false,true]:
				for gait: String in ["Walk","Run"]:
					var actor:=Avatar.new();actor.initial_body=body;arena.add_child(actor);actor.set_process(false);actor.set_physics_process(false)
					var serial:=900000+body;var corpse_serial:=0x40030000+body;var entity:={"serial":serial,"body":body,"hue":hue,"direction":4,"flags":0}
					var gear: Array=[{"id":0xf62,"layer":2,"hue":837},{"id":0x144e},{"id":0x1452}];var worn:=gear.duplicate(true);worn.append({"id":0x3eb8 if body in [185,186] else 0x3e9f,"layer":25,"hue":0})
					actor.apply_server_appearance(entity,worn);actor.rider_contact.begin_mount(false);actor.horse_visual.set_physics_process(false);actor.horse_visual.contact.active=false
					var human: Node3D=actor.human_visual;human.set_process(false);human.cancel_action();human.play("Rider_"+gait,0.);actor.horse_visual.animator.play(gait if body in [185,186] else "walk" if gait=="Walk" else "gallop",0.)
					var submitted: Dictionary={}
					actor.rider_contact.modification_processed.connect(func():submitted["points"]=body_skin(human))
					human.animator.seek(human.animator.current_animation_length*.371,true);human.animator.pause();actor.horse_visual.animator.seek(actor.horse_visual.animator.current_animation_length*.371,true);actor.horse_visual.animator.pause()
					await capture(viewport)
					check(submitted.has("points") and not submitted.points.is_empty(),"Actual rider modifier produced a complete reference skin")
					var reference: PackedVector3Array=submitted.get("points",PackedVector3Array()).duplicate();var floor_anchor: Vector3=actor.visual_root.global_position
					if removed_first:actor.apply_server_appearance(entity,gear)
					arena.avatars[serial]=actor;game.entities[serial]=entity.duplicate(true)
					game._handle(packet(serial,corpse_serial));check(deaths.active.has(serial),"Decoded0xAF accepts native Savage Rider body")
					if not deaths.active.has(serial):actor.free();continue
					var visual: Node3D=deaths.active[serial].visual
					if not removed_first:actor.apply_server_appearance(entity,gear)
					visual.set_process(false);visual.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;visual.animator.seek(0.,true);visual.animator.advance(0.);visual.skeleton.force_update_all_bone_transforms()
					var first:=body_skin(visual);var error:=0.
					if first.size()!=reference.size():error=INF
					else:
						for vertex in first.size():error=maxf(error,first[vertex].distance_to(reference[vertex]))
					check(error<.001,"First death skin matches the actual displayed rider within1mm: "+str([body,hue,removed_first,gait,error]))
					if DisplayServer.get_name()!="headless" and removed_first and hue==0:
						await capture(viewport)
						viewport.get_texture().get_image().save_png(output+"/%d-%s-entry.png"%[body,gait])
					check(visual.native_body==body and visual.native_hue==hue,"Snapshot preserves exact rider body/raw hue")
					var minimum:=INF
					for phase: float in [.15,.4,.7,1.]:
						visual.animator.seek(visual.action_duration*phase,true);visual.animator.advance(0.);visual.skeleton.force_update_all_bone_transforms()
						for point: Vector3 in body_skin(visual):minimum=minf(minimum,point.y-floor_anchor.y)
					check(visual.global_position.distance_to(floor_anchor)<.001,"Rider collapse ends at the server actor's ground anchor")
					check(minimum>=-.004,"Mounted collapse stays above the sampled flat ground")
					if DisplayServer.get_name()!="headless" and removed_first and hue==0:
						await capture(viewport)
						viewport.get_texture().get_image().save_png(output+"/%d-%s-end.png"%[body,gait])
					var static_pose:=Corpses.posed(body,hue,gear)
					if static_pose!=null:
						static_pose.visible=false
						if DisplayServer.get_name()!="headless":await capture(viewport)
					check(static_pose!=null,"Exact rider body/gear has a final corpse pose")
					if static_pose!=null:
						for bone in visual.skeleton.get_bone_count():check(visual.skeleton.get_bone_pose(bone).is_equal_approx(static_pose.skeleton.get_bone_pose(bone)),"Rider death ends on the existing static corpse skeleton")
						static_pose.queue_free()
					var remove:=PackedByteArray([0x1d]);remove.append_array(Wire.uint_be(serial,4));game._handle(remove);arena.avatars.erase(serial);actor.free();check(is_instance_valid(visual),"Rider death snapshot survives native actor removal")
					deaths.finish(serial);await process_frame
					records.append({"body":body,"hue":hue,"mount_removed_first":removed_first,"gait":gait,"first_skin_error_m":error,"minimum_body_y_m":minimum})
	Profiles.entries=saved
	var inputs: Dictionary={}
	for path in [prep_path,rider_path]:inputs[path]=FileAccess.get_sha256(path)
	var runtime: Dictionary={}
	for name in ["MountedHumanDeathTests.gd","HumanNPCDeathTests.gd","HumanNPCDeathVisual.gd","HorseRider.gd","SourceRenderedPose.gd","CreatureDeaths.gd","HumanAvatar.gd","HumanVisual.gd","CorpseModels.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	FileAccess.open(output+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"cases":records,"inputs_sha256":inputs,"runtime_sha256":runtime,"scope":"Client decoded0xAF death from post-rider modifier skin, male/female humans on ordinary horses and SavageRiders on original Ridgebacks, Walk/Run, raw normal/partial hues, layer25 removal immediately before or after trigger, first complete body skin1mm, final ground anchor1mm, sampled flat-floor4mm and existing static corpse bones. Real GPU when renderer says forward_plus; headless is CPU modifier proof only. No native server packet order, physics ragdoll, ledge/continuous collision or mounted-death family acceptance."},"\t"))
	print("MOUNTED HUMAN DEATH: ",checks," checks / ",failures," failures / ",records.size()," cases");quit(1 if failures else 0)
