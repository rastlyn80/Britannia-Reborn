extends SceneTree
## Only scripts/test-horses.ps1 -Live -Ostards supplies this disposable server.
const Game=preload("res://Network/GameSession.gd")
const Horse=preload("res://Presentation/MountVisual.gd")
const HorseRig=preload("res://Presentation/HorseVisual.gd")
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
		for variant in (range(42,46) if bovines else [23,24,38,39,40,41] if ethics_only else range(22,33)+range(34,42) if equine_completion else [19,20,21,33] if llama_completion else [13,14,15,16,17,18,19,20,21]):
			replies[sex].clear();session.send_command("[EquineFixture prepare "+str(variant))
			if not check(await until(func():return not replies[sex].is_empty()),"real upstream equine fixture prepared"):return
			var fields: PackedStringArray=replies[sex][-1].split("|")
			if not check(fields.size()==6 and fields[1]=="prepared","fixture identifies actual native class/body/mount"):return
			var serial:=int(fields[2]);var body:=int(fields[3]);var item:=int(fields[4]);var ethereal: bool=variant in [16,21,22]
			print("EQUINE LIVE VARIANT: ",fields[5]," body=",body," item=",item," female=",sex==1)
			if variant>=38 and variant<=41 and not await join_ethics(session,sex,variant):return
			if not ethereal:
				if not check(await until(func():return session.entities.has(serial) and observer.entities.has(serial)),"both clients receive the real loose animal"):return
				var loose:=preload("res://Presentation/HumanAvatar.gd").new();loose.initial_body=body;root.add_child(loose);loose.set_physics_process(false);loose.apply_server_appearance(session.entities[serial],[])
				if not check(loose.horse_visual!=null and loose.horse_visual.native_body==body,"received mobile selects the new equine art"):return
				loose.free()
			elif not session.known_items.has(serial):
				# A closed backpack does not expose newly added contents. Open it
				# normally and wait for the native container packet before using.
				if not check(await object_ready(session),"native backpack delay respected"):return
				session.open_backpack()
				if not check(await until(func():return session.known_items.has(serial)),"native backpack contents reveal the ethereal item"):return
			if not check(await object_ready(session),"native item delay respected"):return
			if not check(session.use_mobile(serial) if not ethereal else session.use_item(serial),"normal double-click request sent"):return
			var denied: bool=bovines or variant in [20,23,24,25,26,27,28,29,33,40,41] or variant==17 and sex==1
			if denied:
				replies[sex].clear();session.send_command("[EquineFixture audit")
				if not check(await until(func():return not replies[sex].is_empty()),"server audits the restricted ride attempt"):return
				if not check(replies[sex][-1].begins_with("UCEQUINE|audit|0|") and not session.equipment.has(25),"native gender / ethics / faction / unrideable restrictions preserved"):return
			else:
				if not check(await until(func():return int(session.equipment.get(25,{}).get("id",0))==item,20.),"server equips exact native mount item (including ethereal casting)"):return
				if not check(await until(func():return int(observer.mobile_equipment.get(me,{}).get(25,{}).get("id",0))==item),"observer receives the same mount item"):return
				actor.apply_server_appearance(session.player,session.equipment.values());actor.animate(true,0.,.1,1.8)
				if not check(actor.horse_visual!=null and actor.horse_visual.native_mount_item==item and actor.horse_visual.native_body==Horse.horse_body(item),"native packet selects exact equine profile"):return
				if not check(await until(func():return actor.rider_contact.seated_weight>=1.),"rider completes animated seat transition"):return
				if not check(actor.rider_contact.seat_error<.002,"live equine rider stays on saddle"):return
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
				actor.apply_server_appearance(session.player,session.equipment.values())
				if not check(await until(func():return actor.horse_visual==null),"visual rider returns to foot after authoritative dismount"):return
			if not ethereal:
				var loose:=preload("res://Presentation/HumanAvatar.gd").new();loose.initial_body=body;root.add_child(loose);loose.set_physics_process(false);loose.apply_server_appearance(session.entities[serial],[])
				if bovines and not await bovine_interactions(session,observer,sex,serial,body,loose):return
				for action_code in [5,4,3,11]:
					session.last_mobile_actions.erase(serial);observer.last_mobile_actions.erase(serial)
					session.send_command("[EquineFixture action "+str(action_code))
					if not check(await until(func():return session.last_mobile_actions.has(serial) and observer.last_mobile_actions.has(serial)),"native attack/reaction packet arrives on both clients"):return
					if not check(loose.receive_native_action(session.last_mobile_actions[serial]),"actual creature consumes server attack/reaction"):return
					var expected: String={5:"rear",4:"hit",3:"eat",11:"lie_down"}[action_code] if loose.horse_visual is HorseRig else {5:"Attack",4:"Hit",3:"Eat",11:"LieDown"}[action_code]
					if not check(loose.horse_visual.current_clip==expected,"native action selects the species clip"):return
				replies[sex].clear();session.send_command("[EquineFixture kill")
				if not check(await until(func():return replies[sex].any(func(text: String):return text.begins_with("UCEQUINE|corpse|"))),"real upstream death creates a corpse"):return
				var response: String=replies[sex].filter(func(text: String):return text.begins_with("UCEQUINE|corpse|"))[-1]
				var corpse_serial:=int(response.split("|")[2])
				if not check(await until(func():return session.world_items.has(corpse_serial) and observer.world_items.has(corpse_serial)),"real corpse item replicates to both clients"):return
				if not check(int(session.world_items[corpse_serial].get("amount",0))==body,"corpse packet retains original creature identity"):return
				var presenter:=preload("res://Presentation/WorldItems.gd").new();root.add_child(presenter)
				var visual_root:=Node3D.new();root.add_child(visual_root)
				if not check(presenter._equine_corpse(visual_root,session.world_items[corpse_serial],corpse_serial),"received native corpse selects matching death model"):return
				visual_root.free();presenter.hint.free();presenter.free();loose.free()
			records.append({"female":sex==1,"class":fields[5],"body":body,"mount_item":item,"ethereal":ethereal,"ride_permitted":not denied,"fixture_variant":variant,"ranked_faction_member":variant>=34 and variant<=37,"native_ethics_oath":variant>=38 and variant<=41})
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
	var report:="bovine-live.json" if bovines else "ethics-live.json" if ethics_only else "equine-completion-live.json" if equine_completion else "llama-completion-live.json" if llama_completion else "live-validation.json"
	var scope:="Actual world entry, native classes/permissions, layer 25, hues, mounted movement, observer replication and dismount on isolated pinned ModernUO. Ranked faction membership and native ethical oaths are disposable test setup; normal mount checks remain active. No production world or saves touched."
	if bovines:scope="Actual two-client world entry, four native bovine bodies/hues, native Move walk/run replication, real Cow.Tip packets/recovery, owning-player milking API servings/exhaustion, real death and corpse art. Flat arena relocation is fixture setup, not movement evidence. No autonomous AI/pathfinding or complete gameplay/eligibility audit; milking uses the server API, not a client beverage-item interaction."
	var file:=FileAccess.open("res://../outputs/ostard-riding/"+report,FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":0,"records":records,"ethics_status":ethics_status,"scope":scope},"\t"));file.close()
	print("OSTARD NATIVE INTEGRATION: ",checks," checks / 0 failures");quit()
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
