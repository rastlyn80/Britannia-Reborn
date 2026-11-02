extends SceneTree
## Native spell timers/targeting/damage and poison APIs; fixture AI is disabled.
const Game=preload("res://Network/GameSession.gd")
var sessions: Array=[]
var replies: Array=[[],[]]
var errors: Array=[]
var checks:=0
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Native fluid behaviour deadline");quit(1));call_deferred("run")
func until(condition: Callable) -> bool:
	var start:=Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-start<15000:
		if not errors.is_empty():return false
		await process_frame
	return condition.call()
func check(ok: bool,label: String) -> bool:
	checks+=1;print("FLUID NATIVE ","PASS: " if ok else "FAIL: ",label)
	if not ok:push_error(label+str(errors));quit(1)
	return ok
func reply(client: int,command: String) -> String:
	replies[client].clear();sessions[client].send_command("[FluidElementalFixture "+command)
	if not check(await until(func():return not replies[client].is_empty()),"Native fixture reply: "+command):return ""
	return replies[client][-1]
func run() -> void:
	var accounts: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"));var records: Array=[]
	for client in 2:
		var session:=Game.new();root.add_child(session);sessions.append(session);session.failed.connect(func(reason: String):errors.append(reason));session.message_received.connect(func(text: String):
			if text.begins_with("UCFLUID|"):replies[client].append(text))
		session.connect_account(accounts[client].username,accounts[client].password,2594)
		if not check(await until(func():return session.phase=="characters"),"Disposable native login"):return
		var chosen: Dictionary={}
		for character: Dictionary in session.characters:
			if not str(character.name).is_empty():chosen=character;break
		if not check(not chosen.is_empty(),"Existing disposable test character"):return
		session.select_character(int(chosen.slot),str(chosen.name))
		if not check(await until(func():return session.phase=="world"),"Actual native world entry"):return
	for client in 2:
		for body in [158,162]:
			var damage:=0;var attempts:=0;var caster:=0;var target:=0;var traits: PackedStringArray;var interruptions: Array=[]
			while damage<=0 and attempts<8:
				attempts+=1
				traits=(await reply(client,"prepare "+str(body))).split("|")
				if not check(traits.size()==9 and traits[1]=="prepared" and int(traits[4])==body,"Real native constructor and poison traits"):return
				caster=int(traits[2]);target=int(traits[3])
				if not check(await until(func():return sessions[0].entities.has(caster) and sessions[1].entities.has(caster) and sessions[0].entities.has(target) and sessions[1].entities.has(target)),"Both actual clients receive the native caster and target"):return
				if not check(int(traits[5])==1 and int(traits[6])==4 and abs(float(traits[7])-(.6 if body==158 else .75))<.00001 and int(traits[8])==(-1 if body==158 else 4),"Original bleed/lethal poison/chance/immunity declarations retained"):return
				if not check((await reply(client,"cast"))=="UCFLUID|cast|1","Native Lightning.Cast starts without forced skills, mana or deadlines"):return
				var result:="UCFLUID|waiting";var start:=Time.get_ticks_msec()
				while result.begins_with("UCFLUID|waiting") and Time.get_ticks_msec()-start<10000:
					await create_timer(.15).timeout;result=await reply(client,"target");print("FLUID CAST STATE ",result)
					if result.begins_with("UCFLUID|waiting|none|"):break
				if result.begins_with("UCFLUID|waiting|none|"):
					interruptions.append({"attempt":attempts,"state":result});continue
				var fields:=result.split("|")
				if not check(fields.size()==4 and fields[1]=="damage","Native cast timer installs a real targeting cursor"):return
				damage=int(fields[2])-int(fields[3])
			if not check(damage>0,"Actual native spell targeting damages the target"):return
			var poison:=(await reply(client,"poison")).split("|")
			if not check(poison.size()==6 and poison[2]=="Poisoned" and int(poison[3])==4,"Native lethal poison application affects the target"):return
			if not check(poison[4]==("Poisoned" if body==158 else "Immune") and int(poison[5])==(4 if body==158 else -1),"Actual native poison immunity differs between Acid and Poison"):return
			records.append({"client":client,"body":body,"caster":caster,"target":target,"actual_spell_damage":damage,"spell_attempts":attempts,"interrupted_attempts":interruptions,"target_poisoned":true,"native_traits_passed":true,"self_poison_result":poison[4]})
			await reply(client,"cleanup")
			if not check(await until(func():return not sessions[0].entities.has(caster) and not sessions[1].entities.has(caster) and not sessions[0].entities.has(target) and not sessions[1].entities.has(target)),"Native cleanup removes test actors on both clients"):return
	var sources: Dictionary={}
	for path in ["Projects/UOContent/Mobiles/Monsters/Elemental/Magic/AcidElemental.cs","Projects/UOContent/Mobiles/Monsters/Elemental/Magic/PoisonElemental.cs","Projects/UOContent/Mobiles/BaseCreature.cs","Projects/UOContent/Spells/Fourth/Lightning.cs","Projects/UOContent/Spells/Base/Spell.cs","Projects/UOContent/Spells/Base/SpellHelper.cs","Projects/Server/Targeting/Target.cs"]:sources[path]=FileAccess.get_sha256("res://../Server/ModernUO/"+path)
	var output:="res://../outputs/creatures/fluid_elementals";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output));FileAccess.open(output+"/behaviour.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":0,"records":records,"native_source_sha256":sources,"fixture_sha256":FileAccess.get_sha256("res://../Server/HorseIntegrationFixtures/FluidElementalBehaviourFixtures.cs"),"test_sha256":FileAccess.get_sha256("res://Network/FluidElementalBehaviourLive.gd"),"scope":"Both actual disposable clients/owners, unmodified native constructors, real Lightning.Cast timer/Target.Invoke/damage and ApplyPoison/immune paths. AI disabled and spell selection/targeting requested by the fixture; not autonomous AI/melee proc/loot/full gameplay. Pinned Spell.Cast hand movement excludes NPC monsters, so this does not claim an automatic NPC Cast2 packet. Explicit native classic/new Cast2 packets are covered separately by CreatureLive. Production/saves excluded."}));print("FLUID NATIVE BEHAVIOUR: ",checks," checks/0failures;4native spell/poison cases");quit()
