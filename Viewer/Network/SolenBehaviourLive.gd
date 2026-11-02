extends SceneTree
## Observe real native friendship/enmity and direct/owned-pet damage callbacks.
const Game=preload("res://Network/GameSession.gd")
var sessions: Array=[]
var replies: Array=[[],[]]
var errors: Array=[]
var checks:=0
func _initialize() -> void:
	create_timer(120.).timeout.connect(func():push_error("Native Solen behaviour deadline");quit(1));call_deferred("run")
func until(condition: Callable) -> bool:
	var start:=Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-start<15000:
		if not errors.is_empty():return false
		await process_frame
	return condition.call()
func check(ok: bool,label: String) -> bool:
	checks+=1;print("SOLEN NATIVE ","PASS: " if ok else "FAIL: ",label)
	if not ok:push_error(label+str(errors));quit(1)
	return ok
func run() -> void:
	var accounts: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"));var states: Array=[];var damage: Array=[]
	for client in 2:
		var session:=Game.new();root.add_child(session);sessions.append(session);session.failed.connect(func(reason: String):errors.append(reason));session.message_received.connect(func(text: String):
			if text.begins_with("UCSOLEN|"):replies[client].append(text))
		session.connect_account(accounts[client].username,accounts[client].password,2594)
		if not check(await until(func():return session.phase=="characters"),"Disposable native login"):return
		var chosen: Dictionary={}
		for character: Dictionary in session.characters:
			if not str(character.name).is_empty():chosen=character;break
		if not check(not chosen.is_empty(),"Existing disposable test character"):return
		session.select_character(int(chosen.slot),str(chosen.name))
		if not check(await until(func():return session.phase=="world"),"Actual native world entry for both owners"):return
	for client in 2:
		sessions[client].send_command("[SolenBehaviourFixture")
		if not check(await until(func():return replies[client].any(func(text: String):return text.begins_with("UCSOLEN|done|"))),"Native Solen helper and damage fixture completed"):return
		var state_rows: Array=replies[client].filter(func(text: String):return text.begins_with("UCSOLEN|state|"));var damage_rows: Array=replies[client].filter(func(text: String):return text.begins_with("UCSOLEN|damage|"));var done: PackedStringArray=replies[client].filter(func(text: String):return text.begins_with("UCSOLEN|done|"))[-1].split("|")
		if not check(int(done[2])==781 and int(done[3])==805 and int(done[4])==0x453 and int(done[5])==1,"Original native red/black worker bodies, black hue and actual controlled-pet master retained"):return
		if not check(state_rows.size()==3 and damage_rows.size()==4,"All friendship states and direct/pet damage witnesses present"):return
		for text: String in state_rows:
			var fields:=text.split("|");var state:=fields[2];var red:=1 if state=="Red" else 0;var black:=1 if state=="Black" else 0;var expected: Array=[red,black,1-red,1-black,red,black,1-red,1-black]
			for i in 8:
				if not check(int(fields[i+3])==int(expected[i]),"Native "+state+" friendship/enmity matches for the owner and its actual controlled pet"):return
			states.append({"client":client,"friendship":state,"native_values":Array(fields).slice(3)})
		for text: String in damage_rows:
			var fields:=text.split("|")
			if not check(fields[4]=="1" and fields[5]=="1" and fields[6]=="1","Actual native "+fields[3]+" damage reduces "+fields[2]+" worker health, revokes its owner's friendship and restores enmity"):return
			damage.append({"client":client,"colour":fields[2],"from":fields[3],"native_health_reduced":true,"friendship_revoked":true,"enmity_restored":true})
	var sources: Dictionary={}
	for path in ["Projects/UOContent/Mobiles/Monsters/Ants/SolenHelper.cs","Projects/UOContent/Mobiles/Monsters/Ants/RedSolenWorker.cs","Projects/UOContent/Mobiles/Monsters/Ants/BlackSolenWorker.cs"]:sources[path]=FileAccess.get_sha256("res://../Server/ModernUO/"+path)
	var output:="res://../outputs/creatures/solen_workers";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output));FileAccess.open(output+"/friendship.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":0,"states":states,"damage":damage,"native_source_sha256":sources,"fixture_sha256":FileAccess.get_sha256("res://../Server/HorseIntegrationFixtures/SolenBehaviourFixtures.cs"),"test_sha256":FileAccess.get_sha256("res://Network/SolenBehaviourLive.gd"),"scope":"Actual two-client native world entry; on both disposable owners, native Solen friendship helpers and worker IsEnemy evaluate all3states for players/actual controlled pets. Native Damage dispatch revokes matching friendship for direct/player-owned-pet attacks. Friendship assignment is fixture setup, not quest completion. AI disabled for controlled observation; not autonomous combat, quest, persistence or full native gameplay certification. Production/saves excluded."}));print("SOLEN NATIVE BEHAVIOUR: ",checks," checks/0failures;6friendship/8damage cases");quit()
