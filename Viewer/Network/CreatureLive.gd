extends SceneTree
const EagleVisual=preload("res://Presentation/EagleVisual.gd")
const Game=preload("res://Network/GameSession.gd")
const Registry=preload("res://Presentation/CreatureRegistry.gd")
var family:="bruins"
var prepared:=false
var accepted_pin:=""
var candidate_pin:=""
var sessions: Array=[]
var replies: Array=[[],[]]
var errors: Array=[]
var checks:=0
var records: Array=[]
var death_arenas: Array=[]
var death_items: Array=[]
var death_presenters: Array=[]
var death_events: Array=[{},{}]
class DeathArena extends Node3D:
	var avatars: Dictionary={}
class DeathItems extends Node:
	var nodes: Dictionary={}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--family="):family=arg.trim_prefix("--family=")
		if arg=="--prepared":prepared=true
	call_deferred("run")
func until(condition: Callable,seconds: float=15.) -> bool:
	var start:=Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-start<seconds*1000:
		if not errors.is_empty():return false
		await process_frame
	return condition.call()
func check(ok: bool,label: String) -> bool:
	checks+=1;print("CREATURE LIVE ","PASS: " if ok else "FAIL: ",label)
	if not ok:push_error(label+str(errors));quit(1)
	return ok
func reply(sex: int,command: String,prefix: String) -> String:
	replies[sex].clear();sessions[sex].send_command("[CreatureFixture "+command)
	var responded:=await until(func():return replies[sex].any(func(t: String):return t.begins_with(prefix) or t.begins_with("UCCREATURE|blocked|")))
	if not check(responded,"native fixture reply: "+command+"; received "+str(replies[sex])):return ""
	if not check(not replies[sex].any(func(t: String):return t.begins_with("UCCREATURE|blocked|")),"Native command accepted: "+command+"; received "+str(replies[sex])):return ""
	return replies[sex].filter(func(t: String):return t.begins_with(prefix))[-1]
func run() -> void:
	var accounts: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"))
	var candidates: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/live-candidates.json"))
	candidate_pin=FileAccess.get_sha256("res://../work/creatures/live-candidates.json")
	accepted_pin=FileAccess.get_sha256("res://local-art/creatures/accepted-index.json")
	if prepared:
		if not check(family in ["candidate_batch","mummies","solen_warriors","ice_elementals","solen_queens"],"Prepared trial uses an explicitly checked family"):return
		Registry.load_index()
		for candidate: Dictionary in candidates:
			var record: Dictionary=candidate.get("presentation",{})
			if not check(not record.is_empty() and record.status=="prepared" and str(record.kind)==str(candidate.kind) and int(candidate.body) in ([783,807] if family=="solen_queens" else [154,782,806,161]),"Exact checked candidate renderer is injected only into this process"):return
			Registry.entries[int(candidate.body)]=record
	for sex in 2:
		var session:=Game.new();root.add_child(session);sessions.append(session)
		var arena:=DeathArena.new();root.add_child(arena);death_arenas.append(arena)
		var item_map:=DeathItems.new();arena.add_child(item_map);death_items.append(item_map)
		var deaths:=preload("res://Presentation/CreatureDeaths.gd").new();arena.add_child(deaths);deaths.configure(arena,session,item_map);death_presenters.append(deaths)
		deaths.transition_started.connect(func(killed: int,corpse: int,visual: Node3D):death_events[sex][killed]={"corpse":corpse,"body":visual.native_body,"clip":visual.current_clip,"hue":visual.native_hue})
		session.failed.connect(func(reason: String):errors.append(reason))
		session.message_received.connect(func(text: String):
			if text.begins_with("UCCREATURE|"):replies[sex].append(text))
		session.connect_account(accounts[sex].username,accounts[sex].password,2594)
		if not check(await until(func():return session.phase=="characters"),"actual disposable native login"):return
		var slot:=-1;var city:=-1
		for character: Dictionary in session.characters:
			if character.name.is_empty():slot=int(character.slot);break
		for place: Dictionary in session.cities:
			if place.name=="Britain":city=int(place.index);break
		if not check(slot>=0 and city>=0,"native character slot and Britain start"):return
		session.create_character("Creature Woman" if sex else "Creature Man",slot,city,sex==1)
		if not check(await until(func():return session.phase=="world"),"actual ModernUO world entry"):return
	for sex in 2:
		var session: Node=sessions[sex];var observer: Node=sessions[1-sex]
		for candidate: Dictionary in candidates:
			var body:=int(candidate.body)
			var response:=await reply(sex,"prepare "+str(body)+(" "+str(candidate.native_class) if candidate.has("native_class") else ""),"UCCREATURE|prepared|")
			if response.is_empty():return
			var fields:=response.split("|");var serial:=int(fields[2]);var native_class:=str(fields[4])
			if native_class in ["SummonedAirElemental","SummonedFireElemental"] and not check(fields[8]=="summoned","Elemental summon is created through the native summoning API, not merely its class constructor"):return
			print("CREATURE NATIVE PREPARED ",response)
			var native_state:=str(fields[8])
			if candidate.has("native_class") and not check(native_class==str(candidate.native_class),"Requested native class is exercised even when several classes share a body"):return
			if candidate.get("movement_mode","")=="native_waterline" and not check("aquatic=1" in fields and "wet=1" in fields,"Native water-only actor starts on genuine swimmer-only water surface"):return
			if body==0xDF and not check(native_state=="shorn" and int(fields[9])==0,"native sheep carving reaches the shorn body and consumes available wool"):return
			if not check(int(fields[3])==body,"actual native constructor retains exact body"):return
			if not check(await until(func():return session.entities.has(serial) and observer.entities.has(serial)),"both clients receive native loose creature"):return
			if candidate.has("constructor_hues"):
				var expected_hue:=int(candidate.constructor_hues[native_class])
				if not check(int(session.entities[serial].hue)==expected_hue and int(observer.entities[serial].hue)==expected_hue,"Both clients receive the native constructor's original hue before any dye"):return
			var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=body;root.add_child(actor);actor.set_physics_process(false);actor.apply_server_appearance(session.entities[serial],[])
			death_arenas[sex].avatars[serial]=actor
			var peer_actor:=preload("res://Presentation/HumanAvatar.gd").new();peer_actor.initial_body=body;root.add_child(peer_actor);peer_actor.set_physics_process(false);peer_actor.apply_server_appearance(observer.entities[serial],[]);death_arenas[1-sex].avatars[serial]=peer_actor
			if not check(actor.horse_visual!=null and actor.horse_visual.native_body==body and actor.human_visual==null,"received body selects the actual validated creature avatar"):return
			for hue in [53,0x8000|53]:
				await reply(sex,"colour "+str(hue),"UCCREATURE|colour|")
				if not check(await until(func():return int(session.entities[serial].hue)==hue and int(observer.entities[serial].hue)==hue),"native full/partial hues reach both clients"):return
				actor.apply_server_appearance(session.entities[serial],[])
				if not check(actor.horse_visual.native_hue==hue,"actual creature retains exact raw hue bits"):return
			var rooted:=false
			for running in [false,true]:
				var start:=Time.get_ticks_msec()
				while Time.get_ticks_msec()-start<800:await process_frame
				var origin:=Vector2i(session.entities[serial].x,session.entities[serial].y)
				response=await reply(sex,"step "+("1" if running else "0"),"UCCREATURE|step|")
				if response.is_empty():return
				fields=response.split("|");var target:=Vector2i(int(fields[2]),int(fields[3]))
				if response.ends_with("|immobile"):
					rooted=true
					if not check(target==origin and Vector2i(observer.entities[serial].x,observer.entities[serial].y)==origin,"native rooted creature refuses movement on both clients"):return
					if not check(actor.horse_visual.current_clip=="Idle","rooted creature stays in its resting presentation"):return
					continue
				if not check(target!=origin and await until(func():return Vector2i(session.entities[serial].x,session.entities[serial].y)==target and Vector2i(observer.entities[serial].x,observer.entities[serial].y)==target),"actual native Move changes coordinates on both clients"):return
				if candidate.get("movement_mode","")=="native_waterline" and not check(response.ends_with("|wet=1"),"Native walk/run remains on genuine water after actual Mobile.Move"):return
				if not check(bool(session.entities[serial].running)==running and bool(observer.entities[serial].running)==running,"native walk/run flags replicate"):return
				actor.animate(true,0.,.1,6.8 if session.entities[serial].running else 1.8)
				var expected_gait: String=str(candidate.get("native_gait_expectations",{}).get("run" if running else "walk","Run" if running else "Walk"))
				if actor.horse_visual is EagleVisual and actor.horse_visual.current_clip=="TakeOff":
					if not check(actor.horse_visual.animator.assigned_animation=="TakeOff" and await until(func():return actor.horse_visual.current_clip==expected_gait),"Native eagle movement finishes real take-off into the declared gait"):return
				if not check(actor.horse_visual.current_clip==expected_gait,"received native gait drives its declared physical-speed replacement: expected "+expected_gait+", actual "+str(actor.horse_visual.current_clip)):return
			session.last_mobile_actions.erase(serial);observer.last_mobile_actions.erase(serial)
			await reply(sex,"hurt","UCCREATURE|hurt|")
			if not check(await until(func():return session.last_mobile_actions.has(serial) and observer.last_mobile_actions.has(serial)),"Native weapon hit-reaction method reaches both clients"):return
			var hurt: Dictionary=session.last_mobile_actions[serial]
			if not check(int(hurt.get("action",-1))==(7 if str(candidate.profile) in ["animal","sea"] else 10),"Pinned native hit group agrees with the body's server type"):return
			if not check(actor.receive_native_action(hurt) and actor.horse_visual.current_clip=="Hit" and not actor.horse_visual.dead,"Actual native classic hit packet plays a live reaction"):return
			var animal:=str(candidate.profile)=="animal";var sea:=str(candidate.profile)=="sea"
			var actions: Array=[5,9,3,11,-1] if animal else [5,6,7,3,4,12,-1,-2] if sea else [4,17,-1]
			if not animal and not sea:
				for extra in [[5,"Attack2"],[6,"Attack3"],[11,"Pillage"],[12,"Cast"],[-2,"Cast"],[19,"Fly"],[20,"Land"]]:
					if actor.horse_visual.animator.has_animation(extra[1]):actions.append(extra[0])
				for extra in [[-3,2],[-4,5],[-5,14]]:
					if actor.horse_visual.entry.get("new_action_categories",{}).has(str(extra[1])):actions.append(extra[0])
			if actor.horse_visual.animator.has_animation("Cast2"):
				for slot in [12,14]:
					if actor.horse_visual.entry.get("classic_action_categories",{}).get(str(slot),"")=="Cast2" and not actions.has(slot):actions.append(slot)
				if actor.horse_visual.entry.get("new_action_categories",{}).get("11","")=="Cast2" and not actions.has(-2):actions.append(-2)
			if actor.horse_visual.entry.get("classic_action_categories",{}).get("18","")=="Fidget2" and actor.horse_visual.animator.has_animation("Fidget2"):actions.append(18)
			var action_records: Array=[]
			for action in actions:
				session.last_mobile_actions.erase(serial);observer.last_mobile_actions.erase(serial)
				await reply(sex,"action "+str(action),"UCCREATURE|action|")
				if not check(await until(func():return session.last_mobile_actions.has(serial) and observer.last_mobile_actions.has(serial)),"native action reaches both clients"):return
				var received: Dictionary=session.last_mobile_actions[serial]
				if not check(actor.receive_native_action(received),"actual creature consumes native action"):return
				var expected:=str({5:"Attack",9:"Fidget",3:"Eat",11:"LieDown",-1:"Hit"}.get(action,"")) if animal else str({5:"Attack",6:"Attack2",7:"Hit",3:"Fidget",4:"Fidget2",12:"Attack",-1:"Hit",-2:"Attack"}.get(action,"")) if sea else str({4:"Attack",5:"Attack2",6:"Attack3",11:"Pillage",12:"Cast",-2:"Cast",-3:"Hit",-4:"Fidget",-5:"Pillage",17:"Fidget",-1:"Hit",19:"Fly",20:"Land"}.get(action,""))
				if action>=0:expected=str(actor.horse_visual.entry.get("classic_action_categories",{}).get(str(action),expected))
				if action in [-3,-4,-5]:
					var native_type: int={-3:2,-4:5,-5:14}[action]
					if not check(str(received.get("protocol",""))=="new" and int(received.get("type",-1))==native_type,"Requested native action type survives actual packet decoding"):return
				if str(received.get("protocol",""))=="new":expected=str(actor.horse_visual.entry.get("new_action_categories",{}).get(str(int(received.get("type",-1))),expected))
				if expected=="Attack2" and not actor.horse_visual.animator.has_animation("Attack2"):expected="Attack"
				if expected=="Fidget2" and not actor.horse_visual.animator.has_animation("Fidget2"):expected="Fidget"
				if not check(actor.horse_visual.current_clip==expected,"native action selects the intended category"):return
				var peer_request: Dictionary=observer.last_mobile_actions[serial]
				if not check(peer_actor.receive_native_action(peer_request) and peer_actor.horse_visual.current_clip==expected,"Observer actual avatar selects the same native category"):return
				action_records.append({"requested":action,"owner_packet":received.duplicate(true),"observer_packet":peer_request.duplicate(true),"owner_clip":actor.horse_visual.current_clip,"observer_clip":peer_actor.horse_visual.current_clip})
				if expected=="Fly" and not check(not actor.horse_visual.contact.enabled,"airborne source clip releases foot contact"):return
			if native_class=="Dolphin":
				var seen: Dictionary={}
				for attempt in 24:
					session.last_mobile_actions.erase(serial);observer.last_mobile_actions.erase(serial)
					await reply(sex,"breach","UCCREATURE|breach|")
					if not check(await until(func():return session.last_mobile_actions.has(serial) and observer.last_mobile_actions.has(serial)),"Native Dolphin.Jump reaches both clients"):return
					var request: Dictionary=session.last_mobile_actions[serial];var group:=int(request.action);seen[group]=true
					if not check(group in [3,4] and actor.receive_native_action(request) and actor.horse_visual.current_clip==("Jump" if group==3 else "Roll") and not actor.horse_visual.dead,"Native dolphin breach never becomes feeding, alert or death"):return
					if seen.size()==2:break
				if not check(seen.size()==2,"Both random native dolphin breach variants are exercised"):return
			var death_direction:=int(session.entities[serial].direction)
			response=await reply(sex,"kill","UCCREATURE|corpse|")
			if response.is_empty():return
			var corpse:=int(response.split("|")[2])
			var death_refused:=response.ends_with("|refused")
			if death_refused:
				if not check(not death_events[sex].has(serial) and not death_events[1-sex].has(serial),"native death refusal does not start a renderer death transition"):return
				if not check(corpse==0 and session.entities.has(serial) and observer.entities.has(serial),"native death refusal retains the living creature on both clients"):return
				if not check(not actor.horse_visual.dead,"native death refusal does not invent a client death pose"):return
				if native_class=="ServantOfSemidar" and not check(response.contains("|damageable=0|"),"native quest servant remains immune to damage"):return
			else:
				if not check(await until(func():return death_events[sex].has(serial) and death_events[1-sex].has(serial)),"native death packet starts the actual renderer transition on both clients"):return
				for client in [sex,1-sex]:
					var observed: Dictionary=death_events[client][serial]
					# Native summoned actors can announce a transient corpse in
					# 0xAF, then delete it before Kill() returns to the fixture.
					var corpse_matches: bool=int(observed.corpse)==corpse or response.ends_with("|suppressed") and not sessions[client].world_items.has(int(observed.corpse))
					if not check(int(observed.body)==body and corpse_matches and observed.clip=="Death","native renderer snapshot preserves body, corpse lifecycle and source death clip: "+str(observed)):return
			if not death_refused and corpse==0:
				if not check(response.ends_with("|suppressed") and await until(func():return not session.entities.has(serial) and not observer.entities.has(serial)),"native death removes the creature without inventing a suppressed corpse"):return
			elif not death_refused:
				if not check(await until(func():return session.world_items.has(corpse) and observer.world_items.has(corpse)),"actual native corpse replicates to both clients"):return
				if not check(int(session.world_items[corpse].get("amount",0))==body,"native corpse preserves original body"):return
				var presenter:=preload("res://Presentation/WorldItems.gd").new();presenter.session=session;root.add_child(presenter);var holder:=Node3D.new();root.add_child(holder)
				if not check(presenter._equine_corpse(holder,session.world_items[corpse],corpse),"native corpse selects the matching source death model"):return
				for frame in 2:await process_frame
				var dead_visual:=holder.get_node("CorpseVisual")
				if not check(is_equal_approx(dead_visual.rotation.y,PI-float(death_direction&7)*PI/4.),"native corpse keeps the victim's facing from the death packet"):return
				if not check(dead_visual.get_meta("static_cadaver",false) and dead_visual.get_meta("death_clip")=="Death" and dead_visual.find_children("*","AnimationPlayer",true,false).is_empty(),"native corpse holds the final source death pose as a static mesh"):return
				holder.queue_free();presenter.hint.queue_free();presenter.queue_free()
			for client in [sex,1-sex]:death_presenters[client].finish(serial);death_arenas[client].avatars.erase(serial);death_events[client].erase(serial)
			actor.queue_free();peer_actor.queue_free()
			await process_frame
			records.append({"actions":action_records,"female":sex==1,"body":body,"native_class":native_class,"native_state":native_state,"kind":candidate.kind,"constructor_hue":candidate.get("constructor_hues",{}).get(native_class,-1),"native_water":candidate.get("movement_mode","")=="native_waterline","corpse_suppressed":corpse==0 and not death_refused,"native_death_refused":death_refused,"movement":"Native AI refuses movement" if rooted else "Native Mobile.Move walk/run"})
			await reply(sex,"cleanup","UCCREATURE|cleaned")
	for session in sessions:session.close()
	if not check(accepted_pin==FileAccess.get_sha256("res://local-art/creatures/accepted-index.json") and candidate_pin==FileAccess.get_sha256("res://../work/creatures/live-candidates.json"),"Native trial leaves accepted routes and checked input list unchanged"):return
	var folder:="res://../outputs/creatures/"+family;DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var preparation_path:="res://local-art/creatures/"+family+"/preparation.json"
	var preparation_sha:=FileAccess.get_sha256(preparation_path) if not prepared and FileAccess.file_exists(preparation_path) else ""
	var file:=FileAccess.open(folder+"/live.json",FileAccess.WRITE);file.store_string(JSON.stringify({"test_sha256":FileAccess.get_sha256("res://Network/CreatureLive.gd"),"fixture_sha256":FileAccess.get_sha256("res://../Server/HorseIntegrationFixtures/CreatureFixtures.cs"),"preparation_sha256":preparation_sha,"candidate_sha256":candidate_pin,"accepted_index_sha256":accepted_pin,"prepared_trial":prepared,"checks":checks,"failures":0,"records":records,"scope":"Actual two-client world entry, native constructor bodies/hues, Mobile.Move walk/run, packets and corpse replication. Native AI is frozen for controlled sampling; flat-arena relocation is fixture setup. Not autonomous AI, taming or full gameplay certification. Production world and saves untouched."},"\t"));file.close()
	print("CREATURE NATIVE / ",family,": ",checks," checks / 0 failures");quit()
