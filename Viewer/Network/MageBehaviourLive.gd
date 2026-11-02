extends "res://Network/FluidElementalBehaviourLive.gd"
## Native casting and corpse Lift/Drop callbacks; no autonomous AI claim.
func _initialize() -> void:
	create_timer(240.).timeout.connect(func():push_error("Native mage behaviour deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> bool:
	checks+=1;print("MAGE NATIVE ","PASS: " if ok else "FAIL: ",label)
	if not ok:push_error(label+str(errors));quit(1)
	return ok
func native_sources() -> Dictionary:
	var sources: Dictionary={}
	for path in ["Projects/UOContent/Mobiles/Monsters/Humanoid/Magic/EvilMage.cs","Projects/UOContent/Mobiles/Monsters/Humanoid/Magic/EvilMageLord.cs","Projects/UOContent/Mobiles/BaseCreature.cs","Projects/UOContent/Spells/Base/Spell.cs","Projects/UOContent/Spells/Fourth/Lightning.cs","Projects/UOContent/Items/Misc/Corpses/Corpse.cs","Projects/UOContent/Misc/Notoriety.cs","Projects/Server/Mobiles/Mobile.cs","Projects/Server/Items/Container.cs"]:sources[path]=FileAccess.get_sha256("res://../Server/ModernUO/"+path)
	return sources
func reply(client: int,command: String) -> String:
	replies[client].clear();sessions[client].send_command("[MageBehaviourFixture "+command)
	if not check(await until(func():return not replies[client].is_empty()),"Native mage fixture reply: "+command):return ""
	return replies[client][-1]
func run() -> void:
	var sources:=native_sources();var test_pin:=FileAccess.get_sha256("res://Network/MageBehaviourLive.gd");var base_pin:=FileAccess.get_sha256("res://Network/FluidElementalBehaviourLive.gd");var fixture_pin:=FileAccess.get_sha256("res://../Server/HorseIntegrationFixtures/MageBehaviourFixtures.cs")
	var accounts: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"));var records: Array=[]
	for client in 2:
		var session:=Game.new();root.add_child(session);sessions.append(session);session.failed.connect(func(reason: String):errors.append(reason));session.message_received.connect(func(text: String):
			if text.begins_with("UCMAGE|"):replies[client].append(text))
		session.connect_account(accounts[client].username,accounts[client].password,2594)
		if not check(await until(func():return session.phase=="characters"),"Disposable native mage login"):return
		var chosen: Dictionary={}
		for character: Dictionary in session.characters:
			if not str(character.name).is_empty():chosen=character;break
		if not check(not chosen.is_empty(),"Existing disposable test character"):return
		session.select_character(int(chosen.slot),str(chosen.name))
		if not check(await until(func():return session.phase=="world"),"Actual disposable native world entry"):return
	for client in 2:
		for body: int in [124,125,126]:
			var damage:=0;var attempts:=0;var interruptions: Array=[];var traits: PackedStringArray
			while damage<=0 and attempts<12:
				attempts+=1;traits=(await reply(client,"prepare "+str(body))).split("|")
				if not check(traits.size()==9 and traits[1]=="prepared" and int(traits[4])==body and traits[8]==("EvilMage" if body==124 else "EvilMageLord"),"Unmodified native mage constructor retains body/class"):return
				var caster:=int(traits[2]);var target:=int(traits[3])
				if not check(await until(func():return sessions[0].entities.has(caster) and sessions[1].entities.has(caster) and sessions[0].entities.has(target) and sessions[1].entities.has(target)),"Both clients receive actual native caster/target"):return
				if not check(traits[5]=="1" and traits[6]=="1" and traits[7]=="1","Native rummaging/murderer/meat getters retain declarations"):return
				if not check(await reply(client,"cast")=="UCMAGE|cast|1","Native Lightning.Cast starts without forced skills/mana/deadlines"):return
				var result:="UCMAGE|waiting";var start:=Time.get_ticks_msec()
				while result.begins_with("UCMAGE|waiting") and Time.get_ticks_msec()-start<10000:
					await create_timer(.15).timeout;result=await reply(client,"target")
					if result=="UCMAGE|waiting|none":break
				if result=="UCMAGE|waiting|none":interruptions.append({"attempt":attempts,"state":result});continue
				var fields:=result.split("|")
				if not check(fields.size()==4 and fields[1]=="damage","Native cast timer installs a target cursor"):return
				damage=int(fields[2])-int(fields[3])
			if not check(damage>0,"Native spell target dispatch produces actual damage"):return
			var rummage: PackedStringArray=(await reply(client,"rummage")).split("|")
			print("MAGE NATIVE RUMMAGE: ",rummage)
			if not check(rummage.size()==9 and rummage[1]=="rummage","Native rummage includes facet/loot-permission evidence"):return
			var refused:=rummage.duplicate()
			if not check(rummage[2]=="0" and int(rummage[3])>0 and rummage[3]==rummage[4] and rummage[5]=="0" and rummage[6]=="1" and rummage[7]=="0","Restricted facet refuses corpse loot without native loot rights"):return
			rummage=(await reply(client,"rummage-unrestricted")).split("|");print("MAGE NATIVE UNRESTRICTED RUMMAGE: ",rummage)
			if not check(rummage.size()==9 and rummage[2]=="1" and int(rummage[3])>int(rummage[4]) and rummage[5]=="1" and rummage[6]=="0" and int(rummage[7])>0,"Unrestricted facet native Rummage uses real Lift/Drop and acquires loot"):return
			records.append({"client":client,"body":body,"native_class":traits[8],"native_traits_passed":true,"actual_spell_damage":damage,"cast_attempts":attempts,"interrupted_casts":interruptions,"restricted_refusal":Array(refused),"native_rummage":true,"unrestricted_result":Array(rummage),"corpse_before":int(rummage[3]),"corpse_after":int(rummage[4]),"native_backpack_acquired":true})
			await reply(client,"cleanup")
	for session in sessions:session.close()
	if not check(sources==native_sources() and test_pin==FileAccess.get_sha256("res://Network/MageBehaviourLive.gd") and base_pin==FileAccess.get_sha256("res://Network/FluidElementalBehaviourLive.gd") and fixture_pin==FileAccess.get_sha256("res://../Server/HorseIntegrationFixtures/MageBehaviourFixtures.cs"),"Exact native/test/fixture inputs stayed unchanged throughout behaviour test"):return
	FileAccess.open("res://../outputs/creatures/mages/behaviour.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":0,"records":records,"test_sha256":test_pin,"base_test_sha256":base_pin,"fixture_sha256":fixture_pin,"native_source_sha256":sources,"scope":"Actual native constructors on both disposable owners, Lightning.Cast/timer/target/damage, native Ogre.Kill corpse, restricted-facet loot refusal and unrestricted-facet native Rummage Lift/Drop/item acquisition. Facet transfer is explicit fixture setup. AI frozen; not autonomous fighting, rummage scheduling, automatic casting/Pillage animation packets or full gameplay. No native stats, mana, skills or deadlines assigned."}));print("MAGE NATIVE BEHAVIOUR: ",checks," checks / 0 failures");quit()
