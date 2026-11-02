extends SceneTree
## Real double-click/target packets drive native charm; setup is fixture-owned.
const Game=preload("res://Network/GameSession.gd")
const Protocol=preload("res://Network/ActionProtocol.gd")
const Runner=preload("res://Network/ActionRunner.gd")
var sessions: Array=[]
var replies: Array=[[],[]]
var errors: Array=[]
var checks:=0
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Silver native behaviour deadline");quit(1));call_deferred("run")
func until(condition: Callable) -> bool:
	var start:=Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-start<15000:
		if not errors.is_empty():return false
		await process_frame
	return condition.call()
func check(ok: bool,label: String) -> bool:
	checks+=1;print("SILVER NATIVE ","PASS: " if ok else "FAIL: ",label)
	if not ok:push_error(label+str(errors));quit(1)
	return ok
func reply(client: int,command: String) -> String:
	replies[client].clear();sessions[client].send_command("[SilverSerpentFixture "+command)
	if not check(await until(func():return not replies[client].is_empty()),"Native fixture reply: "+command):return ""
	return replies[client][-1]
func click(client: int,serial: int) -> void:
	await create_timer(1.2).timeout;sessions[client].send(Protocol.double_click(serial))
func run() -> void:
	var accounts: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"));var records: Array=[]
	for client in 2:
		var session:=Game.new();root.add_child(session);sessions.append(session);session.failed.connect(func(reason: String):errors.append(reason));session.message_received.connect(func(text: String):
			if text.begins_with("UCSILVER|"):replies[client].append(text))
		session.connect_account(accounts[client].username,accounts[client].password,2594)
		if not check(await until(func():return session.phase=="characters"),"Disposable native login"):return
		var chosen: Dictionary={}
		for character: Dictionary in session.characters:
			if not str(character.name).is_empty():chosen=character;break
		if not check(not chosen.is_empty(),"Existing disposable character"):return
		session.select_character(int(chosen.slot),str(chosen.name))
		if not check(await until(func():return session.phase=="world"),"Actual native world entry"):return
	for client in 2:
		var fields:=(await reply(client,"prepare")).split("|")
		if not check(fields.size()==7 and fields[1]=="prepared" and int(fields[6])==92,"Original native Silver constructor body retained"):return
		var snake:=int(fields[2]);var target:=int(fields[3]);var other:=int(fields[4]);var bag:=int(fields[5]);var owned: Array=[snake,target,other]
		if not check(await until(func():return owned.all(func(serial: int):return sessions[0].entities.has(serial) and sessions[1].entities.has(serial))),"Both actual clients receive native charm participants"):return
		await click(client,snake);fields=(await reply(client,"status")).split("|")
		if not check(fields[2]=="none" and int(fields[3])==0 and sessions[client].target_request.is_empty(),"Native double-click refuses charm without a registered familiar"):return
		fields=(await reply(client,"familiar")).split("|")
		if not check(fields.size()==5 and fields[1]=="familiar" and fields[3]=="1" and fields[4]=="1","Native Summon API creates an actual summoned/controlled DeathAdder"):return
		var familiar:=int(fields[2]);owned.append(familiar)
		if not check(await until(func():return sessions[0].entities.has(familiar) and sessions[1].entities.has(familiar)),"Native familiar replicates to both clients"):return
		await click(client,snake)
		if not check(await until(func():return not sessions[client].target_request.is_empty()),"Real double-click installs the native charm target cursor"):return
		fields=(await reply(client,"status")).split("|")
		if not check(fields[2]=="DeathAdderCharmTarget" and int(fields[3])==0,"Native private charm target, rather than a fixture substitute, is active"):return
		if not check(await until(func():return sessions[client].known_items.has(bag)) and Runner.target_entity(sessions[client],bag),"Real target packet selects an existing non-mobile backpack"):return
		fields=(await reply(client,"status")).split("|")
		if not check(fields[2]=="none" and int(fields[3])==0,"Native charm rejects a non-mobile target without assigning combat"):return
		await click(client,snake)
		if not check(await until(func():return not sessions[client].target_request.is_empty()) and Runner.target_entity(sessions[client],target),"Real charm target packet selects the native Ogre"):return
		fields=(await reply(client,"status")).split("|")
		if not check(fields[2]=="none" and int(fields[3])==target and fields[4]=="1","Native charm assigns Combatant and AI combat action"):return
		await click(client,snake)
		if not check(await until(func():return not sessions[client].target_request.is_empty()) and Runner.target_entity(sessions[client],other),"Second real target packet tests already-combating refusal"):return
		fields=(await reply(client,"status")).split("|")
		if not check(int(fields[3])==target,"Native charm preserves the existing combatant when already busy"):return
		fields=(await reply(client,"poison")).split("|")
		if not check(fields.size()==11 and int(fields[2])>0 and int(fields[2])<=32 and int(fields[3])==4 and fields[4]=="Immune" and int(fields[5])==4,"Native melee callback applies lethal poison and native immunity refuses lethal poisoning"):return
		if not check(absf(float(fields[6])-.5)<.00001 and fields[7]=="1" and fields[8]=="1" and fields[9]=="1" and int(fields[10])==100,"Original poison chance, charmability, allegiance getters and resistance retained"):return
		records.append({"client":client,"body":92,"native_summon":true,"actual_charm_packets":true,"no_familiar_refused":true,"invalid_item_refused":true,"combatant_assigned":true,"busy_charm_refused":true,"native_poison_level":int(fields[3]),"poison_callback_attempts":int(fields[2]),"lethal_immune":true,"native_traits_passed":true})
		await reply(client,"cleanup")
		if not check(await until(func():return owned.all(func(serial: int):return not sessions[0].entities.has(serial) and not sessions[1].entities.has(serial))),"Owned actors/familiar are removed on both clients"):return
	var sources: Dictionary={};var runtime: Dictionary={}
	for path in ["Projects/UOContent/Mobiles/Animals/Reptiles/SilverSerpent.cs","Projects/UOContent/Mobiles/BaseCreature.cs","Projects/UOContent/Mobiles/Familiars/DeathAdder.cs","Projects/UOContent/Mobiles/Familiars/BaseFamiliar.cs","Projects/UOContent/Spells/Necromancy/SummonFamiliar.cs","Projects/Server/Targeting/Target.cs"]:sources[path]=FileAccess.get_sha256("res://../Server/ModernUO/"+path)
	for path in ["GameSession.gd","ActionProtocol.gd","ActionRunner.gd"]:runtime[path]=FileAccess.get_sha256("res://Network/"+path)
	var output:="res://../outputs/creatures/silver_serpents";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output));FileAccess.open(output+"/behaviour.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":0,"records":records,"native_source_sha256":sources,"runtime_sha256":runtime,"fixture_sha256":FileAccess.get_sha256("res://../Server/HorseIntegrationFixtures/SilverSerpentBehaviourFixtures.cs"),"test_sha256":FileAccess.get_sha256("res://Network/SilverSerpentBehaviourLive.gd"),"scope":"Both actual disposable owners/world entry; real0x06 double-click and0x6c target packets reach native DeathAdder charm target. No-familiar/non-mobile/busy refusals and native combatant/AI-action assignment observed. Native Summon API/familiar table registration and temporary unblessing are explicit setup, not a completed Necromancy spell. AI/frozen actors prevent autonomous combat. Native OnGaveMeleeAttack callback/ApplyPoison APIs verify poison/immune paths, not actual weapon swing or probability rate. Allegiance getters do not certify faction/ethics gameplay. Production/saves excluded."}));print("SILVER NATIVE BEHAVIOUR: ",checks," checks / 0 failures / two actual network charm cases");quit()
