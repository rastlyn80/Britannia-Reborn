extends "res://Presentation/SavageHumanProfileTests.gd"
## Actual accepted profiles; no candidate injection or server-gameplay claims.
const Mounts=preload("res://Presentation/MountVisual.gd")
const RidgebackVisual=preload("res://Presentation/SourceRidgebackVisual.gd")
var graphical:=false
var output:=""
func _initialize() -> void:
	graphical=DisplayServer.get_name()!="headless"
	output="res://../work/creatures/savages/normal-routes" if graphical else "res://../work/creatures/savages/normal-contact"
	create_timer(180.).timeout.connect(func():push_error("Savage normal-route deadline");quit(1))
	call_deferred("run")
func run() -> void:
	Profiles.load_index();var path:="res://local-art/human-npcs/accepted-index.json";var pin:=FileAccess.get_sha256(path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=Vector2i(800,640);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.7;camera.position=Vector3(.8,1.1,4.);viewport.add_child(camera);camera.look_at(Vector3(0.,1.,0.))
	var empty: Image
	if graphical:empty=await capture()
	for body in [183,184,185,186]:
		var profile:=Profiles.entry(body)
		check(profile.get("status","")=="validated" and profile.get("skin","")=="savage","Normal accepted profile is available")
		for hue in [0,53,0x8035]:
			var entity:={"serial":9000000+body,"body":body,"hue":hue,"flags":0,"direction":0,"x":1100,"y":1700,"z":0}
			var actor:=Avatar.new();actor.initial_body=body;viewport.add_child(actor);actor.apply_server_appearance(entity,[]);actor.set_process(false);actor.set_physics_process(false)
			var human: Node3D=actor.human_visual;human.set_process(false)
			check(human!=null and human.female==(body in [184,186]) and actor.horse_visual==null,"Normal avatar uses the correct human gender")
			check(actor.native_body==body and actor.server_appearance.skin_hue==hue and human.skin_hue==hue and human.native_body_profile.body==body,"Native body/hue/profile survive the normal appearance path")
			check(human.animator.has_animation("Savage_Dance") and human.get_meta("native_dance_sha256","")==profile.tribal_dance.sha256,"The normal profile installs its exact gender dance")
			check(actor.receive_native_action({"body":body,"protocol":"classic","action":111,"frames":5,"delay":0}) and human.action_clip=="Savage_Dance","Native111 reaches the installed original-retargeted action")
			human.animator.seek(human.animator.get_animation("Savage_Dance").length*.4,true);human.animator.pause();human.skeleton.force_update_all_bone_transforms()
			skin_arrays(human,true,graphical)
			check(actor.position.is_zero_approx(),"Dance leaves the native actor coordinates unchanged")
			if graphical:
				var image:=await capture();check(changed(empty,image)>150,"Normal painted dancer occupies actual pixels");image.save_png(output+"/%d-%04x-dance.png"%[body,hue])
			actor.free()
			if body in [185,186]:
				var rider:=Avatar.new();rider.initial_body=body;viewport.add_child(rider)
				rider.apply_server_appearance(entity,[{"id":0x3eb8,"layer":25,"hue":hue}]);rider.set_process(false);rider.set_physics_process(false)
				check(rider.human_visual!=null and rider.human_visual.mounted_live_enabled,"Normal native layer25 mounts the Savage Rider")
				check(rider.horse_visual is RidgebackVisual and rider.horse_visual.native_body==188 and rider.horse_visual.native_hue==hue,"Native Savage Ridgeback uses the accepted original renderer and raw hue")
				for frame in 36:rider.animate(true,0.,1./60.,1.8);await process_frame
				if graphical:
					camera.size=3.6;camera.look_at(Vector3(0.,1.15,0.));var image:=await capture();check(changed(empty,image)>150,"Normal walking Savage Rider occupies actual pixels");image.save_png(output+"/%d-%04x-riding.png"%[body,hue]);camera.size=2.7;camera.look_at(Vector3(0.,1.,0.))
				rider.free()
			var corpse:=Corpses.build(body,hue);check(corpse!=null,"Normal accepted body has an actual cadaver")
			check(corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("corpse_body")==body and corpse.get_meta("native_hue")==hue,"Cadaver preserves native graphic/body/raw hue")
			check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and corpse.find_children("*","AnimationPlayer",true,false).is_empty(),"Cadaver has no live animation rig")
			corpse.free();rows.append({"body":body,"hue":hue})
	var plain:=Avatar.new();plain.initial_body=400;viewport.add_child(plain);plain.apply_server_appearance({"body":400,"hue":0},[])
	check(plain.human_visual.native_body_profile.is_empty() and not plain.human_visual.animator.has_animation("Savage_Dance"),"Ordinary humans retain their own profile and animation library");plain.free()
	check(pin==FileAccess.get_sha256(path),"Normal route test leaves the accepted profile index unchanged")
	var runtime: Dictionary={}
	for name in ["SavageNormalRouteTests.gd","SavageHumanProfileTests.gd","HumanNPCProfiles.gd","HumanNPCMotion.gd","HumanAvatar.gd","HumanVisual.gd","HumanWardrobe.gd","CorpseModels.gd","SourceRidgebackVisual.gd","SourceRigMountVisual.gd","HorseRider.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	FileAccess.open(output+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":rows,"graphical":graphical,"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"runtime_sha256":runtime,"profile_index_sha256":pin,"scope":"Normal accepted human NPC profiles, exact dance111, paint attributes/raw hues, native SavageRidgeback dispatch and static corpses; actual GPU frames only when graphical=true. No native server/AI/loot claim."},"\t"))
	print("SAVAGE NORMAL ROUTES: ",checks," checks / ",failures," failures / graphical=",graphical);quit(1 if failures else 0)
