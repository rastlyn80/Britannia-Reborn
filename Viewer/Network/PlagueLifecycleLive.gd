extends SceneTree
## Actual two-client owned spawn forms and native AI-timer removal conditions.
const Game=preload("res://Network/GameSession.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
var sessions: Array=[]
var replies: Array=[[],[]]
var errors: Array=[]
var checks:=0
func _initialize() -> void:
	create_timer(300.).timeout.connect(func():push_error("Plague native lifecycle deadline");quit(1));call_deferred("run")
func until(condition: Callable,seconds: float=15.) -> bool:
	var start:=Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-start<seconds*1000:
		if not errors.is_empty():return false
		await process_frame
	return condition.call()
func check(ok: bool,label: String) -> bool:
	checks+=1;print("PLAGUE NATIVE ","PASS: " if ok else "FAIL: ",label)
	if not ok:push_error(label+str(errors));quit(1)
	return ok
func reply(client: int,command: String,prefix: String) -> String:
	replies[client].clear();sessions[client].send_command("[PlagueLifecycleFixture "+command)
	if not check(await until(func():return replies[client].any(func(text: String):return text.begins_with(prefix))),"native owner fixture reply: "+command):return ""
	return replies[client].filter(func(text: String):return text.begins_with(prefix))[-1]
func prepare(client: int,body: int) -> Dictionary:
	var response:=await reply(client,"prepare "+str(body),"UCPLAGUE|prepared|")
	if response.is_empty():return {}
	var fields:=response.split("|");var serial:=int(fields[2]);var hue:=int(fields[4]);var lifetime:=int(fields[6]);var owner:=int(fields[5])
	if not check(int(fields[3])==body and fields.has("owner=1") and owner!=serial,"Real PlagueBeast callback creates requested random form with its actual owner"):return {}
	if not check(hue>=17 and hue<=31 and lifetime>=58000 and lifetime<=60000,"Native constructor owns hue17..31 and an unmodified one-minute deadline"):return {}
	if not check(await until(func():return sessions[0].entities.has(serial) and sessions[1].entities.has(serial)),"Owned native spawn reaches both real clients"):return {}
	for peer in 2:
		var entity: Dictionary=sessions[peer].entities[serial]
		if not check(int(entity.body)==body and int(entity.hue)==hue,"Both clients retain exact owned native body/hue"):return {}
		var actor:=Avatar.new();actor.initial_body=body;root.add_child(actor);actor.apply_server_appearance(entity,[])
		if not check(actor.native_body==body and int(actor.server_appearance.skin_hue)==hue,"Actual source or human renderer retains native appearance"):return {}
		if body in [400,401]:
			if not check(actor.human_visual!=null and actor.human_visual.female==(body==401),"Both specialized human PlagueSpawn forms use the correct human model"):return {}
		else:
			if not check(actor.horse_visual!=null and actor.horse_visual.native_body==body,"Existing or new creature source renderer handles this owned form"):return {}
		await process_frame;actor.queue_free()
	return {"serial":serial,"body":body,"hue":hue,"native_class":"PlagueSpawn","female":client==1,"owner_serial":owner,"constructor_attempts":int(fields[7]),"native_lifetime_ms":lifetime,"kind":"owned PlagueSpawn source/human routing"}
func run() -> void:
	var accounts: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"));var records: Array=[];var lifecycle: Array=[]
	for client in 2:
		var session:=Game.new();root.add_child(session);sessions.append(session);session.failed.connect(func(reason: String):errors.append(reason));session.message_received.connect(func(text: String):
			if text.begins_with("UCPLAGUE|"):replies[client].append(text))
		session.connect_account(accounts[client].username,accounts[client].password,2594)
		if not check(await until(func():return session.phase=="characters"),"Actual disposable owner login"):return
		var chosen: Dictionary={}
		for character: Dictionary in session.characters:
			if not str(character.name).is_empty():chosen=character;break
		if not check(not chosen.is_empty(),"Reuse this disposable world's test character"):return
		session.select_character(int(chosen.slot),str(chosen.name))
		if not check(await until(func():return session.phase=="world"),"Actual native world entry for both lifecycle observers"):return
	for client in 2:
		for body in [14,31,400,401,29,21,51]:
			var record:=await prepare(client,body)
			if record.is_empty():return
			var serial:=int(record.serial);await process_frame
			if not check(sessions[0].entities.has(serial) and sessions[1].entities.has(serial),"Nearby unexpired owned spawn remains live on both clients"):return
			records.append(record)
			if (await reply(client,"cleanup","UCPLAGUE|cleaned")).is_empty():return
		for condition in ["range","map","delete"]:
			var record:=await prepare(client,51)
			if record.is_empty():return
			var serial:=int(record.serial);var before_items: Array=[sessions[0].world_items.keys(),sessions[1].world_items.keys()]
			if (await reply(client,"owner-"+condition,"UCPLAGUE|condition|")).is_empty():return
			if not check(await until(func():return not sessions[0].entities.has(serial) and not sessions[1].entities.has(serial)),"Native AI OnThink removes owned spawn after owner "+condition+" on both clients"):return
			var response:=await reply(client,"audit","UCPLAGUE|audit|")
			if not check(response.contains("deleted=1"),"Native server confirms lifecycle deletion rather than client culling"):return
			for peer in 2:
				var added_corpse:=false
				for item: int in sessions[peer].world_items:
					if item not in before_items[peer] and int(sessions[peer].world_items[item].get("id",0))==0x2006:added_corpse=true
				if not check(not added_corpse,"Native lifecycle Delete does not invent a death corpse"):return
			lifecycle.append({"client":client,"condition":condition,"body":51,"native_deleted":true,"two_client_removal":true})
			if (await reply(client,"cleanup","UCPLAGUE|cleaned")).is_empty():return
	var expiry: Array=[]
	for client in 2:
		var record:=await prepare(client,51)
		if record.is_empty():return
		record.started_ms=Time.get_ticks_msec();expiry.append(record)
	if not check(await until(func():return expiry.all(func(record: Dictionary):return not sessions[0].entities.has(int(record.serial)) and not sessions[1].entities.has(int(record.serial))),75.),"Both owned spawns expire through their ordinary native AI timer without changing time/deadlines"):return
	for client in 2:
		var elapsed:=Time.get_ticks_msec()-int(expiry[client].started_ms);var response:=await reply(client,"audit","UCPLAGUE|audit|")
		if not check(elapsed>=58000 and response.contains("deleted=1"),"Unmodified one-minute native expiry is server-confirmed"):return
		lifecycle.append({"client":client,"condition":"native one-minute expiry","elapsed_ms":elapsed,"initial_native_lifetime_ms":expiry[client].native_lifetime_ms,"two_client_removal":true})
		if (await reply(client,"cleanup","UCPLAGUE|cleaned")).is_empty():return
	var output:="res://../outputs/creatures/plague_spawn";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output));FileAccess.open(output+"/live.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":0,"records":records,"lifecycle":lifecycle,"renderer":RenderingServer.get_current_rendering_method(),"fixture_sha256":FileAccess.get_sha256("res://../Server/HorseIntegrationFixtures/PlagueLifecycleFixtures.cs"),"test_sha256":FileAccess.get_sha256("res://Network/PlagueLifecycleLive.gd"),"scope":"Real two-client world entry, all7random owned PlagueSpawn forms sampled through native PlagueBeast.OnGotMeleeAttack callback without assigning Body/Hue/Owner/stats. Movement frozen for controlled observation; minion AI timers remain active and native OnThink removes them for owner range/map/deletion and actual unmodified one-minute expiry. Owner relocation is fixture setup, not multiplayer movement. No autonomous combat, taming, save/reload or complete native gameplay claim; production/saves excluded."}));print("PLAGUE OWNED NATIVE: ",checks," checks/0failures;14owned forms/8native lifecycle cases");quit()
