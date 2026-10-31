extends SceneTree
const Game=preload("res://Network/GameSession.gd")
var family:="bruins"
var sessions: Array=[]
var replies: Array=[[],[]]
var errors: Array=[]
var checks:=0
var records: Array=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--family="):family=arg.trim_prefix("--family=")
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
	if not check(await until(func():return replies[sex].any(func(t: String):return t.begins_with(prefix))),"native fixture reply: "+command):return ""
	return replies[sex].filter(func(t: String):return t.begins_with(prefix))[-1]
func run() -> void:
	var accounts: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"))
	var candidates: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/live-candidates.json"))
	for sex in 2:
		var session:=Game.new();root.add_child(session);sessions.append(session)
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
			var response:=await reply(sex,"prepare "+str(body),"UCCREATURE|prepared|")
			if response.is_empty():return
			var fields:=response.split("|");var serial:=int(fields[2]);var native_class:=str(fields[4])
			var native_state:=str(fields[8])
			if body==0xDF and not check(native_state=="shorn" and int(fields[9])==0,"native sheep carving reaches the shorn body and consumes available wool"):return
			if not check(int(fields[3])==body,"actual native constructor retains exact body"):return
			if not check(await until(func():return session.entities.has(serial) and observer.entities.has(serial)),"both clients receive native loose creature"):return
			var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=body;root.add_child(actor);actor.set_physics_process(false);actor.apply_server_appearance(session.entities[serial],[])
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
				if not check(bool(session.entities[serial].running)==running and bool(observer.entities[serial].running)==running,"native walk/run flags replicate"):return
				actor.animate(true,0.,.1,6.8 if session.entities[serial].running else 1.8)
				if not check(actor.horse_visual.current_clip==("Run" if running else "Walk"),"received gait drives matching source replacement"):return
			var animal:=str(candidate.profile) in ["animal","sea"]
			var actions: Array=[5,9,3,11,-1] if animal else [4,17,-1]
			if not animal:
				for extra in [[5,"Attack2"],[6,"Attack3"],[12,"Cast"],[-2,"Cast"],[19,"Fly"],[20,"Land"]]:
					if actor.horse_visual.animator.has_animation(extra[1]):actions.append(extra[0])
			for action in actions:
				session.last_mobile_actions.erase(serial);observer.last_mobile_actions.erase(serial)
				await reply(sex,"action "+str(action),"UCCREATURE|action|")
				if not check(await until(func():return session.last_mobile_actions.has(serial) and observer.last_mobile_actions.has(serial)),"native action reaches both clients"):return
				if not check(actor.receive_native_action(session.last_mobile_actions[serial]),"actual creature consumes native action"):return
				var expected:=str({5:"Attack",9:"Fidget",3:"Eat",11:"LieDown",-1:"Hit"}.get(action,"")) if animal else str({4:"Attack",5:"Attack2",6:"Attack3",12:"Cast",-2:"Cast",17:"Fidget",-1:"Hit",19:"Fly",20:"Land"}.get(action,""))
				if not check(actor.horse_visual.current_clip==expected,"native action selects the intended category"):return
				if expected=="Fly" and not check(not actor.horse_visual.contact.enabled,"airborne source clip releases foot contact"):return
			response=await reply(sex,"kill","UCCREATURE|corpse|")
			if response.is_empty():return
			var corpse:=int(response.split("|")[2])
			var death_refused:=response.ends_with("|refused")
			if death_refused:
				if not check(corpse==0 and session.entities.has(serial) and observer.entities.has(serial),"native death refusal retains the living creature on both clients"):return
				if not check(not actor.horse_visual.dead,"native death refusal does not invent a client death pose"):return
				if native_class=="ServantOfSemidar" and not check(response.contains("|damageable=0|"),"native quest servant remains immune to damage"):return
			elif corpse==0:
				if not check(response.ends_with("|suppressed") and await until(func():return not session.entities.has(serial) and not observer.entities.has(serial)),"native death removes the creature without inventing a suppressed corpse"):return
			else:
				if not check(await until(func():return session.world_items.has(corpse) and observer.world_items.has(corpse)),"actual native corpse replicates to both clients"):return
				if not check(int(session.world_items[corpse].get("amount",0))==body,"native corpse preserves original body"):return
				var presenter:=preload("res://Presentation/WorldItems.gd").new();root.add_child(presenter);var holder:=Node3D.new();root.add_child(holder)
				if not check(presenter._equine_corpse(holder,session.world_items[corpse],corpse),"native corpse selects the matching source death model"):return
				for frame in 2:await process_frame
				var dead_visual:=holder.get_node("CorpseVisual")
				if not check(dead_visual.dead and dead_visual.current_clip=="Death" and not dead_visual.animator.is_playing(),"native corpse holds the final source death pose"):return
				holder.queue_free();presenter.hint.queue_free();presenter.queue_free()
			actor.queue_free()
			await process_frame
			records.append({"female":sex==1,"body":body,"native_class":native_class,"native_state":native_state,"kind":candidate.kind,"corpse_suppressed":corpse==0 and not death_refused,"native_death_refused":death_refused,"movement":"Native AI refuses movement" if rooted else "Native Mobile.Move walk/run"})
			await reply(sex,"cleanup","UCCREATURE|cleaned")
	for session in sessions:session.close()
	var folder:="res://../outputs/creatures/"+family;DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var file:=FileAccess.open(folder+"/live.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":0,"records":records,"scope":"Actual two-client world entry, native constructor bodies/hues, Mobile.Move walk/run, packets and corpse replication. Native AI is frozen for controlled sampling; flat-arena relocation is fixture setup. Not autonomous AI, taming or full gameplay certification. Production world and saves untouched."},"\t"));file.close()
	print("CREATURE NATIVE / ",family,": ",checks," checks / 0 failures");quit()
