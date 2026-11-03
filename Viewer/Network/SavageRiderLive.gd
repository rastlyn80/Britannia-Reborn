extends "res://Network/SavageLive.gd"
## Accepted human/mount routes driven by original native Rider constructors and packets.
var appearance_events: Array=[[],[]]
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Native Savage Rider deadline");quit(1));call_deferred("run")
func reply(client: int,command: String) -> String:
	replies[client].clear();sessions[client].send_command("[SavageRiderFixture "+command)
	if not check(await until(func():return not replies[client].is_empty()),"Native Rider reply: "+command):return ""
	var result:=str(replies[client][-1])
	if not check(not result.begins_with("UCRIDER|blocked|"),"Native Rider accepts the controlled operation: "+result):return ""
	return result
func worn(client: int,serial: int) -> Array:
	return sessions[client].mobile_equipment.get(serial,{}).values()
func mount_item(client: int,serial: int) -> Dictionary:
	return preload("res://Presentation/MountVisual.gd").mount_item(worn(client,serial))
func refresh(client: int,serial: int) -> void:
	if actors.has(serial) and sessions[client].entities.has(serial):
		actors[serial][client].apply_server_appearance(sessions[client].entities[serial],worn(client,serial))
func rider_death(owner: int,serial: int,body: int,mount_serial: int) -> Dictionary:
	var original_worn:=worn(owner,serial).duplicate(true)
	var direction:=int(sessions[owner].entities[serial].direction)
	var hue:=int(sessions[owner].entities[serial].hue)
	for client in 2:appearance_events[client].clear()
	var response: PackedStringArray=(await reply(owner,"kill")).split("|")
	if not check(response.size()==7 and response[1]=="corpse" and int(response[3])==body and response[4]=="1" and response[5]=="1" and response[6]=="1","Native OnBeforeDeath unseats and deletes its own Ridgeback and mount item, then produces the rider corpse"):return {}
	var corpse:=int(response[2]);var witnesses: Array=[]
	if not check(await until(func():return death_events[0].has(serial) and death_events[1].has(serial)),"Native Rider0xAF starts actual human death transitions on both clients"):return {}
	for client in 2:
		if not check(await until(func():return sessions[client].world_items.has(corpse) and not sessions[client].entities.has(serial) and not sessions[client].entities.has(mount_serial)),"Both clients receive the native cadaver and retain neither a live rider nor a loose deleted mount"):return {}
		var event: Dictionary=death_events[client][serial]
		if not check(event.corpse==corpse and event.body==body and event.hue==hue and event.clip=="Death" and event.grounded,"Native Rider death uses its real human identity, hue and grounded death animation"):return {}
		if not check(preload("res://Presentation/MountVisual.gd").mount_item(event.equipment).is_empty(),"Death snapshot excludes the native-deleted mount item"):return {}
		var expected_worn:=equipment_identity(original_worn.filter(func(item: Dictionary):return int(item.get("layer",0))!=25))
		var actual_worn:=equipment_identity(event.equipment)
		if not check(actual_worn==expected_worn,"Original native clothing survives mount removal into the death snapshot: expected "+str(expected_worn)+", actual "+str(actual_worn)):return {}
		var saw_unseat:=false
		for observed: Dictionary in appearance_events[client]:
			if observed.serial==serial and not observed.mounted:saw_unseat=true
		if not check(saw_unseat,"Native mount-layer removal was observed before death"):return {}
		var item: Dictionary=sessions[client].world_items[corpse]
		if not check(int(item.id)==0x2006 and int(item.amount)==body and int(item.hue)==hue,"Actual static corpse item retains body amount and raw hue"):return {}
		var presenter:=preload("res://Presentation/WorldItems.gd").new();presenter.session=sessions[client];root.add_child(presenter)
		var holder:=Node3D.new();root.add_child(holder)
		if not check(presenter._equine_corpse(holder,item,corpse),"Actual native item builds the accepted rider's static human cadaver"):return {}
		var frozen: Node3D=holder.get_node("CorpseVisual")
		check(frozen.get_meta("static_cadaver",false) and int(frozen.get_meta("corpse_body"))==body and int(frozen.get_meta("native_hue"))==hue and frozen.find_children("*","AnimationPlayer",true,false).is_empty(),"Rider corpse remains a frozen body with exact native identity")
		check(is_equal_approx(frozen.rotation.y,PI-float(direction&7)*PI/4.),"Actual Rider corpse preserves native facing")
		witnesses.append(event.duplicate(true));death_presenters[client].finish(serial);death_events[client].erase(serial)
		holder.free();presenter.hint.free();presenter.free()
	return {"body":body,"corpse":corpse,"hue":hue,"mount_serial":mount_serial,"mount_deleted":true,"witnesses":witnesses}
func run() -> void:
	Profiles.load_index()
	var pins: Dictionary={}
	var paths: Array[String]=["Viewer/Network/SavageRiderLive.gd","Viewer/Network/SavageLive.gd","Viewer/Network/GameSession.gd","Server/HorseIntegrationFixtures/SavageRiderFixtures.cs","Server/HorseIntegrationFixtures/FixtureAIControls.cs","scripts/test-horses.ps1","Viewer/local-art/human-npcs/accepted-index.json"]
	for name in ["HumanAvatar.gd","HumanVisual.gd","HumanNPCProfiles.gd","HumanActions.gd","HumanNPCDeathVisual.gd","CreatureDeaths.gd","CorpseModels.gd","WorldItems.gd","MountVisual.gd","SourceRidgebackVisual.gd","HorseRider.gd"]:paths.append("Viewer/Presentation/"+name)
	for path in ["Mobiles/Monsters/Humanoid/Melee/SavageRider.cs","Mobiles/Animals/Mounts/SavageRidgeback.cs","Mobiles/Animals/Mounts/BaseMount.cs"]:paths.append("Server/ModernUO/Projects/UOContent/"+path)
	for path in paths:pins[path]=FileAccess.get_sha256("res://../"+path)
	var accounts: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"))
	for client in 2:
		var session:=Game.new();root.add_child(session);sessions.append(session);session.failed.connect(func(reason: String):errors.append(reason))
		session.message_received.connect(func(text: String):
			if text.begins_with("UCRIDER|"):replies[client].append(text))
		session.appearance_changed.connect(func(serial: int):
			appearance_events[client].append({"serial":serial,"mounted":not mount_item(client,serial).is_empty()});refresh(client,serial))
		var arena:=DeathArena.new();root.add_child(arena);death_arenas.append(arena)
		var items:=DeathItems.new();arena.add_child(items);death_items.append(items)
		var deaths:=preload("res://Presentation/CreatureDeaths.gd").new();arena.add_child(deaths);deaths.configure(arena,session,items);death_presenters.append(deaths)
		deaths.transition_started.connect(func(killed: int,corpse: int,visual: Node3D):death_events[client][killed]={"corpse":corpse,"body":visual.native_body,"hue":visual.native_hue,"equipment":visual.server_equipment.duplicate(true),"clip":visual.current_clip,"grounded":visual.has_meta("grounded_death_signature")})
		session.connect_account(accounts[client].username,accounts[client].password,2594)
		if not check(await until(func():return session.phase=="characters"),"Disposable native Rider account login"):return
		var slot:=-1;var city:=-1
		for character: Dictionary in session.characters:
			if str(character.name).is_empty():slot=int(character.slot);break
		for place: Dictionary in session.cities:
			if place.name=="Britain":city=int(place.index);break
		if not check(slot>=0 and city>=0,"Fresh native Rider character slot and start"):return
		session.create_character("Rider Woman" if client else "Rider Man",slot,city,client==1)
		if not check(await until(func():return session.phase=="world"),"Actual native Rider observer world entry"):return
	for owner in 2:
		for body in [185,186]:
			var response: PackedStringArray=(await reply(owner,"prepare "+str(body))).split("|")
			if not check(response.size()==14 and int(response[3])==body and int(response[4])==int(body==186) and int(response[7])==188 and int(response[8])==0x3eb8 and response[13]=="1","Unmodified native Rider constructor supplies its real gender, original Savage Ridgeback and mount item with stopped AI"):return
			if not check(int(response[10]) in range(151,171) and int(response[11]) in range(92,131) and int(response[12]) in range(51,66),"Real native Rider stats remain inside original constructor ranges"):return
			var serial:=int(response[2]);var mount_serial:=int(response[6]);var pair: Array=[]
			if not check(await until(func():return sessions[0].entities.has(serial) and sessions[1].entities.has(serial) and not mount_item(0,serial).is_empty() and not mount_item(1,serial).is_empty()),"Both clients receive native mounted Rider equipment"):return
			for client in 2:
				var actor:=Avatar.new();actor.initial_body=body;root.add_child(actor);actor.set_process(false);actor.set_physics_process(false);actor.apply_server_appearance(sessions[client].entities[serial],worn(client,serial));actor.human_visual.set_process(false)
				if not check(actor.human_visual.female==(body==186) and actor.human_visual.mounted_live_enabled and actor.horse_visual.native_body==188 and actor.horse_visual.get_script().resource_path=="res://Presentation/SourceRidgebackVisual.gd","Actual native packets select accepted gender and original Ridgeback renderer"):return
				if not check(actor.human_visual.skin_hue==int(response[5]) and actor.horse_visual.native_hue==int(response[9]),"Original constructor hues arrive before any dye operation"):return
				pair.append(actor);death_arenas[client].avatars[serial]=actor
			actors[serial]=pair
			var native_items:=worn(owner,serial).duplicate(true)
			for required: Array in [[0xf62,2],[0x144e,19],[0x1452,4]]:
				check(native_items.any(func(item: Dictionary):return int(item.id)==required[0] and int(item.layer)==required[1]),"Original constructor supplies the exact native spear/bone-armour identity and layer")
			for hues: Array in [[53,0x8035],[0x8035,53]]:
				await reply(owner,"colour %d %d"%[hues[0],hues[1]])
				if not check(await until(func():return int(sessions[0].entities[serial].hue)==hues[0] and int(sessions[1].entities[serial].hue)==hues[0] and int(mount_item(0,serial).get("hue",-1))==hues[1] and int(mount_item(1,serial).get("hue",-1))==hues[1]),"Rider and native mount propagate independent full/partial hues to both clients"):return
				for client in 2:
					refresh(client,serial);check(actors[serial][client].human_visual.skin_hue==hues[0] and actors[serial][client].horse_visual.native_hue==hues[1],"Actual skin and original mount retain independent raw hue bits")
			var actions: Array=[]
			for group in range(23,30):
				for session: Node in sessions:session.last_mobile_actions.erase(serial)
				await reply(owner,"action "+str(group))
				if not check(await until(func():return sessions[0].last_mobile_actions.has(serial) and sessions[1].last_mobile_actions.has(serial)),"Native mounted packet reaches both clients"):return
				for client in 2:
					var request: Dictionary=sessions[client].last_mobile_actions[serial];var actor: Node3D=actors[serial][client]
					if not check(int(request.body)==body and int(request.action)==group and actor.receive_native_action(request) and actor.human_visual.action_clip==Actions.CLASSIC[group],"Both actual avatars consume the original mounted group and select its rider replacement"):return
				actions.append(sessions[owner].last_mobile_actions[serial].duplicate(true))
			for moving in ["walk","run"]:
				await create_timer(.8).timeout
				var movement: PackedStringArray=(await reply(owner,moving)).split("|")
				if not check(movement.size()==8 and movement[2]=="1" and movement[7]=="1","Real native mounted Move succeeds with rider/mount AI still stopped"):return
				var target:=Vector2i(int(movement[3]),int(movement[4]))
				if not check(await until(func():return Vector2i(sessions[0].entities[serial].x,sessions[0].entities[serial].y)==target and Vector2i(sessions[1].entities[serial].x,sessions[1].entities[serial].y)==target),"Native mounted coordinates replicate to both observers"):return
				for client in 2:
					var actor: Node3D=actors[serial][client];actor.human_visual.cancel_action();actor.animate(true,0.,.1,6.8 if moving=="run" else 1.4)
					check(bool(sessions[client].entities[serial].running)==(moving=="run") and actor.horse_visual.current_clip==("Run" if moving=="run" else "Walk"),"Native mounted gait flags select the corresponding original Ridgeback gait")
			await reply(owner,"dismount")
			if not check(await until(func():return mount_item(0,serial).is_empty() and mount_item(1,serial).is_empty() and sessions[0].entities.has(mount_serial) and sessions[1].entities.has(mount_serial)),"Actual native dismount removes layer25 and exposes its same loose Ridgeback on both clients"):return
			for client in 2:check(not actors[serial][client].human_visual.mounted_live_enabled,"Normal appearance handling receives native dismount")
			await reply(owner,"mount")
			if not check(await until(func():return not mount_item(0,serial).is_empty() and not mount_item(1,serial).is_empty() and not sessions[0].entities.has(mount_serial) and not sessions[1].entities.has(mount_serial)),"Actual native remount restores layer25 and internalizes the same Ridgeback on both clients"):return
			var death:=await rider_death(owner,serial,body,mount_serial)
			if not check(not death.is_empty(),"Native Rider mounted-death witnesses complete"):return
			records.append({"owner":owner,"body":body,"native_class":"SavageRider","native_stats":{"str":int(response[10]),"dex":int(response[11]),"int":int(response[12])},"constructor_hue":int(response[5]),"constructor_mount_hue":int(response[9]),"native_items":native_items,"unresolved_item_art":actors[serial][owner].human_visual.unsupported_items.duplicate(),"actions":actions,"native_mount_body":188,"native_mount_item":0x3eb8,"walk_run":true,"independent_full_partial_hues":true,"dismount_remount":true,"death":death})
			await reply(owner,"cleanup");clear_actors()
	for session: Node in sessions:session.close()
	for path in pins:check(pins[path]==FileAccess.get_sha256("res://../"+path),"Rider native trial leaves its exact input unchanged: "+path)
	var folder:="res://../work/creatures/savage-riders";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	FileAccess.open(folder+"/native-tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":0,"records":records,"inputs_sha256":pins,"scope":"Two disposable actual native clients/owners, original random gender185/186 SavageRider constructors/native gear/Ridgeback188, independent raw hues,7mounted groups, native Move flags/coords, native dismount/remount and OnBeforeDeath mount deletion/0xAF/static corpses. AI timers stopped; native stats/skills/death logic unchanged. Headless; no GPU, autonomous combat/loot/ownership or full-family completion claim."},"\t"))
	print("SAVAGE RIDER NATIVE: ",checks," checks /0 failures");quit()
