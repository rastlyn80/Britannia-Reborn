extends "res://Network/FluidElementalBehaviourLive.gd"
## Actual constructor/callback/timer evidence; AI scheduling remains disabled.
func _initialize() -> void:
	create_timer(360.).timeout.connect(func():push_error("Native Juka behaviour deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> bool:
	checks+=1;print("JUKA NATIVE ","PASS: " if ok else "FAIL: ",label)
	if not ok:push_error(label+str(errors));quit(1)
	return ok
func reply(client: int,command: String) -> String:
	replies[client].clear();sessions[client].send_command("[JukaBehaviourFixture "+command)
	if not check(await until(func():return not replies[client].is_empty()),"Native Juka fixture reply: "+command):return ""
	return replies[client][-1]
func pins() -> Dictionary:
	var result: Dictionary={}
	for path in ["Viewer/Network/JukaBehaviourLive.gd","Viewer/Network/FluidElementalBehaviourLive.gd","Server/HorseIntegrationFixtures/JukaBehaviourFixtures.cs","Server/HorseIntegrationFixtures/FixtureAIControls.cs","Server/ModernUO/Projects/UOContent/Mobiles/Monsters/LBR/Jukas/JukaWarrior.cs","Server/ModernUO/Projects/UOContent/Mobiles/Monsters/LBR/Jukas/JukaMage.cs","Server/ModernUO/Projects/UOContent/Mobiles/Monsters/LBR/Jukas/JukaLord.cs","Server/ModernUO/Projects/UOContent/Mobiles/BaseCreature.cs","Server/ModernUO/Projects/UOContent/Spells/Base/Spell.cs","Server/ModernUO/Projects/UOContent/Spells/Fourth/Lightning.cs","Server/ModernUO/Projects/UOContent/Items/Misc/Corpses/Corpse.cs","Server/ModernUO/Projects/UOContent/Misc/Notoriety.cs","Server/ModernUO/Projects/Server/Mobiles/Mobile.cs"]:result[path]=FileAccess.get_sha256("res://../"+path)
	return result
func run() -> void:
	var input_pins:=pins();var records: Array=[]
	var accounts: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"))
	for client in 2:
		var session:=Game.new();root.add_child(session);sessions.append(session);session.failed.connect(func(reason: String):errors.append(reason));session.message_received.connect(func(text: String):
			if text.begins_with("UCJUKA|"):replies[client].append(text))
		session.connect_account(accounts[client].username,accounts[client].password,2594)
		if not check(await until(func():return session.phase=="characters"),"Disposable native Juka login"):return
		var chosen: Dictionary={}
		for character: Dictionary in session.characters:
			if not str(character.name).is_empty():chosen=character;break
		if not check(not chosen.is_empty(),"Existing disposable test character"):return
		session.select_character(int(chosen.slot),str(chosen.name))
		if not check(await until(func():return session.phase=="world"),"Actual disposable native world entry"):return
	for client in 2:
		for body: int in [764,765]:
			var record: Dictionary={"client":client,"body":body};var traits: PackedStringArray;var attempts:=0;var damage:=0;var interrupted: Array=[]
			while attempts<12:
				attempts+=1;traits=(await reply(client,"prepare "+str(body))).split("|")
				if not check(traits.size()==11 and traits[1]=="prepared" and int(traits[4])==body and traits[5]==("JukaWarrior" if body==764 else "JukaMage") and int(traits[10])==766,"Actual Juka constructors retain native bodies/classes, including support Lord766"):return
				var caster:=int(traits[2]);var target:=int(traits[3]);var lord:=int(traits[9])
				if not check(await until(func():return sessions[0].entities.has(caster) and sessions[1].entities.has(caster) and sessions[0].entities.has(target) and sessions[1].entities.has(target) and sessions[0].entities.has(lord) and sessions[1].entities.has(lord)),"Both clients receive native participants"):return
				if not check(traits[6]=="1" and traits[7]=="1" and traits[8]=="1","Native rummaging/murderer/meat declarations retained"):return
				if not check(await reply(client,"ai")=="UCJUKA|ai|1|1|1","All three native AI timers are actually stopped in active sector"):return
				if body==764:break
				if not check(await reply(client,"cast")=="UCJUKA|cast|1","Native Juka Lightning.Cast starts without forced skills/mana/deadlines"):return
				var result:="UCJUKA|waiting";var start:=Time.get_ticks_msec()
				while result.begins_with("UCJUKA|waiting") and Time.get_ticks_msec()-start<10000:
					await create_timer(.15).timeout;result=await reply(client,"target")
					if result=="UCJUKA|waiting|none":break
				if result=="UCJUKA|waiting|none":interrupted.append({"attempt":attempts,"state":result});continue
				var fields:=result.split("|")
				if not check(fields.size()==4 and fields[1]=="damage","Native spell timer installs actual target cursor"):return
				damage=int(fields[2])-int(fields[3])
				if damage>0:break
			if body==764:
				var proc:=false;var observations: Array=[]
				for attempt in 96:
					var melee: PackedStringArray=(await reply(client,"melee")).split("|")
					if not check(melee.size()==6 and melee[1]=="melee" and melee[4]=="0","Native Warrior callback starts from a non-frozen target"):return
					observations.append(Array(melee));proc=melee[5]=="1" or int(melee[3])<int(melee[2])
					if proc:break
				if not check(proc,"Unmodified Warrior random callback causes real stun/paralysis or critical damage"):return
				record.melee_observations=observations;record.native_special_observed=true
			else:
				if not check(damage>0,"Native Juka spell targeting causes actual damage"):return
				record.actual_spell_damage=damage;record.cast_attempts=attempts;record.interrupted_casts=interrupted
				var buff: PackedStringArray;var began:=Time.get_ticks_msec()
				while Time.get_ticks_msec()-began<12000:
					buff=(await reply(client,"buff")).split("|")
					if not check(buff.size()==11 and buff[1]=="buff" and buff[9]=="1" and buff[10]=="1","Native Lord buff keeps friend/combat-target preconditions"):return
					if int(buff[3])>int(buff[2]):break
					await create_timer(.2).timeout
				if not check(int(buff[3])==int(buff[2])+int(int(buff[2])*.75) and int(buff[5])==int(buff[4])+int(int(buff[4])*.5) and int(buff[7])==int(buff[6])+int(int(buff[6])*.5) and buff[8]=="0","Native OnThink deadline applies exact Lord75%hits/50%strength/dexterity buff and action lock"):return
				record.native_buff=Array(buff);var boosted:=Time.get_ticks_msec()
				while Time.get_ticks_msec()-boosted<35000:
					await create_timer(.3).timeout;buff=(await reply(client,"buff")).split("|")
					if buff.size()==11 and buff[8]=="1":break
				if not check(buff.size()==11 and buff[2]==buff[3] and buff[4]==buff[5] and buff[6]==buff[7] and buff[8]=="1" and Time.get_ticks_msec()-boosted>=19000,"Unmodified native20-second timer restores Lord stats and releases action lock"):return
				record.native_buff_expiry=Array(buff);record.observed_buff_seconds=float(Time.get_ticks_msec()-boosted)/1000.
			if not check(await reply(client,"ai")=="UCJUKA|ai|1|1|1","All AI timers remain stopped before native loot callback"):return
			var loot: PackedStringArray=(await reply(client,"rummage")).split("|")
			if loot.size()==3 and loot[1]=="no-backpack":
				if not check(loot[2]=="0","Native Rummage refuses a constructor without a backpack"):return
				record.no_backpack_refusal=true
			else:
				if not check(loot.size()==8 and loot[2]=="0" and loot[3]==loot[4] and int(loot[3])>0 and loot[5]=="0" and loot[6]=="1" and loot[7]=="0","Restricted facet retains native corpse loot-rights refusal"):return
				record.restricted_refusal=Array(loot)
				loot=(await reply(client,"rummage-unrestricted")).split("|");print("JUKA UNRESTRICTED LOOT: ",loot)
				if not check(loot.size()==8 and loot[2]=="1" and int(loot[3])>int(loot[4]) and loot[5]=="1" and loot[6]=="0" and int(loot[7])>0,"Unrestricted native Rummage transfers actual corpse loot through Lift/Drop"):return
				record.unrestricted_result=Array(loot)
			record.native_class=traits[5];record.support_lord_body=766;records.append(record);await reply(client,"cleanup")
	for session in sessions:session.close()
	if not check(input_pins==pins(),"Native/test/fixture sources unchanged throughout behaviour run"):return
	FileAccess.open("res://../outputs/creatures/juka/behaviour.json",FileAccess.WRITE).store_string(JSON.stringify({"ai_timer_stop_verified":true,"checks":checks,"failures":0,"records":records,"inputs_sha256":input_pins,"scope":"Actual native Juka constructors on both disposable owners. Native Warrior post-melee callback and random special; native Mage Lightning.Cast/timer/target/damage and OnThink Lord buff with natural20-second recovery. AI scheduling disabled; Lord combat target and facet travel are explicit fixture setup. No stats/skills/mana/deadlines assigned or random outcomes forced. Loot callbacks retain no-backpack/rights refusals; successful transfers use native Lift/Drop. Support Lord766 is not an accepted graphics route. Not autonomous fighting, actual weapon swings/proc-rate proof, buff particle rendering, automatic casting packets or full gameplay."}));print("JUKA NATIVE BEHAVIOUR: ",checks," checks /0 failures");quit()
