extends SceneTree
# Live two-client developer edit session against the real local ModernUO
# server: two independent GameSession connections (two development accounts,
# two characters) join one server-authoritative session. Checks shared
# accepted edits and previews, reservations, stale-revision conflicts, undo
# that would overwrite another editor's newer change, invalid commands,
# reconnect/late-join snapshots, a cross-district terrain brush and saved edit
# sets. --mark leaves one marker edit for the restart check; --verify-marker
# checks it after a server restart and removes it. Measurements are printed.
const Session = preload("res://Network/GameSession.gd")
const State = preload("res://DevEdit/DevEditState.gd")
var clients: Array = []
var states: Array = []
var passed := 0
var failed := 0
var log_lines: Array = []
var stats := {}

func check(condition: bool, name: String) -> void:
	if condition:
		passed += 1
		print("DEV EDIT LIVE PASS: ",name)
	else:
		failed += 1
		print("DEV EDIT LIVE FAIL: ",name)

func now_ms() -> float:
	return Time.get_unix_time_from_system()*1000.0

func _initialize() -> void: call_deferred("run")

func connect_client(index: int) -> bool:
	var client := Session.new()
	var state := State.new()
	root.add_child(client)
	client.dev_edit_received.connect(func(line: String):
		if "--trace" in OS.get_cmdline_user_args(): print("C%d < %s" % [index,line])
		state.feed(line))
	var entered := [false]
	var failure := [""]
	client.failed.connect(func(reason: String): failure[0] = reason)
	client.characters_received.connect(func(characters: Array,cities: Array):
		for character in characters:
			if not character.name.is_empty():
				client.select_character(character.slot,character.name)
				return
		for city in cities:
			if city.name == "Britain":
				client.create_character("Britain Companion",0,city.index)
				return)
	client.entered.connect(func(_position: Dictionary): entered[0] = true)
	var user := OS.get_environment("UO_DEV_USER")+("2" if index == 1 else "")
	client.connect_account(user,OS.get_environment("UO_DEV_PASSWORD"))
	var deadline := Time.get_ticks_msec()+30000
	while not entered[0] and failure[0].is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	if not entered[0]:
		push_error("Client %d did not enter: %s" % [index,failure[0]])
		return false
	if index < clients.size():
		clients[index] = client
		states[index] = state
	else:
		clients.append(client)
		states.append(state)
	return true

func send(index: int) -> Callable:
	return func(text: String) -> bool: return clients[index].send_dev_edit(text)

func until(condition: Callable, timeout_ms: int = 8000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_ms
	while not condition.call() and Time.get_ticks_msec() < deadline: await process_frame
	return condition.call()

func join(index: int) -> bool:
	states[index].synced = false
	states[index].join(send(index))
	return await until(func(): return states[index].synced or states[index].denied != "")

func request_done(index: int, id: int) -> bool:
	return await until(func(): return id > 0 and states[index].requests.has(id) and states[index].requests[id].status != "pending")

func status(index: int, id: int) -> String:
	return str(states[index].requests.get(id,{}).get("status","unsent"))

func run() -> void:
	var mode := "full"
	for arg in OS.get_cmdline_user_args():
		if arg == "--verify-marker": mode = "verify"
	if not await connect_client(0): quit(1);return
	if mode == "verify":
		await verify_marker()
	else:
		if not await connect_client(1): quit(1);return
		await full()
	for client in clients: client.close()
	print("DEV EDIT LIVE: %d passed, %d failed" % [passed,failed])
	print("DEV EDIT LIVE MEASURE: ",JSON.stringify(stats))
	quit(1 if failed > 0 else 0)

func marker_path() -> String:
	return ProjectSettings.globalize_path("res://../outputs/validation/dev-edit-marker.json")

func full() -> void:
	var a: State = states[0]
	var b: State = states[1]
	check(await join(0) and a.denied == "","editor A authorized and synced (%s)" % a.denied)
	check(await join(1) and b.denied == "","editor B authorized and synced")
	check(a.me != b.me and a.session == b.session and a.revision == b.revision,"two distinct editors, one session at revision %d" % a.revision)
	var start := a.revision
	# Shared accepted placement, with cross-client latency on one machine.
	var sent_at := now_ms()
	var placed := a.place(3144,1601.5,1592,20,30,send(0))
	check(await request_done(0,placed) and status(0,placed) == "applied","A places an approved asset")
	var seq: int = a.requests[placed].seq
	var target := ""
	for t in a.targets:
		if a.revision_of(t) == seq: target = t
	check(await until(func(): return b.state_of(target) == a.state_of(target) and target != ""),"B receives A's placement %s without restart" % target)
	stats.place_round_trip_ms = now_ms()-sent_at
	check(b.author_of(target) == a.me and b.revision_of(target) == seq,"attribution and revision replicated")
	# Shared preview, then cleared.
	a.preview(target,"a:3144:1602:1592:20:30",send(0))
	check(await until(func(): return b.previews.get(a.me,{}).get(target,"") == "a:3144:1602:1592:20:30"),"B sees A's shared preview")
	a.clear_preview(send(0))
	check(await until(func(): return not b.previews.has(a.me)),"preview cleared for B")
	check(a.state_of(target) == "a:3144:1601.5:1592:20:30","preview did not change accepted state")
	# Reservation blocks the other editor.
	var locked := b.reserve(target,send(1))
	check(await until(func(): return a.locks.get(target,"") == b.me),"B's reservation visible to A")
	var blocked := a.set_state(target,"a:3144:1603:1592:20:30","move",send(0))
	check(await request_done(0,blocked) and status(0,blocked) == "failed" and "reserved" in a.requests[blocked].detail,"A's edit refused while B holds the reservation")
	# B moves (accepted), A then edits from the stale revision (conflict).
	var stale_base := a.revision_of(target)
	var moved := b.set_state(target,"a:3144:1603:1592:20:30","move",send(1))
	check(await request_done(1,moved) and status(1,moved) == "applied","B moves the reserved object")
	b.release(target,send(1))
	check(await until(func(): return not a.locks.has(target)),"reservation released")
	await until(func(): return a.revision_of(target) == b.revision_of(target))
	var conflict_text := "set %%d %s %d %s" % [target,stale_base,"a:3144:1604:1592:20:30"]
	var conflict := a._request("set","stale move",conflict_text,send(0))
	check(await request_done(0,conflict) and status(0,conflict) == "failed" and "conflict" in a.requests[conflict].detail,"stale-revision edit rejected as an explicit conflict")
	# A's undo of its placement would overwrite B's newer move: refused.
	check(a.undo_candidate() == seq,"A's undo stack holds its placement")
	var undo_a := a.undo(send(0))
	check(await request_done(0,undo_a) and status(0,undo_a) == "failed" and b.me in a.requests[undo_a].detail,"undo refused: would overwrite %s's newer change" % b.me)
	check(a.state_of(target) == "a:3144:1603:1592:20:30","refused undo left B's change intact")
	# B undoes and redoes its own move.
	var undo_b := b.undo(send(1))
	check(await request_done(1,undo_b) and status(1,undo_b) == "applied" and await until(func(): return a.state_of(target) == "a:3144:1601.5:1592:20:30"),"B's own undo restores A's placement for both")
	var redo_b := b.redo(send(1))
	check(await request_done(1,redo_b) and status(1,redo_b) == "applied" and await until(func(): return a.state_of(target) == "a:3144:1603:1592:20:30"),"B's redo reapplies for both")
	var redo_seq: int = b.requests[redo_b].seq
	# Invalid commands fail without changing the session.
	var before := a.revision
	var bad_asset := a.place(999,1601,1592,20,0,send(0))
	var outside := a.place(3144,10,10,20,0,send(0))
	var malformed := a._request("set","malformed","set %d s:1:2 0 hide",send(0))
	var far_move := a._request("set","far","set %d s:1600:1590:20:3144:0 0 m:1620:1590:20:0:3144",send(0))
	var big_brush := a.brush(1650,1650,9,4,"-",send(0))
	for id in [bad_asset,outside,malformed,far_move,big_brush]: await request_done(0,id)
	check([bad_asset,outside,malformed,far_move,big_brush].all(func(id: int): return status(0,id) == "failed"),"unapproved, out-of-region, malformed, over-distance and oversized commands rejected")
	check(a.revision == before and b.revision == before,"rejected commands left the revision at %d" % before)
	# A real static from the prepared bake: hide it, B sees it.
	var static_target := real_static()
	if static_target != "":
		var hidden := a.set_state(static_target,"hide","hide",send(0))
		check(await request_done(0,hidden) and status(0,hidden) == "applied" and await until(func(): return b.state_of(static_target) == "hide"),"A hides baked static %s; B receives it" % static_target)
	# Reconnect / late join: B drops, A edits, B returns and gets the snapshot.
	clients[1].close()
	await until(func(): return not a.editors.has(b.me),3000)
	var while_away := a.set_state(target,"a:3144:1604:1593:20:45","move",send(0))
	check(await request_done(0,while_away) and status(0,while_away) == "applied","A edits while B is disconnected")
	var b_name := b.me
	clients[1].queue_free()
	if not await connect_client(1): check(false,"B reconnects");return
	b = states[1]
	check(await join(1) and b.me == b_name,"B reconnects as the same editor")
	check(b.state_of(target) == "a:3144:1604:1593:20:45" and b.revision == a.revision and b.revision_of(target) == a.revision_of(target),"late join snapshot has A's edit and revision %d" % a.revision)
	check(b.undo_candidate() == redo_seq,"history snapshot rebuilds B's undo stack (next undo: revision %d)" % redo_seq)
	if static_target != "": check(b.state_of(static_target) == "hide","late join snapshot includes the hidden static")
	# Terrain brush across the district border x = 1664.
	var brush_started := now_ms()
	var brush := a.brush(1664,1560,2,6,"dirt",send(0))
	check(await request_done(0,brush) and status(0,brush) == "applied","cross-district terrain brush accepted")
	check(await until(func(): return b.state_of("t:1664:1560") == "h:6:dirt" and b.state_of("t:1662:1560") == "h:2:dirt" and b.state_of("t:1663:1560") == "h:4:dirt"),"B receives the brushed samples with the deterministic falloff")
	stats.brush_round_trip_ms = now_ms()-brush_started
	# Saved edit set.
	var saved := a.save("live-check",send(0))
	check(await request_done(0,saved) and status(0,saved) == "applied" and "sha256" in a.requests[saved].detail,"edit set saved: %s" % a.requests[saved].get("detail",""))
	# Return every target this run touched to baseline (attributed restore ops).
	var cleared := true
	for t in a.targets.keys():
		if a.revision_of(t) > start and a.state_of(t) != "":
			var reset := a.set_state(t,"","restore",send(0))
			await request_done(0,reset)
			cleared = cleared and status(0,reset) == "applied"
	for t in a.targets:
		if a.revision_of(t) > start and a.state_of(t) != "": cleared = false
	check(cleared,"every test edit returned to baseline")
	if "--mark" in OS.get_cmdline_user_args():
		var mark := a.place(3204,1603,1595,20,0,send(0))
		check(await request_done(0,mark) and status(0,mark) == "applied","restart marker placed")
		var marker_target := ""
		for t in a.targets:
			if a.revision_of(t) == int(a.requests[mark].seq): marker_target = t
		DirAccess.make_dir_recursive_absolute(marker_path().get_base_dir())
		var file := FileAccess.open(marker_path(),FileAccess.WRITE)
		file.store_string(JSON.stringify({"target":marker_target,"state":a.state_of(marker_target),"revision":a.revision_of(marker_target),"author":a.me}))
		file.close()
	stats.revision = a.revision

func verify_marker() -> void:
	var a: State = states[0]
	check(FileAccess.file_exists(marker_path()),"marker record exists")
	var marker: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(marker_path()))
	check(await join(0),"editor rejoins after server restart")
	check(a.state_of(marker.target) == marker.state and a.revision_of(marker.target) == int(marker.revision) and a.author_of(marker.target) == marker.author,"edit survived the server restart with revision and author")
	var removed := a.set_state(marker.target,"","remove",send(0))
	check(await request_done(0,removed) and status(0,removed) == "applied","marker removed")
	DirAccess.remove_absolute(marker_path())

# A decorative baked static from the local prepared bake (none when absent).
func real_static() -> String:
	var path := ProjectSettings.globalize_path("res://../outputs/britain/prepared/near_1600_1536.res")
	if not FileAccess.file_exists(path): return ""
	var resource: Resource = load(path)
	for key in resource.source_info:
		var parts: PackedStringArray = str(resource.source_info[key]).split("|")
		if parts[0] in ["flower","grass","bush","mushroom"] and parts[1] == "replacement" and resource.source_map.has(key): return "s:"+key
	return ""
