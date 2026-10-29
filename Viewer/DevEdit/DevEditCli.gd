extends SceneTree
# Command-line developer editor and Claude Code bridge.
# scripts/dev-edit.ps1 runs a list of commands and prints one JSON line each.
# scripts/dev-edit-bridge.ps1 (--serve) stays connected, by default as the
# assistant "Claude": every request/answer/proposal is appended to an outbox
# file as JSON, and command lines appended to an inbox file are executed. A
# Claude Code session watches the outbox and answers through the inbox.
# Commands: the shared grammar of DevEdit/DevEditCommands.gd, plus
#   status | list | asks | inspect X Y [RADIUS] | interpret TEXT | ask TEXT
#   answer ID TEXT | propose ID CMD && CMD … | resolve ID applied|declined
#   preview T STATE | clearpreview
#   wait SECONDS | quit (bridge)
const Session = preload("res://Network/GameSession.gd")
const State = preload("res://DevEdit/DevEditState.gd")
const Batch = preload("res://Presentation/DistrictBatch.gd")
const Commands = preload("res://DevEdit/DevEditCommands.gd")
const Intent = preload("res://DevEdit/DevEditIntent.gd")
var game: Node
var state := State.new()
var commands: Commands
var index: Dictionary = {}
var outbox := ""
const ACKNOWLEDGE := "Got it, I'm on it. A reply usually takes under a minute."
var resources: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func emit(data: Dictionary) -> void:
	var line := JSON.stringify(data)
	print("DEVEDIT ",line)
	if outbox != "":
		var file := FileAccess.open(outbox,FileAccess.READ_WRITE) if FileAccess.file_exists(outbox) else FileAccess.open(outbox,FileAccess.WRITE)
		file.seek_end()
		file.store_line(line)
		file.close()

func until(test: Callable, seconds: float) -> bool:
	var start := Time.get_ticks_msec()
	while not test.call() and Time.get_ticks_msec()-start < seconds*1000: await process_frame
	return test.call()

func send() -> Callable:
	return func(text: String) -> bool: return game.send_dev_edit(text)

func run() -> void:
	var account := "2"
	var lines: Array = []
	var inbox := ""
	var assistant := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--account="): account = arg.substr(10)
		if arg.begins_with("--commands="): lines.append_array(arg.substr(11).split(";",false))
		if arg.begins_with("--file="): lines.append_array(FileAccess.get_file_as_string(arg.substr(7)).split("\n",false))
		if arg.begins_with("--serve="): inbox = arg.substr(8)
		if arg.begins_with("--outbox="): outbox = arg.substr(9)
		if arg == "--assistant": assistant = true
	game = Session.new()
	root.add_child(game)
	game.dev_edit_received.connect(func(line: String): state.feed(line))
	commands = Commands.new(state,send(),records_in)
	var entered := [false]
	var failure := [""]
	game.failed.connect(func(reason: String): failure[0] = reason)
	game.entered.connect(func(_p: Dictionary): entered[0] = true)
	game.characters_received.connect(func(characters: Array,_cities: Array):
		for character in characters:
			if not character.name.is_empty():
				game.select_character(character.slot,character.name)
				return
		failure[0] = "account has no character")
	game.connect_account(OS.get_environment("UO_DEV_USER")+("2" if account == "2" else ""),OS.get_environment("UO_DEV_PASSWORD"))
	if not await until(func(): return entered[0] or failure[0] != "",40):
		emit({"error":"world entry timed out"});quit(1);return
	if not entered[0]:
		emit({"error":failure[0]});quit(1);return
	state.join(send(),assistant)
	if not await until(func(): return state.synced or state.denied != "",15) or state.denied != "":
		emit({"error":"session join failed","detail":state.denied});quit(1);return
	emit({"session":state.session,"editor":state.me,"revision":state.revision,"editors":state.editors.keys()})
	var code := 0
	for line in lines:
		var text := str(line).strip_edges()
		if text.is_empty() or text.begins_with("#"): continue
		if not await execute(text): code = 1
	if inbox != "": await serve(inbox)
	game.close()
	quit(code)

# Bridge loop: report conversation events, execute appended inbox lines.
func serve(inbox: String) -> void:
	# Every new ask gets an instant reply from the bridge itself, so the asker
	# knows it arrived while the assistant works on the real answer.
	var acknowledged := {}
	state.conversation_changed.connect(func(id: int):
		var ask: Dictionary = state.asks[id]
		if ask.status == "open" and ask.answers.is_empty() and ask.author != state.me and not acknowledged.has(id):
			acknowledged[id] = true
			state.answer(id,ACKNOWLEDGE,send())
		emit({"event":"conversation","id":id,"author":ask.author,"text":ask.text,"status":ask.status,"answers":ask.answers,"proposal":ask.proposal,"near":position_hint(ask.author)}))
	state.targets_changed.connect(func(targets: Array, seq: int, author: String, action: String):
		if action != "sync": emit({"event":"edit","revision":seq,"author":author,"action":action,"targets":targets.size()}))
	for id in state.asks: state.conversation_changed.emit(id)
	if not FileAccess.file_exists(inbox): FileAccess.open(inbox,FileAccess.WRITE).close()
	var offset := FileAccess.get_file_as_string(inbox).length()
	emit({"event":"serving","inbox":inbox,"editor":state.me})
	while game.phase == "world":
		await create_timer(0.25).timeout
		if not FileAccess.file_exists(inbox): break
		var content := FileAccess.get_file_as_string(inbox)
		if content.length() <= offset: continue
		var fresh := content.substr(offset)
		var complete := fresh.rfind("\n")
		if complete < 0: continue
		offset += complete+1
		for line in fresh.left(complete).split("\n",false):
			var text := line.strip_edges()
			if text == "quit": return
			if text != "": await execute(text)

# Where the asking editor stands (if visible to this client), to help an
# assistant turn "here" into coordinates.
func position_hint(author: String) -> Array:
	for serial in game.entities:
		var entity: Dictionary = game.entities[serial]
		if str(entity.get("name","")) == author: return [int(entity.x),int(entity.y),int(entity.z)]
	return []

func request(id: int, command: String) -> bool:
	if id == 0:
		emit({"command":command,"status":"not-sent","detail":"could not encode (check arguments, undo/redo availability)"})
		return false
	if id == -1:
		emit({"command":command,"status":"selected","targets":commands.selection})
		return true
	await until(func(): return state.requests.get(id,{}).get("status","pending") != "pending",15)
	var r: Dictionary = state.requests.get(id,{})
	var out := {"command":command,"status":r.get("status","timeout"),"detail":r.get("detail",""),"revision":int(r.get("seq",0))}
	if int(r.get("seq",0)) > 0:
		out.changes = state.targets.keys().filter(func(t: String): return state.revision_of(t) == int(r.seq)).map(func(t: String): return [t,state.state_of(t)])
	emit(out)
	return out.status == "applied"

func execute(text: String) -> bool:
	var a := text.split(" ",false)
	var verb := a[0].to_lower()
	var rest := text.substr(text.find(" ")+1).strip_edges() if " " in text else ""
	match verb:
		"status":
			emit({"command":text,"session":state.session,"revision":state.revision,"editors":state.editors.keys(),"locks":state.locks,"edited":state.targets.values().filter(func(t: Dictionary): return t.state != "").size(),"undo":state.undo_candidate(),"redo":state.redo_candidate()})
			return true
		"list":
			var edited := {}
			for t in state.targets:
				if state.state_of(t) != "": edited[t] = {"state":state.state_of(t),"revision":state.revision_of(t),"author":state.author_of(t)}
			emit({"command":text,"edited":edited})
			return true
		"asks":
			emit({"command":text,"asks":state.asks})
			return true
		"inspect":
			if a.size() < 3: return _bad(text)
			var r := int(a[3]) if a.size() > 3 else 0
			emit({"command":text,"statics":records_in(Rect2i(int(a[1])-r,int(a[2])-r,r*2+1,r*2+1))})
			return true
		"interpret":
			var hint := position_hint(state.me)
			var context := {"x":game.player.x,"y":game.player.y,"z":game.player.z,"facing":int(game.player.direction) & 7,"me":state.me}
			var plan := Intent.new().interpret(rest,context)
			if plan.understood: plan.scope = plan.lines.map(func(l: String): var p := commands.plan(l); return p.description if p.ok else "cannot run: "+str(p.error))
			emit({"command":text,"plan":plan,"at":hint})
			return true
		"ask":
			var ok := state.ask(rest,send())
			emit({"command":text,"status":"asked" if ok else "not-sent"})
			return ok
		"answer":
			if a.size() < 3 or not a[1].is_valid_int(): return _bad(text)
			var ok := state.answer(int(a[1]),rest.substr(rest.find(" ")+1),send())
			emit({"command":text,"status":"answered" if ok else "not-sent"})
			return ok
		"propose":
			if a.size() < 3 or not a[1].is_valid_int(): return _bad(text)
			var lines: Array = Array(rest.substr(rest.find(" ")+1).split("&&",false)).map(func(l: String): return l.strip_edges())
			var checked: Array = lines.map(func(l: String): var p := commands.plan(l); return p.description if p.ok else "INVALID: "+str(p.error))
			if checked.any(func(c: String): return c.begins_with("INVALID")):
				emit({"command":text,"status":"invalid","scope":checked})
				return false
			var ok := state.propose(int(a[1]),lines,send())
			emit({"command":text,"status":"proposed" if ok else "not-sent","scope":checked})
			return ok
		"resolve":
			if a.size() != 3 or not a[1].is_valid_int() or not a[2] in ["applied","declined"]: return _bad(text)
			var ok := state.resolve(int(a[1]),a[2],send())
			emit({"command":text,"status":a[2] if ok else "not-sent"})
			return ok
		"preview":
			if a.size() < 2: return _bad(text)
			state.preview(a[1],a[2] if a.size() > 2 else "",send())
			emit({"command":text,"status":"shared (not saved)"})
			return true
		"clearpreview":
			state.clear_preview(send())
			emit({"command":text,"status":"cleared"})
			return true
		"wait":
			await create_timer(float(a[1]) if a.size() > 1 else 1.0).timeout
			return true
	var plan := commands.plan(text)
	if not plan.ok:
		emit({"command":text,"status":"invalid","detail":plan.error})
		return false
	if plan.kind == "batch": emit({"command":text,"scope":plan.description,"targets":plan.targets.size()})
	return await request(commands.send(plan),text)

func _bad(text: String) -> bool:
	emit({"command":text,"status":"invalid","detail":"see the command list at the top of DevEdit/DevEditCli.gd"})
	return false

# Source records with live-edit eligibility from the local prepared bake.
func records_in(area: Rect2i) -> Array:
	var folder := ProjectSettings.globalize_path("res://../outputs/britain/prepared")
	if index.is_empty() and FileAccess.file_exists(folder.path_join("index.json")): index = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("index.json")))
	var found: Array = []
	for oy in range(floori(float(area.position.y)/64.0)*64,area.end.y,64):
		for ox in range(floori(float(area.position.x)/64.0)*64,area.end.x,64):
			var path := folder.path_join("near_%d_%d.res" % [ox,oy])
			if not FileAccess.file_exists(path): continue
			if not resources.has(path): resources[path] = load(path)
			var resource: Resource = resources[path]
			var counts := {}
			for tile in resource.decode().statics:
				var base := "%d:%d:%d:%d" % [tile.x,tile.y,tile.z,tile.id]
				var key := base+":"+str(int(counts.get(base,0)))
				counts[base] = int(counts.get(base,0))+1
				if not area.has_point(Vector2i(tile.x,tile.y)): continue
				var parts: PackedStringArray = str(resource.source_info.get(key,"||0")).split("|")
				var editable: bool = resource.source_map.has(key) and Batch.live_editable(parts[0],parts[1] if parts.size() > 1 else "")
				var detail: Dictionary = index.get("staticData",{}).get(str(int(tile.id)),{})
				var reason := "" if editable else ("joined architecture" if parts[0] in Batch.LIVE_EDIT_EXCLUDED else "not individually owned")
				found.append({"target":"s:"+key,"x":int(tile.x),"y":int(tile.y),"z":int(tile.z),"id":int(tile.id),"name":str(detail.get("name","")),"kind":parts[0],"editable":editable,"reason":reason,"overlay":state.state_of("s:"+key)})
	return found
