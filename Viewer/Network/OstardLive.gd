extends SceneTree
## Only scripts/test-horses.ps1 -Live -Ostards supplies this disposable server.
const Game=preload("res://Network/GameSession.gd")
const Horse=preload("res://Presentation/MountVisual.gd")
var sessions: Array=[]
var avatars: Array=[]
var errors: Array=[]
var replies: Array=[]
var checks:=0
var records: Array=[]
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
		session.create_character("Equine Woman" if sex else "Equine Man",slot,city,sex==1)
		if not check(await until(func():return session.phase=="world"),"actual isolated ModernUO world entry"):return
		var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if sex else 400;root.add_child(actor);actor.set_physics_process(false);avatars.append(actor)
	for sex in 2:
		var session: Node=sessions[sex];var observer: Node=sessions[1-sex];var actor: Node3D=avatars[sex];var me:=int(session.player.serial)
		for variant in [13,14,15,16,17,18,19,20,21]:
			replies[sex].clear();session.send_command("[EquineFixture prepare "+str(variant))
			if not check(await until(func():return not replies[sex].is_empty()),"real upstream equine fixture prepared"):return
			var fields: PackedStringArray=replies[sex][-1].split("|")
			if not check(fields.size()==6 and fields[1]=="prepared","fixture identifies actual native class/body/mount"):return
			var serial:=int(fields[2]);var body:=int(fields[3]);var item:=int(fields[4]);var ethereal: bool=variant in [16,21]
			print("EQUINE LIVE VARIANT: ",fields[5]," body=",body," item=",item," female=",sex==1)
			if not ethereal:
				if not check(await until(func():return session.entities.has(serial) and observer.entities.has(serial)),"both clients receive the real loose animal"):return
				var loose:=preload("res://Presentation/HumanAvatar.gd").new();loose.initial_body=body;root.add_child(loose);loose.set_physics_process(false);loose.apply_server_appearance(session.entities[serial],[])
				if not check(loose.horse_visual!=null and loose.horse_visual.native_body==body,"received mobile selects the new equine art"):return
				loose.free()
			if not check(await object_ready(session),"native item delay respected"):return
			if not check(session.use_mobile(serial) if not ethereal else session.use_item(serial),"normal double-click request sent"):return
			var denied: bool=variant==20 or variant==17 and sex==1
			if denied:
				replies[sex].clear();session.send_command("[EquineFixture audit")
				if not check(await until(func():return not replies[sex].is_empty()),"server audits the restricted ride attempt"):return
				if not check(replies[sex][-1].begins_with("UCEQUINE|audit|0|") and not session.equipment.has(25),"native ki-rin gender restriction and unrideable pack llama preserved"):return
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
				for action_code in [5,4]:
					session.last_mobile_actions.erase(serial);observer.last_mobile_actions.erase(serial)
					session.send_command("[EquineFixture action "+str(action_code))
					if not check(await until(func():return session.last_mobile_actions.has(serial) and observer.last_mobile_actions.has(serial)),"native attack/reaction packet arrives on both clients"):return
					if not check(loose.receive_native_action(session.last_mobile_actions[serial]),"actual creature consumes server attack/reaction"):return
					if not check(loose.horse_visual.current_clip in (["rear","hit"] if body==0x319 else ["Attack","Hit"]),"native action selects the species clip"):return
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
			records.append({"female":sex==1,"class":fields[5],"body":body,"mount_item":item,"ethereal":ethereal,"ride_permitted":not denied})
			replies[sex].clear();session.send_command("[EquineFixture cleanup")
			if not check(await until(func():return replies[sex].has("UCEQUINE|cleaned")),"owned disposable fixture cleaned"):return
	for actor in avatars:actor.free()
	for session in sessions:session.close()
	var file:=FileAccess.open("res://../outputs/ostard-riding/live-validation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":0,"records":records,"scope":"Actual world entry, native classes/permissions, layer 25, hues, mounted movement, observer replication and dismount on isolated pinned ModernUO. No production world or saves touched."},"\t"));file.close()
	print("OSTARD NATIVE INTEGRATION: ",checks," checks / 0 failures");quit()
