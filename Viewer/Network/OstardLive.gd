extends SceneTree
## Only scripts/test-horses.ps1 -Live -Ostards supplies this disposable server.
const Game=preload("res://Network/GameSession.gd")
const Horse=preload("res://Presentation/MountVisual.gd")
const HorseRig=preload("res://Presentation/HorseVisual.gd")
const BovineActions := preload("res://Presentation/BovineActionsVisual.gd")
const BovineTransition := preload("res://Network/BovineLiveTransition.gd")
var sessions: Array=[]
var avatars: Array=[]
var errors: Array=[]
var replies: Array=[]
var checks:=0
var records: Array=[]
var equine_completion:=false
var llama_completion:=false
var ethics_status: Array=[]
var ethics_only:=false
var ethics_resume:=false
var bovines:=false
var bovine_actions: Array[Dictionary] = []
var sea_horse:=false
var giant_beetle:=false
var fire_beetle:=false
var hiryu:=false
var cu_sidhe:=false
var source_mounts := false
var cu_active:=false
const CU_PACKAGE := "res://local-art/creatures/cu_sidhe_mount/preparation.json"
var cu_pin := ""
var hiryu_active:=false
const HIRYU_PACKAGE := "res://local-art/creatures/hiryu_mount/preparation.json"
var hiryu_pin := ""
var ethereal_beetle:=false
func fixture_reply(session: Node,sex: int,command: String,prefix: String) -> String:
	replies[sex].clear();session.send_command("[EquineFixture "+command)
	if not check(await until(func():return replies[sex].any(func(t: String):return t.begins_with(prefix))),"native ethics reply: "+command):return ""
	return replies[sex].filter(func(t: String):return t.begins_with(prefix))[-1]
func join_ethics(session: Node,sex: int,variant: int) -> bool:
	var hero:=variant in [38,41]
	session.send(Game.speech_packet("I will defend the virtues" if hero else "I am evil incarnate"))
	var response:=await fixture_reply(session,sex,"ethics-owner","UCEQUINE|owner|")
	if response.is_empty():return false
	return check(response.split("|")[2]==("HeroEthic" if hero else "EvilEthic"),"native spoken oath near an ankh joins the eligible ethic")
func _initialize() -> void:call_deferred("run")
func until(condition: Callable,seconds: float=15.) -> bool:
	var start:=Time.get_ticks_msec()
	while not condition.call():
		if not errors.is_empty() or Time.get_ticks_msec()-start>seconds*1000.:return false
		await process_frame
	return true
func check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:
		push_error(label+" "+str(errors))
		for session in sessions:session.close()
		quit(1);return false
	print("EQUINE LIVE PASS: ",label);return true
func object_ready(session: Node) -> bool:
	return await until(func():return Time.get_ticks_msec()>=session.next_item_action)
func native_step(session: Node,running: bool,desired: int=-1) -> int:
	var origin:=Vector2i(session.player.x,session.player.y)
	for direction in ([desired] if desired>=0 else range(8)):
		# A native facing change is acknowledged without changing position.
		for attempt in 2:
			if not await until(func():return session.outstanding==-1 and not session.awaiting_position and Time.get_ticks_msec()>=session.next_walk):return -1
			if not session.walk(direction,running):continue
			if not await until(func():return session.outstanding==-1 and not session.awaiting_position):return -1
			if Vector2i(session.player.x,session.player.y)!=origin:return direction
	return -1
func run() -> void:
	equine_completion="--equine-completion" in OS.get_cmdline_user_args()
	llama_completion="--llama-completion" in OS.get_cmdline_user_args()
	ethics_only="--ethics-only" in OS.get_cmdline_user_args()
	ethics_resume="--ethics-resume" in OS.get_cmdline_user_args()
	bovines="--bovines" in OS.get_cmdline_user_args()
	BovineActions.trial_enabled = "--bovine-actions" in OS.get_cmdline_user_args()
	sea_horse="--sea-horse" in OS.get_cmdline_user_args()
	giant_beetle="--giant-beetle" in OS.get_cmdline_user_args()
	fire_beetle="--fire-beetle" in OS.get_cmdline_user_args()
	ethereal_beetle="--ethereal-beetle" in OS.get_cmdline_user_args()
	hiryu="--hiryu" in OS.get_cmdline_user_args()
	hiryu_active="--hiryu-active" in OS.get_cmdline_user_args()
	source_mounts = "--source-mounts" in OS.get_cmdline_user_args()
	cu_sidhe="--cu-sidhe" in OS.get_cmdline_user_args()
	cu_active="--cu-sidhe-active" in OS.get_cmdline_user_args()
	if cu_sidhe:
		var registry = preload("res://Presentation/CreatureRegistry.gd")
		cu_pin = FileAccess.get_sha256(CU_PACKAGE)
		var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CU_PACKAGE))
		var entry: Dictionary = package.models[0]
		if not check(entry.kind == "cushidhe" and int(entry.mount_item) == 0x3e91,"Exact original Cu Sidhe mount package"):return
		registry.load_index()
		if cu_active:
			var active := registry.entry(277).duplicate(true)
			active.status = "prepared"
			if not check(active == entry,"Normal registry loads the exact prepared Cu Sidhe mount"):return
		else:
			registry.entries[277] = entry
	if hiryu:
		hiryu_pin = FileAccess.get_sha256(HIRYU_PACKAGE)
		var registry = preload("res://Presentation/CreatureRegistry.gd")
		var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HIRYU_PACKAGE))
		var entry: Dictionary = package.models[0]
		if not check(entry.kind == "hai_riyo" and int(entry.mount_item) == 0x3e94,"Exact original Hiryu mount package"):return
		if hiryu_active:
			var active := registry.entry(243).duplicate(true)
			active.status = "prepared"
			if not check(active == entry,"Normal registry loads the exact prepared Hiryu mount"):return
		else:
			registry.load_index()
			registry.entries[243] = entry
	var accounts: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"))
	for sex in 2:
		var session:=Game.new();root.add_child(session);sessions.append(session);replies.append([])
		session.failed.connect(func(reason: String):errors.append(reason))
		session.message_received.connect(func(text: String):
			if text.begins_with("UCEQUINE|"):replies[sex].append(text))
		session.connect_account(accounts[sex].username,accounts[sex].password,2594)
		if not check(await until(func():return session.phase=="characters"),"native isolated account login"):return
		var slot:=-1;var city:=-1
		for character in session.characters:
			if character.name.is_empty():slot=int(character.slot);break
		for place in session.cities:
			if place.name=="Britain":city=int(place.index);break
		if not check(slot>=0 and city>=0,"native empty slot and Britain start"):return
		if ethics_resume:
			var character: Dictionary=session.characters.filter(func(c: Dictionary):return c.name==("Equine Woman" if sex else "Equine Man"))[0]
			session.select_character(int(character.slot),character.name)
		else:session.create_character("Equine Woman" if sex else "Equine Man",slot,city,sex==1)
		if not check(await until(func():return session.phase=="world"),"actual isolated ModernUO world entry"):return
		var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if sex else 400;root.add_child(actor);actor.set_physics_process(false);avatars.append(actor)
	if ethics_resume:
		await resume_ethics();return
	for sex in 2:
		var session: Node=sessions[sex];var observer: Node=sessions[1-sex];var actor: Node3D=avatars[sex];var me:=int(session.player.serial)
		for variant in ([55,56,57,58,59] if source_mounts else [52,53,54] if cu_sidhe else [50,51] if hiryu else [49] if ethereal_beetle else [48] if fire_beetle else [47] if giant_beetle else [46] if sea_horse else range(42,46) if bovines else [23,24,38,39,40,41] if ethics_only else range(22,33)+range(34,42) if equine_completion else [19,20,21,33] if llama_completion else [13,14,15,16,17,18,19,20,21]):
			replies[sex].clear();session.send_command("[EquineFixture prepare "+str(variant))
			if not check(await until(func():return not replies[sex].is_empty()),"real upstream equine fixture prepared"):return
			var fields: PackedStringArray=replies[sex][-1].split("|")
			if not check(fields.size()==6 and fields[1]=="prepared","fixture identifies actual native class/body/mount"):return
			var serial:=int(fields[2]);var body:=int(fields[3]);var item:=int(fields[4]);var ethereal: bool=variant in [16,21,22,49]
			var constructor_hue := -1
			if cu_sidhe:
				if not check(body == 277 and item == 0x3e91 and fields[5] == "CuSidhe","Original native Cu Sidhe body and mount item"):return
				var state := await fixture_reply(session,sex,"cu-state","UCEQUINE|cu-state|")
				if not check(state == "UCEQUINE|cu-state|%d|%d" % [int(variant == 54), int(variant == 53)],"Native Cu Sidhe rider race and pads match the scenario"):return
				var rider_body := (605 + sex) if variant == 54 else (400 + sex)
				if not check(await until(func():return int(session.player.body) == rider_body),"Native Cu Sidhe rider body reaches the client"):return
			if hiryu and not check(body==243 and item==0x3e94 and fields[5]==("Hiryu" if variant==50 else "LesserHiryu"),"original native Hiryu identity"):return
			if hiryu:
				var flight := await fixture_reply(session,sex,"hiryu-flight","UCEQUINE|hiryu-flight|")
				if not check(flight == "UCEQUINE|hiryu-flight|0|0","Pinned native Hiryu reports grounded capability and state"):return
			if source_mounts:
				var identity: Array = [[794,0x3ebd,"SwampDragon"],[799,0x3ebe,"ScaledSwampDragon"],
					[187,0x3eba,"Ridgeback"],[188,0x3eb8,"SavageRidgeback"],
					[794,0x3ebd,"SwampDragon"]][variant - 55]
				if not check([body,item,fields[5]] == identity,"Pinned native mount constructor identity"):return
			if giant_beetle and not check(body==791 and item==0x3ebc and fields[5]=="Beetle","original native Giant Beetle identity"):return
			if fire_beetle and not check(body==169 and item==0x3e95 and fields[5]=="FireBeetle","original native Fire Beetle identity"):return
			if ethereal_beetle and not check(body==0 and item==0x3e97 and fields[5]=="EtherealBeetle","original native Ethereal Beetle item identity"):return
			if sea_horse:
				if not check(body==144 and item==0x3eb3 and fields[5]=="SeaHorse","real native SeaHorse identity is distinct from its horse-art fallback"):return
				var native_state:=await fixture_reply(session,sex,"sea-state","UCEQUINE|sea-state|")
				if not check(native_state=="UCEQUINE|sea-state|144|16051|0|0|0","native SeaHorse is walking, non-swimming and not tamable; fixture control is setup only"):return
			print("EQUINE LIVE VARIANT: ",fields[5]," body=",body," item=",item," female=",sex==1)
			if variant>=38 and variant<=41 and not await join_ethics(session,sex,variant):return
			if not ethereal:
				if not check(await until(func():return session.entities.has(serial) and observer.entities.has(serial)),"both clients receive the real loose animal"):return
				var loose:=preload("res://Presentation/HumanAvatar.gd").new();loose.initial_body=body;root.add_child(loose);loose.set_physics_process(false);loose.apply_server_appearance(session.entities[serial],[])
				if not check(loose.horse_visual!=null and loose.horse_visual.native_body==body,"received mobile selects the new equine art"):return
				if hiryu or cu_sidhe:
					constructor_hue = int(session.entities[serial].hue)
					var palettes: Dictionary = Horse.Animals.Creatures.entry(body).native_constructor_hue_ranges
					var allowed: Array = palettes[fields[5]]
					if not check(allowed.any(func(pair: Array):return constructor_hue == int(pair[0])) and int(observer.entities[serial].hue) == constructor_hue,"Both clients receive an original constructor hue"):return
				if sea_horse and not check(loose.horse_visual.native_hue==0 and loose.horse_visual.get_meta("equine_profile").get("default_hue")==1348,"fallback tint stays a presentation default; native zero hue is retained"):return
				if giant_beetle and not check(loose.horse_visual.native_hue==0,"native Giant Beetle has its original default hue"):return
				if fire_beetle and not check(loose.horse_visual.native_hue==0x489 and int(observer.entities[serial].hue)==0x489,"native Fire Beetle default hue on both clients"):return
				loose.free()
				if variant == 59:
					constructor_hue = await apply_swamp_barding(session, observer, sex, serial)
					if constructor_hue < 0:return
					body = 799
					item = 0x3ebe
			elif not session.known_items.has(serial):
				# A closed backpack does not expose newly added contents. Open it
				# normally and wait for the native container packet before using.
				if not check(await object_ready(session),"native backpack delay respected"):return
				session.open_backpack()
				if not check(await until(func():return session.known_items.has(serial)),"native backpack contents reveal the ethereal item"):return
			if ethereal_beetle and not check(int(session.known_items[serial].id)==0x260f and int(session.known_items[serial].hue)==0,"native unstained Ethereal Beetle statuette"):return
			if not check(await object_ready(session),"native item delay respected"):return
			if not check(session.use_mobile(serial) if not ethereal else session.use_item(serial),"normal double-click request sent"):return
			var denied: bool=bovines or variant in [20,23,24,25,26,27,28,29,33,40,41,52] or variant==17 and sex==1
			if denied:
				replies[sex].clear();session.send_command("[EquineFixture audit")
				if not check(await until(func():return not replies[sex].is_empty()),"server audits the restricted ride attempt"):return
				if not check(replies[sex][-1].begins_with("UCEQUINE|audit|0|") and not session.equipment.has(25),"native mount restriction preserved"):return
			else:
				if not check(await until(func():return int(session.equipment.get(25,{}).get("id",0))==item,20.),"server equips exact native mount item (including ethereal casting)"):return
				if not check(await until(func():return int(observer.mobile_equipment.get(me,{}).get(25,{}).get("id",0))==item),"observer receives the same mount item"):return
				actor.apply_server_appearance(session.player,session.equipment.values());actor.animate(true,0.,.1,1.8)
				if not check(actor.horse_visual!=null and actor.horse_visual.native_mount_item==item and actor.horse_visual.native_body==Horse.horse_body(item),"native packet selects exact equine profile"):return
				if cu_sidhe and not check(actor.human_visual!=null and actor.human_visual.female==(sex==1),"Cu Sidhe rider uses the correct male or female rig"):return
				if not check(await until(func():return actor.rider_contact.seated_weight>=1.),"rider completes animated seat transition"):return
				if not check(actor.rider_contact.seat_error<.002,"live equine rider stays on saddle"):return
				if variant == 59 and not check(actor.horse_visual.native_hue == constructor_hue
					and int(observer.mobile_equipment[me][25].hue) == constructor_hue,
					"Mounted barding keeps the deed hue on both clients"):return
				if source_mounts and not await source_rider_actions(session, observer, sex, me, actor):return
				if (hiryu or cu_sidhe) and not check(int(session.equipment[25].hue) == constructor_hue and int(observer.mobile_equipment[me][25].hue) == constructor_hue and actor.horse_visual.native_hue == constructor_hue,"Native constructor hue survives mounting"):return
				if fire_beetle and not check(actor.horse_visual.native_hue==0x489 and int(observer.mobile_equipment[me][25].hue)==0x489,"native mounted Fire Beetle keeps its constructor hue"):return
				if ethereal:
					if not check(int(session.equipment[25].hue)==0x4001 and bool(actor.horse_visual.get_meta("equine_profile").get("ethereal",false)),"real server spectral hue selects spectral rendering"):return
				for hue in [53,0x8000|53]:
					session.send_command("[EquineFixture colour "+str(hue))
					if not check(await until(func():return int(session.equipment.get(25,{}).get("hue",0))==hue and int(observer.mobile_equipment.get(me,{}).get(25,{}).get("hue",0))==hue),"native full/partial hue reaches both clients"):return
					actor.apply_server_appearance(session.player,session.equipment.values())
					if not check(actor.horse_visual.native_hue==hue,"new art retains raw hue flags"):return
				for running in [false,true]:
					var departure:=Vector2i(session.player.x,session.player.y)
					var travelled_direction:=await native_step(session,running)
					if not check(travelled_direction>=0,"real server confirms mounted walk/run movement"):return
					# Return by native movement so a long variant sweep does not
					# carry one rider outside the observer's replication range.
					await native_step(session,running,(travelled_direction+4)%8)
					if not check(Vector2i(session.player.x,session.player.y)==departure,"native return route keeps the observer in range"):return
				if not check(await object_ready(session) and session.use_mobile(me),"normal self double-click dismount request"):return
				if not check(await until(func():return not session.equipment.has(25) and not observer.mobile_equipment.get(me,{}).has(25)),"server and observer remove mounted equipment"):return
				if not ethereal:
					if not check(await until(func():return session.entities.has(serial) and observer.entities.has(serial)),"real animal returns to world on both clients"):return
				else:
					if not check(not session.entities.has(serial) and not observer.entities.has(serial),"ethereal item does not invent a loose animal"):return
				if ethereal_beetle:
					if not check(await object_ready(session),"native pack reopen delay respected"):return
					session.open_backpack()
					if not check(await until(func():return int(session.known_items.get(serial,{}).get("id",0))==0x260f and int(session.known_items[serial].hue)==(0x8000|53)),"same dyed statuette returns to backpack"):return
				actor.apply_server_appearance(session.player,session.equipment.values())
				if not check(await until(func():return actor.horse_visual==null),"visual rider returns to foot after authoritative dismount"):return
			if giant_beetle and not await beetle_pack(session,sex,serial):return
			if fire_beetle and not await fire_beetle_smelt(session,sex,serial):return
			if not ethereal:
				var loose:=preload("res://Presentation/HumanAvatar.gd").new();loose.initial_body=body;root.add_child(loose);loose.set_physics_process(false);loose.apply_server_appearance(session.entities[serial],[])
				if bovines and not await bovine_interactions(session,observer,sex,serial,body,loose):return
				if sea_horse and not await sea_horse_interactions(session,observer,sex,serial,loose):return
				var action_clips: Dictionary={5:"Attack",6:"Attack2",7:"Hit",9:"Fidget",10:"Fidget2"} if giant_beetle or fire_beetle or hiryu else {5:"Attack",4:"Hit",3:"Eat",11:"LieDown"}
				if source_mounts:action_clips.clear()
				for action_code in action_clips:
					session.last_mobile_actions.erase(serial);observer.last_mobile_actions.erase(serial)
					session.send_command("[EquineFixture action "+str(action_code))
					if not check(await until(func():return session.last_mobile_actions.has(serial) and observer.last_mobile_actions.has(serial)),"native attack/reaction packet arrives on both clients"):return
					if not check(loose.receive_native_action(session.last_mobile_actions[serial]),"actual creature consumes server attack/reaction"):return
					var expected: String={5:"rear",4:"hit",3:"eat",11:"lie_down"}[action_code] if loose.horse_visual is HorseRig else action_clips[action_code]
					if not check(loose.horse_visual.current_clip==expected,"native action selects the species clip"):return
				var bovine_probes: Array[Node3D] = []
				if bovines and BovineActions.trial_enabled and not check(loose.horse_visual is BovineActions,"Bovine trial uses the prepared renderer"):return
				if bovines and loose.horse_visual is BovineActions:
					bovine_probes = await begin_bovine_transition(session, observer, sex, serial, body, loose)
					if bovine_probes.is_empty():return
				replies[sex].clear();session.send_command("[EquineFixture kill")
				if not check(await until(func():return replies[sex].any(func(text: String):return text.begins_with("UCEQUINE|corpse|"))),"real upstream death creates a corpse"):return
				var response: String=replies[sex].filter(func(text: String):return text.begins_with("UCEQUINE|corpse|"))[-1]
				var corpse_serial:=int(response.split("|")[2])
				if not check(await until(func():return session.world_items.has(corpse_serial) and observer.world_items.has(corpse_serial)),"real corpse item replicates to both clients"):return
				if not check(int(session.world_items[corpse_serial].get("amount",0))==body,"corpse packet retains original creature identity"):return
				if not bovine_probes.is_empty() and not await finish_bovine_transition(bovine_probes, session, observer, serial, corpse_serial, body, sex):return
				var presenter:=preload("res://Presentation/WorldItems.gd").new();root.add_child(presenter)
				var visual_root:=Node3D.new();root.add_child(visual_root)
				if not check(presenter._equine_corpse(visual_root,session.world_items[corpse_serial],corpse_serial),"received native corpse selects matching death model"):return
				visual_root.free();presenter.hint.free();presenter.free();loose.free()
			records.append({"female":sex==1,"class":fields[5],"native_class":fields[5],"body":body,"mount_item":item,"ethereal":ethereal,"ride_permitted":not denied,"fixture_variant":variant,"ranked_faction_member":variant>=34 and variant<=37,"native_ethics_oath":variant>=38 and variant<=41})
			replies[sex].clear();session.send_command("[EquineFixture cleanup")
			if not check(await until(func():return replies[sex].has("UCEQUINE|cleaned")),"owned disposable fixture cleaned"):return
		if equine_completion or ethics_only:
			replies[sex].clear();session.send_command("[EquineFixture ethics-status")
			if not check(await until(func():return replies[sex].any(func(text: String):return text.begins_with("UCEQUINE|ethics|"))),"native ethics availability reported"):return
			ethics_status.append({"female":sex==1,"reply":replies[sex][-1]})
			if not check(replies[sex][-1]=="UCEQUINE|ethics|1|1","both native ethics identities remain registered"):return
	if ethics_only and not await save_ethics():return
	for actor in avatars:actor.free()
	for session in sessions:session.close()
	var report:="source-mounts-live.json" if source_mounts else "cu-sidhe-active-live.json" if cu_active else "cu-sidhe-live.json" if cu_sidhe else "hiryu-active-live.json" if hiryu_active else "hiryu-live.json" if hiryu else "ethereal-beetle-live.json" if ethereal_beetle else "fire-beetle-live.json" if fire_beetle else "giant-beetle-live.json" if giant_beetle else "sea-horse-live.json" if sea_horse else "bovine-live.json" if bovines else "ethics-live.json" if ethics_only else "equine-completion-live.json" if equine_completion else "llama-completion-live.json" if llama_completion else "live-validation.json"
	var scope:="Actual world entry, native classes/permissions, layer 25, hues, mounted movement, observer replication and dismount on isolated pinned ModernUO. Ranked faction membership and native ethical oaths are disposable test setup; normal mount checks remain active. No production world or saves touched."
	if source_mounts:scope="Swamp Dragons and Ridgebacks on the isolated native server. Normal mounting, rider action packets, hues, walk/run, dismount and corpses. The real barding deed is used with the client target cursor; its placement in the disposable backpack is fixture setup."
	if bovines:scope="Actual two-client world entry, four native bovine bodies/hues, native Move walk/run replication, real Cow.Tip packets/recovery, owning-player milking API servings/exhaustion, real death and corpse art. Flat arena relocation is fixture setup, not movement evidence. No autonomous AI/pathfinding or complete gameplay/eligibility audit; milking uses the server API, not a client beverage-item interaction."
	if giant_beetle:scope="Pinned native Beetle constructor and two loopback clients. Controlled owner setup, ordinary mounting and dismounting, native walk and run, full and partial hues, classic actions, normal owner pack opening and native death/corpse. Pack permissions for friends and strangers, loot transfer and autonomous combat are separate."
	if fire_beetle:scope="Pinned native FireBeetle constructor and two loopback clients. Native default hue, ordinary mount and dismount, mounted walk and run, full and partial hues, controlled classic actions and native corpse. Normal ore use targets the loose Fire Beetle and receives iron ingots. Smithing recipes and autonomous combat are separate."
	if ethereal_beetle:scope="Pinned native EtherealBeetle statuette 0x260F, ordinary summon and dismount, equipped item 0x3E97, spectral and custom hue, movement, observer replication and dyed statuette return. No loose native creature or corpse."
	if hiryu:scope="Both native Hiryu constructors on two loopback clients. Disposable control setup, ordinary mount and dismount, exact layer 25 item and raw hues, grounded capability and state, server walking and running, and native static corpses. Natural taming is separate."
	if cu_sidhe:scope="Native Cu Sidhe permissions for human owners with and without the pads and for elf owners. Both permitted cases exercise client rider presentation, native mounting, hues, movement, dismount and corpses."
	if sea_horse:scope="Real two-client native SeaHorse constructor144/item0x3EB3; both controlled owners use normal mount/movement/dismount, loose Move walk/run, full/partial hues/actions/death/corpse replication. Native flags are non-swimming, walking and not tamable: fixture control does not establish taming eligibility. Uses the documented client horse-art fallback, not recovered SeaHorse geometry or water-riding gameplay. Controlled sampling is not autonomous AI/choreography certification."
	var evidence := {"checks":checks,"failures":0,"records":records,"ethics_status":ethics_status,"scope":scope}
	if not bovine_actions.is_empty():
		evidence.bovine_actions = bovine_actions
		evidence.bovine_inputs = {}
		for path: String in ["Network/OstardLive.gd", "Network/BovineLiveTransition.gd", "Presentation/BovineActionsVisual.gd",
				"Presentation/CreatureDeathsWithBovines.gd", "Presentation/CreatureDeaths.gd", "Presentation/AnimalVisual.gd",
				"Presentation/BovineVisual.gd", "Presentation/CorpseModels.gd", "Presentation/WorldItems.gd",
				"../Server/HorseIntegrationFixtures/EquineFixtures.cs", "local-art/animals/bovine-actions-bake.json"]:
			evidence.bovine_inputs[path] = FileAccess.get_sha256("res://" + path)
	if cu_sidhe:
		if not check(FileAccess.get_sha256(CU_PACKAGE) == cu_pin,"Cu Sidhe package stays fixed during native verification"):return
		evidence["checks"] = checks
		evidence["preparation_sha256"] = cu_pin
		evidence["normal_registry"] = cu_active
	if hiryu:
		if not check(FileAccess.get_sha256(HIRYU_PACKAGE) == hiryu_pin,"Hiryu package stays fixed during native verification"):return
		evidence["checks"] = checks
		evidence["preparation_sha256"] = hiryu_pin
		evidence["normal_registry"] = hiryu_active
	var file:=FileAccess.open("res://../outputs/ostard-riding/"+report,FileAccess.WRITE);file.store_string(JSON.stringify(evidence,"\t"));file.close()
	print("OSTARD NATIVE INTEGRATION: ",checks," checks / 0 failures");quit()
func beetle_pack(session: Node,sex: int,serial: int) -> bool:
	var response := await fixture_reply(session,sex,"beetle-pack","UCEQUINE|beetle-pack|")
	var fields := response.split("|")
	if not check(fields.size()==4,"Fixture seeded an item in the native strong backpack"):return false
	var pack := int(fields[2])
	var marker := int(fields[3])
	session.context_menu.clear()
	if not check(session.request_context(serial),"Owner requests the loose Beetle's native context menu"):return false
	if not check(await until(func():return int(session.context_menu.get("serial",0))==serial),"Server sends context for the same Beetle"):return false
	var options: Array = session.context_menu.options.filter(func(option: Dictionary):return int(option.label)==3006145)
	if not check(options.size()==1 and session.choose_context(int(options[0].index)),"Owner selects the native Open Backpack entry"):return false
	if not check(await until(func():return session.container_serial==pack),"Server opens the actual Beetle strong backpack"):return false
	return check(await until(func():
		var item: Dictionary = session.known_items.get(marker,{})
		return int(item.get("container",0))==pack and int(item.get("id",0))==0xE21 and int(item.get("amount",0))==3),
		"Native container contents expose the original seeded bandage stack")
func apply_swamp_barding(session: Node, observer: Node, sex: int, serial: int) -> int:
	var fields := (await fixture_reply(session, sex, "barding-deed", "UCEQUINE|barding-deed|")).split("|")
	if not check(fields.size() == 4, "Fixture supplies a native dull copper barding deed"):return -1
	var deed := int(fields[2])
	var hue := int(fields[3])
	if not check(await object_ready(session), "Backpack action delay respected"):return -1
	session.open_backpack()
	if not check(await until(func():return session.known_items.has(deed)), "Client receives its barding deed"):return -1
	if not check(await object_ready(session) and session.use_item(deed), "Player opens the real barding target cursor"):return -1
	if not check(await until(func():return not session.target_request.is_empty()), "Server requests a barding target"):return -1
	if not check(preload("res://Network/ActionRunner.gd").target_entity(session, serial), "Player targets the actual Swamp Dragon"):return -1
	if not check(await until(func():
		var owner_body: Dictionary = session.entities.get(serial, {})
		var observed_body: Dictionary = observer.entities.get(serial, {})
		return not session.known_items.has(deed) and int(owner_body.get("body", 0)) == 799 \
			and int(observed_body.get("body", 0)) == 799 and int(owner_body.get("hue", -1)) == hue \
			and int(observed_body.get("hue", -1)) == hue), "Barding consumes the deed and replicates the new body and hue"):return -1
	return hue

func source_rider_actions(session: Node, observer: Node, sex: int, serial: int, actor: Node3D) -> bool:
	var remote := preload("res://Presentation/HumanAvatar.gd").new()
	root.add_child(remote)
	remote.apply_server_appearance(observer.entities[serial], observer.mobile_equipment[serial].values())
	for group in range(23, 30):
		session.last_mobile_actions.erase(serial)
		observer.last_mobile_actions.erase(serial)
		await fixture_reply(session, sex, "rider-action " + str(group), "UCEQUINE|rider-action|")
		if not check(await until(func():return session.last_mobile_actions.has(serial) and observer.last_mobile_actions.has(serial)), "Native rider action reaches both clients"):
			remote.free()
			return false
		var expected: String = preload("res://Presentation/HumanActions.gd").CLASSIC[group]
		for pair in [[session, actor], [observer, remote]]:
			var request: Dictionary = pair[0].last_mobile_actions[serial]
			if not check(int(request.action) == group and pair[1].receive_native_action(request)
				and pair[1].human_visual.action_clip == expected, "Mounted avatar selects " + expected):
				remote.free()
				return false
	remote.free()
	return true

func fire_beetle_smelt(session: Node,sex: int,serial: int) -> bool:
	var response := await fixture_reply(session,sex,"fire-ore","UCEQUINE|fire-ore|")
	var fields := response.split("|")
	if not check(fields.size()==4,"Fixture supplies fixed-size iron ore to the disposable owner"):return false
	var pack := int(fields[2])
	var ore := int(fields[3])
	if not check(await object_ready(session),"Native backpack action delay respected"):return false
	session.open_backpack()
	if not check(await until(func():return int(session.known_items.get(ore,{}).get("container",0))==pack),
		"Client receives the exact iron ore from the server"):return false
	var ingots := func() -> int:
		var count := 0
		for item: Dictionary in session.contents_of(pack):
			if int(item.get("id",0))==0x1bf2:count+=int(item.get("amount",0))
		return count
	var before: int = ingots.call()
	if not check(await object_ready(session) and session.use_item(ore),"Normal double-click requests ore smelting"):return false
	if not check(await until(func():return not session.target_request.is_empty()),"Native ore interaction sends a targeting cursor"):return false
	if not check(preload("res://Network/ActionRunner.gd").target_entity(session,serial),"Player targets the actual loose Fire Beetle"):return false
	return check(await until(func():return not session.known_items.has(ore) and int(ingots.call())==before+4),
		"Native smelting consumes four ore and adds four iron ingots")
func sea_horse_interactions(session: Node,observer: Node,sex: int,serial: int,loose: Node3D) -> bool:
	for hue in [53,0x8000|53]:
		await fixture_reply(session,sex,"colour "+str(hue),"UCEQUINE|colour|")
		if not check(await until(func():return int(session.entities[serial].get("hue",0))==hue and int(observer.entities[serial].get("hue",0))==hue),"native loose SeaHorse full/partial hues reach both clients"):return false
		loose.apply_server_appearance(session.entities[serial],[])
		if not check(loose.horse_visual.native_hue==hue,"SeaHorse retains actual raw hue flags over its fallback tint"):return false
	for running in [false,true]:
		var start:=Time.get_ticks_msec()
		while Time.get_ticks_msec()-start<800:await process_frame
		var response:=await fixture_reply(session,sex,"animal-step "+("1" if running else "0"),"UCEQUINE|step|")
		if response.is_empty():return false
		var fields:=response.split("|");var target:=Vector2i(int(fields[2]),int(fields[3]))
		if not check(await until(func():return Vector2i(session.entities[serial].x,session.entities[serial].y)==target and Vector2i(observer.entities[serial].x,observer.entities[serial].y)==target),"actual loose SeaHorse Move walk/run reaches both clients"):return false
		if not check(bool(session.entities[serial].get("running",false))==running and bool(observer.entities[serial].get("running",false))==running,"native loose SeaHorse running flag is retained"):return false
		loose.animate(true,0.,.1,6.8 if running else 1.8)
		if not check(loose.horse_visual.current_clip==("canter" if running else "walk"),"actual loose SeaHorse avatar selects the matching shared gait"):return false
	return true
func save_ethics() -> bool:
	for sex in 2:
		var session: Node=sessions[sex];var variant:=38+sex
		var response:=await fixture_reply(session,sex,"prepare "+str(variant),"UCEQUINE|prepared|")
		if not await join_ethics(session,sex,variant):return false
		var serial:=int(response.split("|")[2]);var item: int=[0x3ea8,0x3ea7][sex]
		if not check(await until(func():return session.entities.has(serial)) and await object_ready(session) and session.use_mobile(serial),"normal ethical ride before native save"):return false
		if not check(await until(func():return int(session.equipment.get(25,{}).get("id",0))==item),"ethical steed mounted for persistence"):return false
		await fixture_reply(session,sex,"ethics-link","UCEQUINE|linked")
	var session: Node=sessions[0]
	var duplicate:=await fixture_reply(session,0,"ethics-duplicates","UCEQUINE|duplicates|")
	if not check(duplicate.ends_with("|1"),"duplicate registration preserves original identities and rejects duplicates"):return false
	await fixture_reply(session,0,"ethics-save","UCEQUINE|save-requested")
	var ready:=false
	for attempt in 100:
		var response:=await fixture_reply(session,0,"ethics-owner","UCEQUINE|owner|")
		if response.ends_with("|Running"):ready=true;break
		var start:=Time.get_ticks_msec()
		while Time.get_ticks_msec()-start<100:await process_frame
	return check(ready,"native world save completed before disposable restart")
func resume_ethics() -> void:
	var loaded: Array=[]
	for sex in 2:
		var session: Node=sessions[sex];var item: int=[0x3ea8,0x3ea7][sex]
		var response:=await fixture_reply(session,sex,"ethics-owner","UCEQUINE|owner|");var fields:=response.split("|")
		if response.is_empty():return
		print("ETHICS RESTORED STATE: ",response)
		if not check(fields[2]==("HeroEthic" if sex==0 else "EvilEthic"),"native ethical allegiance restored after process restart"):return
		if not check(int(fields[3])==item and int(fields[4])>0,"saved steed reference and actual mount restored"):return
		if not check(fields[5]=="1" and fields[6]=="1","loaded registries contain each player exactly once"):return
		if not check(await until(func():return int(session.equipment.get(25,{}).get("id",0))==item),"restored layer 25 reaches the client"):return
		if not check(await object_ready(session) and session.use_mobile(int(session.player.serial)),"normal dismount of restored ethical steed"):return
		if not check(await until(func():return not session.equipment.has(25)),"server removes restored mounted equipment"):return
		var steed_serial:=int(fields[4])
		if not check(await until(func():return session.entities.has(steed_serial)) and await object_ready(session) and session.use_mobile(steed_serial),"normal double-click remount request after native restart"):return
		if not check(await until(func():return int(session.equipment.get(25,{}).get("id",0))==item),"restored ethical eligibility permits remounting"):return
		loaded.append({"female":sex==1,"reply":response})
	for actor in avatars:actor.free()
	for session in sessions:session.close()
	var file:=FileAccess.open("res://../outputs/ostard-riding/ethics-restart.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":0,"records":loaded,"scope":"Real native world save and fresh process restart of disposable ethical players and mounted steeds; not production saves."},"\t"));file.close()
	print("ETHICS NATIVE RESTART: ",checks," / 0 failures");quit()
func bovine_interactions(session: Node,observer: Node,sex: int,serial: int,body: int,loose: Node3D) -> bool:
	for hue in [53,0x8000|53]:
		session.send_command("[EquineFixture colour "+str(hue))
		if not check(await until(func():return int(session.entities[serial].get("hue",0))==hue and int(observer.entities[serial].get("hue",0))==hue),"native loose bovine full/partial hue reaches both clients"):return false
		loose.apply_server_appearance(session.entities[serial],[])
		if not check(loose.horse_visual.native_hue==hue,"source bovine preserves exact raw hue flags"):return false
	for running in [false,true]:
		var wait_start:=Time.get_ticks_msec()
		while Time.get_ticks_msec()-wait_start<800:await process_frame
		var response:=await fixture_reply(session,sex,"bovine-step "+("1" if running else "0"),"UCEQUINE|step|")
		if response.is_empty():return false
		var fields:=response.split("|");var target:=Vector2i(int(fields[2]),int(fields[3]))
		print("BOVINE NATIVE STEP: ",response)
		if not check(await until(func():return Vector2i(session.entities[serial].x,session.entities[serial].y)==target and Vector2i(observer.entities[serial].x,observer.entities[serial].y)==target),"native animal Move walk/run coordinates replicate to both clients"):return false
		if not check(bool(session.entities[serial].get("running",false))==running and bool(observer.entities[serial].get("running",false))==running,"native animal run flag reaches both clients"):return false
		loose.animate(true,0.,.1,6.8 if bool(session.entities[serial].running) else 1.8)
		if not check(loose.horse_visual.current_clip==("Run" if running else "Walk"),"received moving bovine uses its native source gait"):return false
	if body in [0xd8,0xe7]:
		session.last_mobile_actions.erase(serial);observer.last_mobile_actions.erase(serial)
		await fixture_reply(session,sex,"bovine-tip","UCEQUINE|tipped")
		if not check(await until(func():return session.last_mobile_actions.has(serial) and observer.last_mobile_actions.has(serial)),"real Cow.Tip packet reaches both clients"):return false
		if not check(loose.receive_native_action(session.last_mobile_actions[serial]) and not loose.horse_visual.dead,"native tipped cow stays alive in the actual avatar"):return false
		loose.horse_visual.action_remaining=.001;loose.horse_visual._process(.01)
		if not check(loose.horse_visual.current_clip=="Idle","live cow-tip category recovers to standing"):return false
		for attempt in 5:
			var response:=await fixture_reply(session,sex,"bovine-milk","UCEQUINE|milk|")
			if not check(response=="UCEQUINE|milk|"+("1|"+str(3-attempt) if attempt<4 else "0|0"),"native milking API retains four servings and exhaustion"):return false
	return true

func begin_bovine_transition(session: Node, observer: Node, sex: int, serial: int, body: int, loose: Node3D) -> Array[Node3D]:
	var other := preload("res://Presentation/HumanAvatar.gd").new()
	other.initial_body = body
	root.add_child(other)
	other.set_physics_process(false)
	other.apply_server_appearance(observer.entities[serial], [])
	var probes: Array[Node3D] = []
	for entry: Array in [[session, loose], [observer, other]]:
		var probe := BovineTransition.new()
		root.add_child(probe)
		probe.configure(entry[0], serial, entry[1])
		probes.append(probe)
	other.reparent(probes[1])
	var actions := {6: "Attack2", 10: "Fidget2"}
	if sex == 1:actions[12] = "Death2"
	for group: int in actions:
		session.last_mobile_actions.erase(serial)
		observer.last_mobile_actions.erase(serial)
		if (await fixture_reply(session, sex, "action %d" % group, "UCEQUINE|action|")).is_empty():return []
		if not check(await until(func():return session.last_mobile_actions.has(serial) and observer.last_mobile_actions.has(serial)),
				"Both clients receive cattle group %d" % group):return []
		for entry: Array in [[session, loose], [observer, other]]:
			var packet: Dictionary = entry[0].last_mobile_actions[serial]
			if not check(packet.protocol == "classic" and packet.action == group and entry[1].receive_native_action(packet)
					and entry[1].horse_visual.current_clip == actions[group], "Cattle group %d plays %s" % [group, actions[group]]):return []
	return probes

func finish_bovine_transition(probes: Array[Node3D], session: Node, observer: Node, serial: int, corpse: int, body: int, sex: int) -> bool:
	var expected := "Death2" if sex == 1 else "Death"
	var transitions: Array[Dictionary] = []
	for index in probes.size():
		var probe: Node3D = probes[index]
		var connection: Node = session if index == 0 else observer
		var item: Dictionary = connection.world_items[corpse]
		var event: Dictionary = probe.events.get(serial, {})
		if not check(not event.is_empty() and event.corpse == corpse and event.body == body and event.clip == expected
				and event.hue == int(item.hue), "Native cattle death packet starts the matching collapse"):return false
		if not check(probe.place_corpse(corpse, item), "Native cattle corpse builds from its network item"):return false
		transitions.append(event)
	if not check(await until(func():return not session.entities.has(serial) and not observer.entities.has(serial)),
			"Native cattle mobile is removed on both clients"):return false
	for probe: Node3D in probes:
		if not check(await until(func():return probe.settled(corpse)), "The settled native cattle corpse is visible"):return false
		if not check(probe.verify_corpse(corpse, body, int(session.world_items[corpse].hue), expected),
				"The frozen cattle corpse retains body, raw hue and collapse pose"):return false
		probe.free()
	bovine_actions.append({"body": body, "female": sex == 1, "transitions": transitions})
	return true
