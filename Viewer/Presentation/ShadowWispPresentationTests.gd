extends "res://Presentation/WispPresentationTests.gd"
## Reuse the owned Wisp rig, exercising the actual body165 avatar/material path.
const Shadow=preload("res://Presentation/ShadowWispVisual.gd")
func _initialize() -> void:
	output="res://../work/creatures/shadow-wisp/validation"
	create_timer(180.).timeout.connect(func():push_error("Shadow Wisp presentation deadline");quit(1))
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output));Registry.load_index()
	var path:="res://local-art/creatures/shadow_wisps/preparation.json"
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var record: Dictionary=preparation.models[0]
	var accepted_pin:=FileAccess.get_sha256("res://local-art/creatures/accepted-index.json")
	var donor_pin:=FileAccess.get_sha256(record.assets.modern);var donor_entry:=Registry.entry(58).duplicate(true)
	var normal_route:=Registry.supports_body(165)
	if normal_route:
		var expected:=record.duplicate(true);expected.status="validated"
		check(Registry.entry(165)==expected,"Normal accepted Shadow Wisp route retains the prepared record")
	else:Registry.entries[165]=record
	viewport=SubViewport.new();viewport.size=Vector2i(800,640);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.7;camera.position=Vector3(1.3,1.2,2.);viewport.add_child(camera);camera.look_at(Vector3(0.,.75,0.))
	var actor:=Avatar.new();actor.initial_body=165;actor.set_meta("own",true)
	var plate:=Node3D.new();plate.name="Nameplate";actor.add_child(plate)
	var picker:=StaticBody3D.new();picker.collision_layer=2;picker.set_meta("server_mobile",165);var pick_shape:=CollisionShape3D.new();pick_shape.shape=CapsuleShape3D.new();picker.add_child(pick_shape);actor.add_child(picker)
	viewport.add_child(actor);actor.apply_server_appearance({"body":165,"hue":0},[]);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;check(visual is Shadow and actor.human_visual==null,"Actual body165 avatar selects its scoped shadow renderer")
	visual.set_process(false);visual.set_physics_process(false);visual.contact.active=false
	check(visual.skeleton.get_bone_count()==7 and visual.model.find_children("*","MeshInstance3D",true,false).size()==8,"Shared complete seven-bone/eight-surface owned asset retained")
	var skins:=0
	for clip: String in record.stats.original.clips:
		for phase in [0.,.2371,.6197,1.]:
			visual.dead=false;visual.play(clip,0.);visual.animator.seek(visual.animator.get_animation(clip).length*phase,true);visual.animator.pause();visual.skeleton.force_update_all_bone_transforms();visual.update_energy_pose()
			var box:=bounds(visual);check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.05 and box.size.length()<3.,"Complete shadow skin remains finite across every authored action")
			check(actor.global_position.is_zero_approx(),"Authored action never changes native actor coordinates");skins+=8
	visual.dead=false;visual.play("Idle",0.);visual.animator.seek(.6,true);visual.animator.pause()
	var base:=await capture();base.save_png(output+"/native-0000.png");var hues: Array=[]
	for hue in [0x901,53,0x8035]:
		actor.apply_server_appearance({"body":165,"hue":hue},[]);var picture:=await capture();var pixels:=changed(base,picture)
		check(visual.native_body==165 and visual.native_hue==hue,"Actual avatar preserves wild/familiar/full/partial raw identity")
		check(pixels>80,"Actual shadow surface visibly responds to native hue")
		for mesh: MeshInstance3D in visual.model.find_children("*","MeshInstance3D",true,false):
			var material:=mesh.get_active_material(0) as ShaderMaterial
			check(material.shader==preload("res://Presentation/ShadowWispSurface.gdshader") and material.get_meta("snapshot_uniform_time",false),"Scoped surface retains explicit snapshot phase")
		hues.append({"hue":hue,"changed_pixels":pixels});picture.save_png(output+"/native-%04x.png"%hue)
	actor.apply_server_appearance({"body":165,"hue":53},[]);var full:=await capture();actor.apply_server_appearance({"body":165,"hue":0x8035},[]);var partial:=await capture()
	check(changed(full,partial)>30,"Partial dye preserves a different dark core than full dye")
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(8.,.1,8.);collider.shape=shape;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground)
	visual.set_physics_process(true);var terrain: Array=[]
	for height in [0.,.25]:
		for tilt in [Vector3.ZERO,Vector3(.08,0.,0.),Vector3(0.,0.,-.08)]:
			for yaw in [0.,PI/2.]:
				for clip in ["Idle","Run","Cast"]:
					ground.position.y=height;ground.rotation=tilt;actor.rotation.y=yaw;visual.dead=false;visual.current_clip=clip;visual.action_remaining=1000.;visual.play(clip,0.)
					for frame in 12:
						await physics_frame;actor.animate(false,yaw,1./60.,0.);visual.animator.seek(visual.animator.get_animation(clip).length*.35,true);visual.animator.pause();await process_frame
					var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3.UP*2.,Vector3.DOWN*2.,1))
					check(not hit.is_empty(),"Finite hover plane is actually sampled")
					var root_pose: Vector3=visual.skeleton.get_bone_global_pose(0).origin;var error:=absf(visual.skeleton.to_global(root_pose).y-float(hit.position.y)-(visual.skeleton.global_basis*root_pose).y)
					check(error<.004 and actor.global_position.is_zero_approx(),"Scaled shadow root keeps its authored height above finite ground")
					var box:=bounds(visual);check((visual.global_transform*(visual.get_meta("pick_bounds") as AABB)).grow(.01).encloses(box),"Selection bounds contain the actual scaled effect")
					check(plate.global_position.y>box.end.y+.045,"Nameplate remains above the visible upper ray")
					terrain.append({"height":height,"tilt":tilt,"yaw":yaw,"clip":clip,"error_m":error})
	actor.free();ground.free();await process_frame
	var corpse_rows: Array=[]
	for hue in [0,0x901,0x8035]:
		var posed:=Corpses.posed(165,hue);var expected:=bounds(posed);posed.free();var corpse:=Corpses.build(165,hue)
		check(corpse!=null,"Native graphic165 has a real frozen corpse")
		check(corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("corpse_body")==165 and corpse.get_meta("native_hue")==hue,"Frozen corpse retains native graphic/body/raw hue")
		check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and (corpse.get_meta("corpse_bounds") as AABB).size.distance_to(expected.size)<.001,"All source surfaces freeze without a live rig or shape change")
		camera.look_at(Vector3(0.,.15,0.));var empty:=await capture();viewport.add_child(corpse);var picture:=await capture()
		check(changed(empty,picture)>60,"Frozen shadow corpse occupies actual pixels")
		check(changed(picture,await capture())==0,"Frozen shadow corpse image remains static")
		picture.save_png(output+"/corpse-%04x.png"%hue);corpse_rows.append({"hue":hue});corpse.free()
	check(donor_pin==FileAccess.get_sha256(record.assets.modern) and donor_entry==Registry.entry(58),"Original owned Wisp scene and public body58 registry remain unchanged")
	check(accepted_pin==FileAccess.get_sha256("res://local-art/creatures/accepted-index.json"),"Candidate review leaves active local routes unchanged")
	var runtime: Dictionary={}
	for name in ["ShadowWispPresentationTests.gd","WispPresentationTests.gd","ShadowWispVisual.gd","ShadowWispSurface.gdshader","WispVisual.gd","WispMaterial.gd","WispSurface.gdshader","CreatureRegistry.gd","CreatureVisual.gd","OstardVisual.gd","HumanAvatar.gd","CorpseModels.gd","SkinGeometry.gd","HumanHue.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	FileAccess.open(output+"/presentation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"preparation_sha256":FileAccess.get_sha256(path),"asset_sha256":donor_pin,"complete_skins":skins,"hues":hues,"terrain":terrain,"corpses":corpse_rows,"runtime_sha256":runtime,"scope":"Actual body165 candidate avatar, all reused owned action envelopes, visible full/partial/familiar hue response,36finite hover cases with picking/nameplate and3actual frozen static corpses. OriginalWisp58 remains unchanged. No native-live/AI/ownership/mana-restoration/continuousterrain or distribution acceptance."},"\t"))
	print("SHADOW WISP PRESENTATION: ",checks," checks / ",failures," failures / ",skins," complete skins / ",terrain.size()," hover cases");quit(1 if failures else 0)
