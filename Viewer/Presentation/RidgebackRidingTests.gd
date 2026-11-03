extends "res://Presentation/SavageHumanProfileTests.gd"
## Client-only appearance/actions, original mounts, human Savage profiles/corpses.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Mounts=preload("res://Presentation/MountVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var output:="res://../work/creatures/ridgebacks/riding"
func _initialize() -> void:
	if DisplayServer.get_name()=="headless":output="res://../work/creatures/ridgebacks/riding-contact"
	create_timer(240.).timeout.connect(func():push_error("Ridgeback rider deadline");quit(1));call_deferred("run")
func image() -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	Registry.load_index();Profiles.load_index();var before:=Profiles.entries.duplicate(true)
	var prep_path:="res://local-art/creatures/source_preserving/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prep_path));var mounts: Dictionary={}
	for entry: Dictionary in prep.models:
		if not str(entry.kind).begins_with("ridgeback_"):continue
		var body:=int(entry.bodies[0].body);Registry.entries[body]=entry;mounts[body]=entry
	check(mounts.size()==3,"Three original Ridgeback forms prepared")
	var rider_path:="res://local-art/human-npcs/savages/riders.json";var riders: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(rider_path))
	for profile: Dictionary in riders.profiles:
		check(int(profile.body) in [185,186] and bool(profile.female)==(int(profile.body)==186),"Native Savage Rider gender/profile contract")
		Profiles.entries[int(profile.body)]=profile
	var pins: Dictionary={}
	for path in [prep_path,rider_path,"res://../scripts/savage-profile-inputs.json","res://local-art/creatures/accepted-index.json"]:pins[path]=FileAccess.get_sha256(path)
	viewport=SubViewport.new();viewport.size=Vector2i(1200,1000);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;viewport.add_child(camera)
	var samples: Array=[];var corpses: Array=[]
	for rider_body: int in [400,401,185,186]:
		var savage:=rider_body in [185,186];var female:=rider_body in [401,186]
		var actor:=Avatar.new();actor.initial_body=rider_body;viewport.add_child(actor);actor.set_process(false);actor.set_physics_process(false)
		check(actor.human_visual!=null and actor.human_visual.female==female,"Exact modern human/Savage Rider body/gender")
		var choices: Array=[188] if savage else [187,188,193]
		for mount_body: int in choices:
			var item:=int(mounts[mount_body].mount_item)
			check(Mounts.horse_body(item)==mount_body and Mounts.mount_available(mount_body,item),"Exact native item selects original Ridgeback presentation key")
			var outfits: Array=[[],[{"id":0x1f03},{"id":0x170b}],[{"id":0xf62,"layer":2,"hue":837},{"id":0x144e},{"id":0x1452}]]
			for outfit_index in outfits.size():
				var worn: Array=outfits[outfit_index].duplicate(true);worn.append({"id":item,"layer":25,"hue":0x4001 if mount_body==193 else 0})
				worn.append({"id":0x203c,"layer":11,"hue":53})
				if not female:worn.append({"id":0x2040,"layer":16,"hue":54})
				var entity:={"body":rider_body,"hue":0 if savage else 1002,"serial":800000+rider_body,"flags":0}
				var statistics:={"hits":87,"strength":101,"unknown_stat":9}
				var details:=preload("res://Network/MobileAppearance.gd").profile(entity,worn,statistics,"Native rider")
				actor.apply_server_appearance(entity,worn,details)
				check(actor.server_appearance.hair_id==0x203c and actor.server_appearance.hair_hue==53 and actor.server_appearance.statistics==statistics,"Native hair and all supplied statistics survive mounted profile")
				if not female:check(actor.server_appearance.beard_id==0x2040 and actor.server_appearance.beard_hue==54,"Native male beard type/colour stays independent of mount hue")
				check(actor.horse_visual!=null and actor.horse_visual.native_body==mount_body and actor.horse_visual.native_mount_item==item,"Actual layer25 dispatch retains exact source form/item")
				check(actor.human_visual.missing_art.is_empty(),"Robe and exact native TribalSpear/BoneArms/BoneLegs have prepared art")
				if outfit_index==2:check(bool(actor.human_visual.get_meta("armour_undercoat"))!=savage,"Native Savage bone arms expose painted torso; ordinary armour retains its backing")
				actor.rider_contact.begin_mount(false);actor.human_visual.set_process(false);actor.horse_visual.set_physics_process(false);actor.horse_visual.contact.active=false
				if savage:skin_arrays(actor.human_visual,true,DisplayServer.get_name()!="headless")
				for action: int in [23,24,25,26,27,28,29]:
					actor.human_visual.cancel_action()
					var request:={"body":rider_body,"protocol":"classic","action":action,"frames":8,"repeat":1,"delay":1}
					check(actor.receive_native_action(request),"All seven mounted classic groups reach actual human renderer")
					var source_clip:="Walk" if action==23 else "Run" if action==24 else "Idle"
					actor.horse_visual.play(source_clip,0.)
					for phase: float in [.2371,.7231]:
						actor.animator.seek(actor.animator.current_animation_length*phase,true);actor.animator.pause();actor.horse_visual.animator.seek(actor.horse_visual.animator.current_animation_length*phase,true);actor.horse_visual.animator.pause()
						for frame in 4:await process_frame
						var feet: Array=actor.rider_contact.stirrup_errors;var seat: float=actor.rider_contact.seat_error
						var good: bool=seat<.002 and feet.size()==2 and feet.all(func(error: float):return error<.025)
						check(good,"Post-modifier seat/ankle fitting: "+str([rider_body,mount_body,outfit_index,action,phase,seat,feet]))
						check(actor.transform.is_equal_approx(Transform3D.IDENTITY),"Presentation preserves authoritative actor root")
						samples.append({"rider_body":rider_body,"mount_body_key":mount_body,"native_mount_item":item,"outfit":outfit_index,"action":action,"phase":phase,"seat_m":seat,"feet_m":feet.duplicate(),"passed":good})
						if DisplayServer.get_name()!="headless" and outfit_index==2 and phase<.5 and action in [23,24,25]:
							var mesh: MeshInstance3D=actor.horse_visual.model.find_children("*","MeshInstance3D",true,false)[0];var box:=Geometry.deformed_bounds(mesh,actor.horse_visual.skeleton)
							for part: MeshInstance3D in actor.human_visual.find_children("*","MeshInstance3D",true,false):
								if not part.is_visible_in_tree():continue
								box=box.merge(Geometry.deformed_bounds(part,part.get_node(part.skeleton) as Skeleton3D) if part.skin!=null else part.global_transform*part.get_aabb())
							camera.size=box.size.length()*1.25;camera.position=box.get_center()+Vector3(-.8,.35,1.)*box.size.length();camera.look_at(box.get_center())
							(await image()).save_png(output+"/%d-%d-%d.png"%[rider_body,mount_body,action])
				if mount_body==193:
					var material:=actor.horse_visual.model.find_children("*","MeshInstance3D",true,false)[0].get_active_material(0) as ShaderMaterial
					check(material.shader==preload("res://Presentation/OstardEthereal.gdshader") and not material.get_shader_parameter("use_hue"),"Native default0x4001 keeps authored ethereal material without an accidental hue1")
		actor.apply_server_appearance({"body":rider_body,"hue":0 if savage else 1002},[])
		check(actor.retiring_horse and not actor.horse_visual.visible,"Dismount retains hidden sockets without duplicate loose creature")
		actor._finish_dismount();check(actor.horse_visual==null and not actor.human_visual.mounted_live_enabled,"Dismount removes ridden source model")
		if savage:
			for hue: int in [0,53,0x8035]:
				var corpse:=Corpses.build(rider_body,hue,[{"id":0xf62,"hue":837},{"id":0x144e},{"id":0x1452}])
				check(corpse!=null and corpse.get_meta("corpse_body")==rider_body and corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("native_hue")==hue,"Exact equipped Savage Rider corpse/body/raw hue")
				if corpse!=null:
					check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and corpse.find_children("*","AnimationPlayer",true,false).is_empty(),"Savage Rider cadaver is static")
					corpses.append({"body":rider_body,"hue":hue});corpse.free()
			actor.apply_server_appearance({"body":401 if female else 400,"hue":1002},[]);skin_arrays(actor.human_visual,false)
			check(actor.human_visual.native_body_profile.is_empty(),"Return to ordinary human removes Savage profile/paint")
		actor.free()
	Profiles.entries=before
	for path: String in pins:check(FileAccess.get_sha256(path)==pins[path],"Prepared inputs/accepted route unchanged throughout gate")
	var runtime: Dictionary={}
	for name in ["RidgebackRidingTests.gd","SavageHumanProfileTests.gd","SourceRidgebackVisual.gd","SourceRigMountVisual.gd","SourcePreservingCreatureVisual.gd","HumanAvatar.gd","HumanVisual.gd","HumanWardrobe.gd","HumanNPCProfiles.gd","SavageBodyPaint.gd","SavageSkin.gdshader","HumanActions.gd","HorseRider.gd","MountVisual.gd","CorpseModels.gd","OstardEthereal.gdshader"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	FileAccess.open(output+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"exact_paint_normals_tangents":DisplayServer.get_name()!="headless","samples":samples,"corpses":corpses,"inputs_sha256":pins,"runtime_sha256":runtime,"scope":"Client-only exact native-item dispatch into original Ridgeback forms; modern male/female and185/186Savage profiles, three outfits including pinned native gear, seven classic mounted actions/two phases, post-modifier seat2mm/ankles25mm, default ethereal hue, static equipped corpses and profile restoration.193 is an item-only source presentation key; no witnessed native loose193 constructor. No live permissions/AI/combat, universal triangle collision or family acceptance."},"\t"))
	print("RIDGEBACK RIDING: ",checks," checks / ",failures," failures / ",samples.size()," poses / ",corpses.size()," Savage Rider corpse cases");quit(1 if failures else 0)
