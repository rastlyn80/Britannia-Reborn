extends SceneTree
# Command-line developer editor (scripts/dev-edit.ps1). Joins the same
# server-authoritative session as the in-game panel, using the same command
# model, and prints one JSON line per command, so Claude Code (or a future
# conversational assistant) can act in a live session and read the result.
# Commands (separated by ';' in --commands or one per line in --file):
#   status | list | inspect X Y [RADIUS] | place ID X Y Z [YAW]
#   hide TARGET | restore TARGET | move TARGET X Y Z [YAW] | replace TARGET ID
#   brush X Y R DZ [SURFACE] | undo | redo | save NAME | load NAME
#   preview TARGET STATE | clearpreview | wait SECONDS
const Session = preload("res://Network/GameSession.gd")
const State = preload("res://DevEdit/DevEditState.gd")
const Batch = preload("res://Presentation/DistrictBatch.gd")
var game: Node
var state := State.new()
var index: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func emit(data: Dictionary) -> void:
	print("DEVEDIT ",JSON.stringify(data))

func until(test: Callable, seconds: float) -> bool:
	var start := Time.get_ticks_msec()
	while not test.call() and Time.get_ticks_msec()-start < seconds*1000: await process_frame
	return test.call()

func send() -> Callable:
	return func(text: String) -> bool: return game.send_dev_edit(text)

func run() -> void:
	var account := "2"
	var lines: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--account="): account = arg.substr(10)
		if arg.begins_with("--commands="): lines.append_array(arg.substr(11).split(";",false))
		if arg.begins_with("--file="): lines.append_array(FileAccess.get_file_as_string(arg.substr(7)).split("\n",false))
	game = Session.new()
	root.add_child(game)
	game.dev_edit_received.connect(func(line: String): state.feed(line))
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
	state.join(send())
	if not await until(func(): return state.synced or state.denied != "",15) or state.denied != "":
		emit({"error":"session join failed","detail":state.denied});quit(1);return
	emit({"session":state.session,"editor":state.me,"revision":state.revision,"editors":state.editors.keys()})
	var code := 0
	for line in lines:
		var text := str(line).strip_edges()
		if text.is_empty() or text.begins_with("#"): continue
		if not await execute(text): code = 1
	game.close()
	quit(code)

func number(text: String) -> bool: return text.is_valid_float()

func request(id: int, command: String) -> bool:
	if id == 0:
		emit({"command":command,"status":"not-sent","detail":"could not encode (check arguments, undo/redo availability)"})
		return false
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
		"inspect":
			if a.size() < 3: return _bad(text)
			emit({"command":text,"statics":inspect(int(a[1]),int(a[2]),int(a[3]) if a.size() > 3 else 0)})
			return true
		"place":
			if a.size() < 5: return _bad(text)
			return await request(state.place(int(a[1]),float(a[2]),float(a[3]),int(a[4]),int(a[5]) if a.size() > 5 else 0,send()),text)
		"hide":
			if a.size() != 2: return _bad(text)
			return await request(state.set_state(a[1],"hide","hide",send()),text)
		"restore":
			if a.size() != 2: return _bad(text)
			return await request(state.set_state(a[1],"","restore",send()),text)
		"move", "replace":
			if a.size() < 3: return _bad(text)
			var target: String = a[1]
			var place := State.placement(state.state_of(target))
			var identity := State.static_identity(target)
			if place.is_empty() and not identity.is_empty(): place = {"x":float(identity.x),"y":float(identity.y),"z":int(identity.z),"yaw":0,"id":int(identity.id)}
			if place.is_empty(): return _bad(text)
			if verb == "move":
				if a.size() < 5: return _bad(text)
				place.x = float(a[2]);place.y = float(a[3]);place.z = int(a[4])
				if a.size() > 5: place.yaw = int(a[5])
			else: place.id = int(a[2])
			var encoded := "a:%d:%s:%s:%d:%d" % [place.id,State.number(place.x),State.number(place.y),place.z,posmod(int(place.yaw),360)] if target.begins_with("p:") else "m:%s:%s:%d:%d:%d" % [State.number(place.x),State.number(place.y),place.z,posmod(int(place.yaw),360),place.id]
			return await request(state.set_state(target,encoded,verb,send()),text)
		"brush":
			if a.size() < 5: return _bad(text)
			return await request(state.brush(int(a[1]),int(a[2]),int(a[3]),int(a[4]),a[5] if a.size() > 5 else "-",send()),text)
		"undo": return await request(state.undo(send()),text)
		"redo": return await request(state.redo(send()),text)
		"save":
			if a.size() != 2: return _bad(text)
			return await request(state.save(a[1],send()),text)
		"load":
			if a.size() != 2: return _bad(text)
			return await request(state.load_set(a[1],send()),text)
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
	return _bad(text)

func _bad(text: String) -> bool:
	emit({"command":text,"status":"invalid","detail":"see the command list at the top of DevEdit/DevEditCli.gd"})
	return false

# Static identities near a cell from the local prepared bake, with their
# live-edit eligibility. Requires the owned local data; prints nothing else.
func inspect(x: int, y: int, radius: int) -> Array:
	var folder := ProjectSettings.globalize_path("res://../outputs/britain/prepared")
	if index.is_empty() and FileAccess.file_exists(folder.path_join("index.json")): index = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("index.json")))
	var found: Array = []
	var seen := {}
	for dy in range(-radius,radius+1):
		for dx in range(-radius,radius+1):
			var at := Vector2i(floori(float(x+dx)/64.0)*64,floori(float(y+dy)/64.0)*64)
			if seen.has(at): continue
			seen[at] = true
			var path := folder.path_join("near_%d_%d.res" % [at.x,at.y])
			if not FileAccess.file_exists(path): continue
			var resource: Resource = load(path)
			var counts := {}
			for tile in resource.decode().statics:
				var base := "%d:%d:%d:%d" % [tile.x,tile.y,tile.z,tile.id]
				var key := base+":"+str(int(counts.get(base,0)))
				counts[base] = int(counts.get(base,0))+1
				if absi(int(tile.x)-x) > radius or absi(int(tile.y)-y) > radius: continue
				var parts: PackedStringArray = str(resource.source_info.get(key,"||0")).split("|")
				var name := str(index.get("staticData",{}).get(str(int(tile.id)),{}).get("name",""))
				found.append({"target":"s:"+key,"name":name,"kind":parts[0],"editable":resource.source_map.has(key) and Batch.live_editable(parts[0],parts[1] if parts.size() > 1 else ""),"overlay":state.state_of("s:"+key)})
	return found
