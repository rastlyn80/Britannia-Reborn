extends "res://Presentation/IceElementalDeathTests.gd"
## Shared rendered-avatar gate; inherited helpers decode 0xAF and measure skins.
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
var viewport: SubViewport
var camera: Camera3D
var output:="res://../work/creatures/batch-presentation"
var preparations:=PackedStringArray(["mummies/preparation.json","solen_warriors/preparation.json","ice_elementals/candidate.json"])
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--preparation="):preparations=arg.trim_prefix("--preparation=").split(",",false)
	create_timer(240.).timeout.connect(func():push_error("Candidate presentation batch deadline");quit(1))
	call_deferred("run")
func capture() -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func displayed_skin(visual: Node3D,state: Dictionary) -> PackedVector3Array:
	var result:=PackedVector3Array()
	for point: Vector3 in state.skin_local:result.append(visual.skeleton.global_transform*point)
	return result
func settle(actor: Node3D,visual: Node3D,clip: String,phase: float) -> void:
	visual.dead=false;visual.action_remaining=1000.;visual.play(clip,0.)
	visual.contact.enabled=not clip.begins_with("Death")
	for frame in 30:
		await physics_frame
		actor.animate(false,actor.rotation.y,1./60.,0.)
		visual.animator.seek(visual.animator.get_animation(clip).length*phase,true)
		visual.animator.pause()
		await process_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	Registry.load_index();var accepted_path:="res://local-art/creatures/accepted-index.json";var accepted_pin:=FileAccess.get_sha256(accepted_path)
	var entries: Array=[];var inputs: Dictionary={}
	for name in preparations:
		var path: String="res://local-art/creatures/"+name;inputs[path]=FileAccess.get_sha256(path)
		var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		for entry: Dictionary in prep.models:
			entries.append(entry);Registry.entries[int(entry.bodies[0].body)]=entry
			for treatment: String in ["original","rounded","modern"]:
				var asset:=Registry.asset_path(entry,treatment);inputs[asset]=FileAccess.get_sha256(asset)
				if FileAccess.file_exists(asset+".import"):inputs[asset+".import"]=FileAccess.get_sha256(asset+".import")
			for dependency: String in entry.get("art_dependency_sha256",{}):
				var dependency_path:="res://local-art/creatures/"+dependency;inputs[dependency_path]=FileAccess.get_sha256(dependency_path)
			if entry.has("ground_lookup"):inputs[str(entry.ground_lookup)]=FileAccess.get_sha256(str(entry.ground_lookup))
	viewport=SubViewport.new();viewport.size=Vector2i(960,720);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;viewport.add_child(camera)
	var arena:=Arena.new();viewport.add_child(arena)
	var platform:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(8.,.1,8.);shape.shape=box;shape.position.y=-.05;platform.add_child(shape);arena.add_child(platform)
	var game:=Game.new();root.add_child(game);game.set_process(false);var items:=Items.new();arena.add_child(items);var deaths:=Deaths.new();arena.add_child(deaths);deaths.configure(arena,game,items);deaths.set_process(false)
	var rows: Array=[];var death_rows: Array=[]
	for entry: Dictionary in entries:
		var body:=int(entry.bodies[0].body);var serial:=7000000+body;var corpse_serial:=0x40010000+body
		var folder:=output+"/"+str(entry.kind);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		for plane: Dictionary in [{"name":"flat","height":0.,"tilt":Vector3.ZERO},{"name":"cross","height":.15,"tilt":Vector3(.08,0.,-.08)}]:
			platform.position.y=plane.height;platform.rotation=plane.tilt;await physics_frame;await physics_frame
			var actor:=ActualAvatar.new();actor.initial_body=body;actor.set_meta("own",true)
			var plate:=Label3D.new();plate.name="Nameplate";plate.text=str(entry.kind);actor.add_child(plate)
			var picker:=StaticBody3D.new();picker.collision_layer=4;picker.collision_mask=0;picker.set_meta("server_mobile",true);var pick_shape:=CollisionShape3D.new();pick_shape.shape=BoxShape3D.new();picker.add_child(pick_shape);actor.add_child(picker);arena.add_child(actor)
			var entity:={"serial":serial,"body":body,"hue":53,"direction":0,"flags":0,"x":1100,"y":1700,"z":0}
			actor.apply_server_appearance(entity,[]);actor.set_process(false);actor.rotation.y=PI
			var visual: Node3D=actor.horse_visual;var rig: Skeleton3D=visual.skeleton
			visual.contact.active=true
			var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0];var whole:=Ground.skin_points(mesh,rig)
			var modified: Dictionary={"serial":0,"capture":false}
			visual.contact.modification_processed.connect(func():
				modified.serial=int(modified.serial)+1
				if not bool(modified.capture):return
				modified["box"]=Geometry.deformed_bounds(mesh,rig)
				var local_skin:=PackedVector3Array();var inverse:=rig.global_transform.affine_inverse()
				for point in skin(visual):local_skin.append(inverse*point)
				modified["skin_local"]=local_skin
				modified["minimum_gap"]=Ground.minimum_plane_gap(whole,rig,rig.global_transform,platform.position,platform.basis.y)
				modified["pick"]=visual.global_transform*(visual.get_meta("pick_bounds") as AABB)
				modified["collider"]=pick_shape.global_transform*AABB(-pick_shape.shape.size*.5,pick_shape.shape.size)
				modified["plate_y"]=plate.global_position.y
			)
			check(visual.get_script().resource_path==str(entry.presentation_script) and actor.human_visual==null and visual.native_body==body,"Actual avatar selects the exact candidate renderer/body")
			for clip: String in entry.stats.original.clips:
				var phase:=.2371 if str(plane.name)=="flat" else .7231
				await settle(actor,visual,clip,phase)
				var previous:=int(modified.serial);modified.capture=true
				visual.animator.seek(visual.animator.get_animation(clip).length*phase,true)
				for frame in 3:await process_frame
				await RenderingServer.frame_post_draw
				check(int(modified.serial)>previous and modified.has("box"),"Fresh final modifier pose reaches the actual render stage")
				if not modified.has("box"):continue
				var bounds: AABB=modified.box
				check(bounds.position.is_finite() and bounds.size.is_finite() and float(modified.minimum_gap)>-.008,"Complete rendered skin is finite and stays above the real plane within8mm")
				check((modified.pick as AABB).grow(.001).encloses(bounds) and (modified.collider as AABB).grow(.001).encloses(bounds),"Final render pose is enclosed by actual picking bounds/collider")
				check(float(modified.plate_y)>bounds.end.y+.015 and actor.position.is_zero_approx(),"Final-pose nameplate clears body and native root is unchanged")
				camera.size=bounds.size.length()*1.15;camera.position=bounds.get_center()+Vector3(0.,.5,2.)*camera.size;camera.look_at(bounds.get_center())
				var image:=await capture();modified.capture=false;image.save_png(folder+"/"+str(plane.name)+"-"+clip.to_lower()+".png")
				rows.append({"kind":entry.kind,"body":body,"plane":plane.name,"clip":clip,"phase":phase,"minimum_gap_m":modified.minimum_gap})
			await settle(actor,visual,"Run",.37);modified.capture=true;visual.animator.seek(visual.animator.get_animation("Run").length*.37,true);await capture()
			modified.capture=false
			var displayed:=displayed_skin(visual,modified)
			actor.set_physics_process(false);visual.set_physics_process(false);visual.set_process(false);visual.contact.active=false
			game.entities[serial]=entity.duplicate(true);arena.avatars[serial]=actor
			game._handle(packet(serial,corpse_serial))
			check(deaths.active.has(serial),"Decoded0xAF creates the actual candidate death snapshot")
			if deaths.active.has(serial):
				var snapshot: Node3D=deaths.active[serial].visual;snapshot.set_process(false);snapshot.set_physics_process(false);snapshot.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;snapshot.animator.seek(0.,true);snapshot.animator.advance(0.);snapshot.skeleton.force_update_all_bone_transforms()
				var first:=skin(snapshot);var error:=0.
				if first.size()==displayed.size():
					for vertex in first.size():error=maxf(error,first[vertex].distance_to(displayed[vertex]))
				else:error=INF
				check(error<.001,"First death skin matches the actual displayed render-stage source within1mm")
				var image:=await capture();image.save_png(folder+"/"+str(plane.name)+"-death-entry.png")
				death_rows.append({"kind":entry.kind,"body":body,"plane":plane.name,"first_displayed_skin_error_m":error})
				deaths.finish(serial)
			arena.avatars.erase(serial);game.entities.erase(serial);actor.free();await process_frame
		print("CANDIDATE GPU BODY ",body," / cumulative failures ",failures)
	check(accepted_pin==FileAccess.get_sha256(accepted_path),"Rendered candidate batch leaves accepted catalogue unchanged")
	for path: String in inputs:check(inputs[path]==FileAccess.get_sha256(path),"Prepared input unchanged throughout rendered batch")
	var runtime: Dictionary={}
	for file in ["SourcePreservingCreatureVisual.gd","SourceVariantPoseEntry.gd","SourceBloodElementalVisual.gd","SourceLavaSerpentVisual.gd","SourceLavaSerpentSurface.gdshader","SourceSilverSerpentVisual.gd","SourceSilverSerpentMaterial.gd","SourceSilverSerpentSurface.gdshader","SourceFluidElementalVisual.gd","SourceFluidElementalMaterial.gd","SourceFluidElementalSurface.gdshader","SourceElementalVisual.gd","SourceElementalMaterial.gd","SourceElementalSurface.gdshader","SourcePlaneSoleSupport.gd","SmallSnakeVisual.gd","MeasuredCreatureVisual.gd","MeasuredCreatureSupport.gd","SourceBipedVisual.gd","SourceBipedSupport.gd","CreatureVisual.gd","SourceMountContact.gd","BirdGroundSupport.gd","FootContact.gd","OstardVisual.gd","HumanHue.gd","HumanActions.gd","CandidatePresentationBatchTests.gd","IceElementalDeathTests.gd","CreatureDeathTests.gd","CreatureDeaths.gd","ItemStudio.gd","SourceMummyVisual.gd","SourceRenderedPose.gd","SourceMummySupport.gd","SourceSolenWarriorVisual.gd","SourceSolenWarriorSupport.gd","SourceIceElementalVisual.gd","SourceIceElementalSupport.gd","SourceIceElementalMaterial.gd","SourceIceElementalSurface.gdshader","SourcePoseEntry.gd","HumanAvatar.gd","CreatureRegistry.gd","CorpseModels.gd","SourceGroundLookup.gd","SkinGeometry.gd"]:runtime[file]=FileAccess.get_sha256("res://Presentation/"+file)
	for file in ["SourceSwampDragonVisual.gd","MountVisual.gd","HorseRider.gd"]:runtime[file]=FileAccess.get_sha256("res://Presentation/"+file)
	var report:={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"samples":rows,"death_entries":death_rows,"inputs_sha256":inputs,"runtime_sha256":runtime,"scope":"Actual registered avatars and post-modifier complete skins/picking/nameplates over two finite planes and one declared source phase per plane/clip, with actual GPU images; decoded fixture0xAF entry from the displayed Run pose. No native-server, exhaustive transitions, ledge/spawn or partial-dye pixel certification."}
	FileAccess.open(output+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CANDIDATE PRESENTATION BATCH: ",checks," checks / ",failures," failures / ",rows.size()," rendered poses / ",death_rows.size()," death entries")
	quit(1 if failures else 0)
