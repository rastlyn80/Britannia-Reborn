extends SceneTree
## Real native packets against scripts/test-horses.ps1's disposable server only.
const Game=preload("res://Network/GameSession.gd")
const Horse=preload("res://Presentation/HorseVisual.gd")
var sessions: Array=[]
var avatars: Array=[]
var errors: Array=[]
var replies: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func until(condition: Callable,seconds: float = 15.) -> bool:
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
	print("HORSE LIVE PASS: ",label);return true
func run() -> void:
	var accounts: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"))
	for sex in 2:
		var session:=Game.new();root.add_child(session);sessions.append(session);replies.append([])
		session.failed.connect(func(reason: String):errors.append(reason))
		session.message_received.connect(func(text: String):
			if text.begins_with("UCHORSE|"):replies[sex].append(text))
		session.connect_account(accounts[sex].username,accounts[sex].password,2594)
		if not check(await until(func():return session.phase=="characters"),"isolated native account login"):return
		var slot:=-1;var city:=-1
		for character in session.characters:
			if character.name.is_empty():slot=int(character.slot);break
		for place in session.cities:
			if place.name=="Britain":city=int(place.index);break
		if not check(slot>=0 and city>=0,"isolated native character slot and Britain start"):return
		session.create_character("Rider Woman" if sex else "Rider Man",slot,city,sex==1)
		if not check(await until(func():return session.phase=="world"),"actual world entry on isolated ModernUO"):return
		var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if sex else 400;root.add_child(actor);actor.set_physics_process(false);avatars.append(actor)
		actor.apply_server_appearance(session.player,session.equipment.values())
		session.mobile_action_received.connect(func(action: Dictionary):
			if int(action.serial)==int(session.player.serial):actor.receive_native_action(action))
	for sex in 2:
		var session: Node=sessions[sex];var observer: Node=sessions[1-sex];var actor: Node3D=avatars[sex]
		var me:=int(session.player.serial)
		for body: int in Horse.BODIES:
			var variant:=Horse.BODIES.keys().find(body);replies[sex].clear()
			session.send_command("[HorseFixture prepare "+str(variant))
			if not check(await until(func():return not replies[sex].is_empty()),"native horse fixture prepared"):return
			var fields: PackedStringArray=replies[sex][-1].split("|")
			if not check(fields.size()>=5 and fields[1]=="prepared","fixture is a real upstream Horse"):return
			var serial:=int(fields[2]);var item:=int(fields[4])
			if not check(await until(func():return session.entities.has(serial) and observer.entities.has(serial)),"both clients receive the unmounted horse mobile"):return
			if not check(await until(func():return Time.get_ticks_msec()>=session.next_item_action),"native delay before mounting respected"):return
			if not check(session.use_mobile(serial),"mount request uses native double-click"):return
			if not check(await until(func():return session.equipment.has(25) and int(session.equipment[25].id)==item),"server confirms native mount equipment"):return
			if not check(await until(func():return observer.mobile_equipment.get(me,{}).has(25)),"second client receives mounted equipment"):return
			actor.apply_server_appearance(session.player,session.equipment.values());actor.animate(false,0.,.1,0.)
			if not check(actor.horse_visual!=null and actor.human_visual.mounted_live_enabled and actor.horse_visual.native_body==body,"real server mount selects matching horse and seated rider"):return
			if not check(await until(func():return actor.rider_contact.seated_weight>=1.),"rider completes seat transition"):return
			if not check(actor.rider_contact.seat_error<.002,"live rider remains on animated saddle"):return
			for hue in [53,1153,0x8000|53,0,53]:
				session.send_command("[HorseFixture colour "+str(hue))
				if not check(await until(func():return int(session.equipment.get(25,{}).get("hue",-1))==hue),"server hue change reaches the ridden mount item"):return
				if not check(await until(func():return int(observer.mobile_equipment.get(me,{}).get(25,{}).get("hue",-1))==hue),"observer receives the same full raw mount hue"):return
				actor.apply_server_appearance(session.player,session.equipment.values())
				if not check(actor.horse_visual.native_hue==hue and actor.horse_visual.native_body==body,"live coat keeps both server identity and changed hue"):return
			if variant==3:
				var acknowledged:=[false]
				observer.module("player").logged_out.connect(func():acknowledged[0]=true,CONNECT_ONE_SHOT)
				observer.send(preload("res://Network/Packets/Player.gd").logout_request())
				if not check(await until(func():return acknowledged[0]),"observer native logout is acknowledged"):return
				observer.close();await create_timer(2.).timeout
				observer.connect_account(accounts[1-sex].username,accounts[1-sex].password,2594)
				if not check(await until(func():return observer.phase=="characters"),"observer reconnects to the isolated account"):return
				for character in observer.characters:
					if character.name==("Rider Man" if sex else "Rider Woman"):observer.select_character(character.slot,character.name);break
				if not check(await until(func():return observer.phase=="world"),"observer genuinely re-enters the world"):return
				if not check(await until(func():return int(observer.mobile_equipment.get(me,{}).get(25,{}).get("hue",-1))==53),"re-entry restores the other rider's changed mount hue"):return
			for group in [26,27,28,29]:
				session.send_command("[HorseFixture action "+str(group))
				if not check(await until(func():return int(session.last_mobile_actions.get(me,{}).get("action",-1))==group),"server sends mounted action "+str(group)):return
				if not check(await until(func():return int(observer.last_mobile_actions.get(me,{}).get("action",-1))==group),"second client receives mounted action "+str(group)):return
				if not check(actor.human_visual.action_clip.begins_with("Rider_"),"received action plays on seated presentation"):return
			# Native movement is acknowledged by the real server. With no prepared
			# terrain predictor in this small harness the session requests its
			# authoritative position after each ack; it never invents multiplayer.
			var moved:=false
			for run in [false,true]:
				moved=false
				for direction in range(8):
					if not await until(func():return session.outstanding==-1 and not session.awaiting_position and Time.get_ticks_msec()>=session.next_walk):break
					var origin:=Vector2i(session.player.x,session.player.y)
					if session.walk(direction,run):
						if not await until(func():return session.outstanding==-1 and not session.awaiting_position):break
						if Vector2i(session.player.x,session.player.y)!=origin:
							moved=true
							if not check(session.move_interval==(105 if run else 205),"native mounted walk/run pacing"):return
							break
				if not check(moved,"server-confirmed mounted movement"):return
			if not check(await until(func():return Time.get_ticks_msec()>=session.next_item_action),"native object-use delay respected"):return
			if not check(session.use_mobile(me),"dismount request uses native self double-click"):return
			if not check(await until(func():return not session.equipment.has(25)),"server removes native mount equipment"):return
			if not check(await until(func():return not observer.mobile_equipment.get(me,{}).has(25)),"second client receives dismount"):return
			if not check(await until(func():return session.entities.has(serial) and observer.entities.has(serial)),"horse returns as a real world mobile on both clients"):return
			if not check(int(session.entities[serial].get("hue",-1))==53 and int(observer.entities[serial].get("hue",-1))==53,"changed hue survives conversion back to the loose horse"):return
			actor.apply_server_appearance(session.player,session.equipment.values())
			if not check(await until(func():return actor.horse_visual==null),"visual leg-over dismount completes after authoritative unequip"):return
			if not check(actor.horse_visual==null and not actor.human_visual.mounted_live_enabled,"rider returns to on-foot presentation"):return
			replies[sex].clear();session.send_command("[HorseFixture cleanup")
			if not check(await until(func():return replies[sex].has("UCHORSE|cleaned")),"disposable fixture cleaned"):return
	for actor in avatars:actor.free()
	for session in sessions:session.close()
	var file:=FileAccess.open("res://../outputs/horse-session/live-validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":0,"server":"isolated pinned ModernUO at loopback:2594; separate accounts/world; no production saves copied","bodies":Horse.BODIES.keys(),"scope":"Native creation/world entry, horse mobiles, double-click mounting/dismounting, layer-25 updates, seated presentation, server actions, mounted movement and second-client observation on both human bodies."},"\t"));file.close()
	print("HORSE NATIVE INTEGRATION: ",checks," checks / 0 failures");quit()
