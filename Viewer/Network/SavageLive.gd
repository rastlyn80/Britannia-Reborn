extends "res://Network/FluidElementalBehaviourLive.gd"
## Real isolated two-client constructors/packets and native Shaman timers, no GPU claim.
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Profiles=preload("res://Presentation/HumanNPCProfiles.gd")
const Actions=preload("res://Presentation/HumanActions.gd")
var actors: Dictionary={}
var records: Array=[]
var death_arenas: Array=[]
var death_items: Array=[]
var death_presenters: Array=[]
var death_events: Array=[{},{}]
class DeathArena extends Node3D:
	var avatars: Dictionary={}
class DeathItems extends Node:
	var nodes: Dictionary={}
func _initialize() -> void:
	create_timer(360.).timeout.connect(func():push_error("Native Savage integration deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> bool:
	checks+=1;print("SAVAGE NATIVE ","PASS: " if ok else "FAIL: ",label)
	if not ok:push_error(label+str(errors));quit(1)
	return ok
func reply(client: int,command: String) -> String:
	replies[client].clear();sessions[client].send_command("[SavageBehaviourFixture "+command)
	if not check(await until(func():return not replies[client].is_empty()),"Native Savage fixture reply: "+command):return ""
	return str(replies[client][-1])
func clear_actors() -> void:
	for arena: Node3D in death_arenas:arena.avatars.clear()
	for pair: Array in actors.values():
		for actor: Node3D in pair:actor.free()
	actors.clear()
func equipment_identity(items: Array) -> Array:
	var result: Array=items.map(func(item: Dictionary):return {"serial":item.serial,"id":item.id,"layer":item.layer,"hue":item.hue})
	result.sort_custom(func(a: Dictionary,b: Dictionary):return int(a.serial)<int(b.serial))
	return result
func attach(serial: int) -> bool:
	if actors.has(serial):return true
	if not check(await until(func():return sessions[0].entities.has(serial) and sessions[1].entities.has(serial)),"Both clients receive the actual native participant"):return false
	var pair: Array=[]
	for client: int in 2:
		var session: Node=sessions[client];var body:=int(session.entities[serial].body)
		if not check(body in [183,184],"Native human-type body preserves its actual gender identity"):return false
		if not check(await until(func():return session.mobile_equipment.get(serial,{}).size()>=3),"Native equipment reaches each observer"):return false
		var actor:=Avatar.new();actor.initial_body=body;root.add_child(actor);actor.set_process(false);actor.set_physics_process(false)
		actor.apply_server_appearance(session.entities[serial],session.mobile_equipment[serial].values());actor.human_visual.set_process(false)
		check(actor.human_visual!=null and actor.horse_visual==null and actor.human_visual.female==(body==184),"Actual avatar uses the modern human of the native body's gender")
		check(actor.server_appearance.equipment==session.mobile_equipment[serial].values(),"All original native item identities/hues survive appearance handling")
		pair.append(actor)
		death_arenas[client].avatars[serial]=actor
	actors[serial]=pair;return true
func native_death(owner: int,serial: int,body: int) -> Dictionary:
	var worn: Array=sessions[owner].mobile_equipment[serial].values().duplicate(true)
	var hue:=int(sessions[owner].entities[serial].hue);var direction:=int(sessions[owner].entities[serial].direction)
	var response: PackedStringArray=(await reply(owner,"kill")).split("|")
	if not check(response.size()==4 and response[1]=="corpse" and int(response[3])==body,"Native Kill creates an actual corpse without forcing death state"):return {}
	var corpse:=int(response[2])
	if not check(await until(func():return death_events[0].has(serial) and death_events[1].has(serial)),"Actual native0xAF starts human death snapshots on both clients"):return {}
	var witnesses: Array=[]
	for client: int in 2:
		var event: Dictionary=death_events[client][serial]
		if not check(int(event.corpse)==corpse and int(event.body)==body and int(event.hue)==hue and equipment_identity(event.equipment)==equipment_identity(worn) and event.clip=="Death" and event.grounded,"Each native death snapshot retains body/hue/equipment identities and the measured death motion across the native corpse transfer"):return {}
		if not check(await until(func():return sessions[client].world_items.has(corpse) and not sessions[client].entities.has(serial)),"Actual native corpse creation and mobile removal replicate to both observers"):return {}
		var item: Dictionary=sessions[client].world_items[corpse]
		if not check(int(item.id)==0x2006 and int(item.amount)==body and int(item.hue)==hue,"Native corpse retains graphic0x2006/body-amount/raw hue"):return {}
		var presenter:=preload("res://Presentation/WorldItems.gd").new();presenter.session=sessions[client];root.add_child(presenter)
		var holder:=Node3D.new();root.add_child(holder)
		if not check(presenter._equine_corpse(holder,item,corpse),"Real world-item corpse routing builds the native human cadaver"):return {}
		var frozen: Node3D=holder.get_node("CorpseVisual")
		check(frozen.get_meta("static_cadaver",false) and int(frozen.get_meta("corpse_body"))==body and int(frozen.get_meta("native_hue"))==hue and frozen.find_children("*","AnimationPlayer",true,false).is_empty(),"Actual native human corpse is frozen with exact body/hue identity")
		check(is_equal_approx(frozen.rotation.y,PI-float(direction&7)*PI/4.),"Native corpse facing follows the actual death packet")
		witnesses.append(event.duplicate(true));death_presenters[client].finish(serial);death_events[client].erase(serial)
		holder.free();presenter.hint.free();presenter.free()
	return {"corpse":corpse,"body":body,"hue":hue,"direction":direction,"witnesses":witnesses}
func consume(serial: int,group: int) -> bool:
	if not check(await until(func():return sessions[0].last_mobile_actions.has(serial) and sessions[1].last_mobile_actions.has(serial)),"Native action packet reaches both observers"):return false
	for client: int in 2:
		var request: Dictionary=sessions[client].last_mobile_actions[serial];var actor: Node3D=actors[serial][client]
		if not check(request.protocol=="classic" and int(request.action)==group and int(request.body)==int(actor.native_body),"Actual packet preserves protocol/group/native body"):return false
		if not check(actor.receive_native_action(request) and actor.human_visual.action_clip==Actions.resolve(request),"Actual modern avatar selects the expected native human action"):return false
		if group==111:
			check(int(request.frames)==5 and int(request.delay)==0 and not request.reverse and not request.repeat,"Native Shaman sends its real five-frame forward one-shot")
			check(is_equal_approx(actor.human_visual.action_duration,.8) and not bool(actor.foot_contact.call("leg_ik_enabled")),"Native111 drives800ms dance with standing leg IK suspended")
	return true
func run() -> void:
	Profiles.load_index();var old_profiles:=Profiles.entries.duplicate(true)
	var accepted_path:="res://local-art/human-npcs/accepted-index.json";var accepted_sha:=FileAccess.get_sha256(accepted_path) if FileAccess.file_exists(accepted_path) else "absent"
	var prep_path:="res://local-art/human-npcs/savages/dance/preparation.json";var prep_sha:=FileAccess.get_sha256(prep_path)
	var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prep_path))
	for row: Dictionary in prep.models:
		var body:=184 if row.gender=="female" else 183
		Profiles.entries[body]={"body":body,"female":body==184,"skin":"savage","status":"prepared","tribal_dance":{"asset":row.asset,"sha256":row.asset_sha256}}
	var input_paths: Array[String]=["Viewer/Network/SavageLive.gd","Viewer/Network/GameSession.gd","Server/HorseIntegrationFixtures/SavageBehaviourFixtures.cs","Server/HorseIntegrationFixtures/FixtureAIControls.cs","scripts/test-horses.ps1"]
	for name: String in ["HumanAvatar.gd","HumanVisual.gd","HumanActions.gd","HumanNPCMotion.gd","HumanNPCFootContact.gd","HumanNPCProfiles.gd","HumanDeathFloor.gd","HumanNPCDeathVisual.gd","CreatureDeaths.gd","CorpseModels.gd","WorldItems.gd"]:input_paths.append("Viewer/Presentation/"+name)
	for path: String in ["Mobiles/Monsters/Humanoid/Melee/Savage.cs","Mobiles/Monsters/Humanoid/Magic/SavageShaman.cs","Items/Clothing/Hats.cs","Mobiles/BaseCreature.cs"]:input_paths.append("Server/ModernUO/Projects/UOContent/"+path)
	input_paths.append("Server/ModernUO/Projects/Server/Mobiles/Mobile.cs")
	var pins: Dictionary={}
	for path: String in input_paths:pins[path]=FileAccess.get_sha256("res://../"+path)
	var accounts: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"))
	for client: int in 2:
		var session:=Game.new();root.add_child(session);sessions.append(session);session.failed.connect(func(reason: String):errors.append(reason));session.message_received.connect(func(text: String):
			if text.begins_with("UCSAVAGE|"):replies[client].append(text))
		var arena:=DeathArena.new();root.add_child(arena);death_arenas.append(arena)
		var items:=DeathItems.new();arena.add_child(items);death_items.append(items)
		var deaths:=preload("res://Presentation/CreatureDeaths.gd").new();arena.add_child(deaths);deaths.configure(arena,session,items);death_presenters.append(deaths)
		deaths.transition_started.connect(func(killed: int,corpse: int,visual: Node3D):death_events[client][killed]={"corpse":corpse,"body":visual.native_body,"hue":visual.native_hue,"equipment":visual.server_equipment.duplicate(true),"clip":visual.current_clip,"grounded":visual.has_meta("grounded_death_signature")})
		session.connect_account(accounts[client].username,accounts[client].password,2594)
		if not check(await until(func():return session.phase=="characters"),"Disposable native login"):return
		var slot:=-1;var city:=-1
		for character: Dictionary in session.characters:
			if str(character.name).is_empty():slot=int(character.slot);break
		for place: Dictionary in session.cities:
			if place.name=="Britain":city=int(place.index);break
		if not check(slot>=0 and city>=0,"Fresh disposable native character slot/start"):return
		session.create_character("Savage Woman" if client else "Savage Man",slot,city,client==1)
		if not check(await until(func():return session.phase=="world"),"Actual ModernUO world entry"):return
	for client: int in 2:
		for kind: String in ["savage","shaman"]:
			for body: int in [183,184]:
				var prepared: PackedStringArray=(await reply(client,"prepare "+kind+" "+str(body)+" 1")).split("|")
				if not check(prepared.size()==13 and prepared[1]=="prepared" and int(prepared[3])==body and prepared[4]==("Savage" if kind=="savage" else "SavageShaman") and prepared[11]=="1" and prepared[12]=="0","Unmodified native constructor produces the requested body with stopped AI outside guarded towns"):return
				var serial:=int(prepared[2]);if not await attach(serial):return
				var packet_actions: Array=[]
				for group: int in Actions.CLASSIC:
					if group in [23,24,25,26,27,28,29]:continue
					for session: Node in sessions:session.last_mobile_actions.erase(serial)
					await reply(client,"action "+str(group));if not await consume(serial,group):return
					packet_actions.append(sessions[client].last_mobile_actions[serial].duplicate(true))
				for hue: int in [53,0x8035]:
					await reply(client,"hue "+str(hue))
					if not check(await until(func():return int(sessions[0].entities[serial].hue)==hue and int(sessions[1].entities[serial].hue)==hue),"Native full/partial hue changes reach both observers"):return
					for index: int in 2:
						var actor: Node3D=actors[serial][index];actor.apply_server_appearance(sessions[index].entities[serial],sessions[index].mobile_equipment[serial].values())
						check(actor.human_visual.skin_hue==hue and actor.native_body==body,"Actual avatar retains raw native body/hue flags")
				for moving: String in ["walk","run"]:
					var movement: PackedStringArray=(await reply(client,moving)).split("|")
					if not check(movement.size()==8 and movement[2]=="1" and movement[7]=="1","Actual native Move succeeds with all AI still stopped"):return
					var target:=Vector2i(int(movement[3]),int(movement[4]))
					if not check(await until(func():return Vector2i(sessions[0].entities[serial].x,sessions[0].entities[serial].y)==target and Vector2i(sessions[1].entities[serial].x,sessions[1].entities[serial].y)==target),"Native moved coordinates replicate to both observers"):return
					for index: int in 2:
						var actor: Node3D=actors[serial][index];actor.human_visual.cancel_action();actor.animate(true,0.,.1,6.8 if moving=="run" else 1.4)
						check(bool(sessions[index].entities[serial].running)==(moving=="run") and Actions.locomotion(actor.human_visual.current_clip),"Actual native gait flags drive a human locomotion clip")
				var native_items: Array=sessions[client].mobile_equipment[serial].values().duplicate(true)
				var unresolved: Array=actors[serial][client].human_visual.unsupported_items.duplicate()
				var death:=await native_death(client,serial,body)
				if not check(not death.is_empty(),"Native human death/corpse witnesses are complete"):return
				records.append({"owner":client,"kind":kind,"body":body,"native_class":prepared[4],"native_female_flag":prepared[9],"actions":packet_actions,"native_items":native_items,"unresolved_item_art":unresolved,"death":death})
				await reply(client,"cleanup");clear_actors()
		for body: int in [183,184]:
			for quorum: int in [1,4]:
				var prepared: PackedStringArray=(await reply(client,"prepare shaman "+str(body)+" "+str(quorum))).split("|")
				if not check(prepared.size()==13 and int(prepared[8])==quorum and prepared[12]=="0","Native Shaman group count is explicit and its arena is unguarded"):return
				var lead:=int(prepared[2]);var dancers: Array[int]=[]
				for value: String in prepared[5].split(","):dancers.append(int(value))
				for serial: int in dancers:
					if not await attach(serial):return
				var observed: Dictionary={};var attempts: Array=[]
				for attempt in (24 if quorum==4 else 1):
					for session: Node in sessions:
						for serial: int in dancers:session.last_mobile_actions.erase(serial)
					var start: PackedStringArray=(await reply(client,"dance")).split("|")
					if not check(start.size()==6 and int(start[3])>=900 and start[5]=="1","Native BeginSavageDance sets its own1s movement deadline without restarting AI"):return
					for serial: int in dancers:
						if not await consume(serial,111):return
					await create_timer(.2).timeout
					var early: PackedStringArray=(await reply(client,"status")).split("|")
					if not check(early.size()==9 and early[1]=="status","Native early status is complete: "+str(early)):return
					if not check(int(early[2])<1000 and int(early[4])-int(early[3])<25 and early[5]==early[6] and int(early[7])<0,"Before the native deadline no group-strength heal, harm or poison occurs; ordinary regeneration is allowed"):return
					await create_timer(1.1).timeout
					var late: PackedStringArray=(await reply(client,"status")).split("|")
					if not check(late.size()==9 and late[1]=="status","Native late status is complete: "+str(late)):return
					if not check(late.size()==9 and int(late[2])>=1000 and late[8]=="1","Natural callback deadline elapses with actual AI timers still stopped"):return
					# Native Lightning schedules damage250ms after the group callback.
					# Observe that outcome before resetting the next trial's baselines.
					var outcome_deadline:=Time.get_ticks_msec()+5000
					while quorum==4 and int(late[4])-int(late[3])<25 and int(late[6])>=int(late[5]) and int(late[7])<0 and Time.get_ticks_msec()<outcome_deadline:
						await create_timer(.05).timeout
						late=(await reply(client,"status")).split("|")
						if not check(late.size()==9 and late[1]=="status" and late[8]=="1","Delayed native outcome is sampled with AI still stopped"):return
					var healed:=int(late[4])-int(late[3])>=25;var damaged:=int(late[6])<int(late[5]);var poisoned:=int(late[7])>=0
					if quorum==4 and not check(healed or damaged or poisoned,"Each natural group callback finishes before the next trial"):return
					if quorum==1:
						check(not healed and not damaged and not poisoned,"A single Shaman animates but does not schedule the group effect")
					else:
						if healed:observed.heal=true
						if damaged:observed.lightning=true
						if poisoned:observed.poison=true
					attempts.append({"attempt":attempt,"early":Array(early),"late":Array(late),"healed":healed,"damaged":damaged,"poisoned":poisoned})
					if observed.size()==3:break
				if quorum==4 and not check(observed.size()==3,"Natural random group callbacks demonstrate heal, Lightning damage and poison without forced outcomes"):return
				records.append({"owner":client,"body":body,"quorum":quorum,"lead":lead,"dancers":dancers,"native_group_effects":observed,"attempts":attempts})
				await reply(client,"cleanup");clear_actors()
	for session: Node in sessions:session.close()
	Profiles.entries=old_profiles
	check((FileAccess.get_sha256(accepted_path) if FileAccess.file_exists(accepted_path) else "absent")==accepted_sha,"Native trial leaves accepted profiles unchanged")
	check(FileAccess.get_sha256(prep_path)==prep_sha,"Native trial retains exact prepared dance")
	for path: String in pins:check(pins[path]==FileAccess.get_sha256("res://../"+path),"Native trial input remains unchanged: "+path)
	var report:={"checks":checks,"failures":0,"records":records,"inputs_sha256":pins,"preparation_sha256":prep_sha,"death_preparation_sha256":FileAccess.get_sha256("res://local-art/human-npcs/shared/death-preparation.json"),"scope":"Two actual disposable native owners, original Savage/Shaman constructors,28foot packets to both actual avatars, native Move/hues, Kill/0xAF/removal/static0x2006corpse identity/facing on both clients and native BeginSavageDance111/group threshold/natural1s random heal/Lightning/poison callbacks. AI timers stopped; arena placement, player protection, current-health injury/recovery/cure are explicit fixture setup. Native maxima/skills/deadlines/random choices unchanged. Headless, no GPU/material/equipment-fit/loot/rider/autonomous-play or family acceptance."}
	var f:=FileAccess.open("res://../work/creatures/savages/native-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print("SAVAGE NATIVE: ",checks," checks /0 failures");quit()
