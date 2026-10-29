extends RefCounted
# Client mirror of the server-authoritative developer edit session.
# Accepted state arrives only from ModernUO (UCEDIT1 records); this class never
# invents accepted edits. It also builds the textual commands, so the in-game
# panel, scripted tests and a future conversational assistant share one
# command model (see docs/DEV_EDIT.md).
signal targets_changed(targets: Array, seq: int, author: String, action: String)
signal previews_changed(author: String)
signal locks_changed(target: String)
signal session_changed
signal request_changed(request: int)
signal rejected(request: int, code: String, detail: String)
signal conversation_changed(ask: int)

const SURFACES := ["-","grass","forest","dirt","cobblestones","sand","brick"]
var me := ""
var session := ""
var baseline := ""
var revision := 0
var synced := false
var denied := ""
var targets: Dictionary = {}
var history: Dictionary = {}
var previews: Dictionary = {}
var locks: Dictionary = {}
var editors: Dictionary = {}
var requests: Dictionary = {}
var next_request := 1
var last_saved := ""
var building: Dictionary = {}
var malformed := 0
# Conversation: id -> {author, text, status, answers, proposal, proposed_by}.
var asks: Dictionary = {}
var proposal_parts: Dictionary = {}

static func is_int(text: String) -> bool:
	return text.is_valid_int() and str(int(text)) == text

func state_of(target: String) -> String:
	return str(targets.get(target,{}).get("state",""))

func revision_of(target: String) -> int:
	return int(targets.get(target,{}).get("rev",0))

func author_of(target: String) -> String:
	return str(targets.get(target,{}).get("author",""))

func reset() -> void:
	targets.clear();history.clear();previews.clear();locks.clear();editors.clear();building.clear()
	synced = false
	revision = 0

# Returns false for a malformed or unknown record; nothing is applied then.
func feed(line: String) -> bool:
	var f := line.split("|")
	match f[0]:
		"hello":
			if f.size() != 5 or not is_int(f[3]): return _bad()
			reset()
			session = f[1];me = f[2];revision = int(f[3]);baseline = f[4];denied = ""
		"denied":
			denied = line.substr(7)
			session_changed.emit()
		"cur":
			if f.size() != 5 or not is_int(f[2]): return _bad()
			targets[f[1]] = {"state":f[4],"rev":int(f[2]),"author":f[3]}
		"hist":
			if f.size() != 7 or not is_int(f[1]) or not is_int(f[4]) or not is_int(f[5]): return _bad()
			history[int(f[1])] = {"author":f[2],"action":f[3],"reverts":int(f[4]),"reverted_by":int(f[5]),"count":int(f[6])}
		"synced":
			if f.size() != 2 or not is_int(f[1]): return _bad()
			revision = int(f[1])
			synced = true
			targets_changed.emit(targets.keys(),revision,"","sync")
			session_changed.emit()
		"op":
			if f.size() != 7 or not is_int(f[1]) or not is_int(f[4]) or not is_int(f[5]) or not is_int(f[6]): return _bad()
			building[int(f[1])] = {"author":f[2],"action":f[3],"count":int(f[4]),"request":int(f[5]),"reverts":int(f[6]),"changes":[]}
		"chg":
			if f.size() != 4 or not is_int(f[1]) or not building.has(int(f[1])): return _bad()
			building[int(f[1])].changes.append([f[2],f[3]])
		"end":
			if f.size() != 2 or not is_int(f[1]) or not building.has(int(f[1])): return _bad()
			_commit(int(f[1]),building[int(f[1])])
			building.erase(int(f[1]))
		"reject":
			if f.size() < 4 or not is_int(f[1]): return _bad()
			var detail := "|".join(f.slice(3))
			if requests.has(int(f[1])):
				requests[int(f[1])].status = "failed"
				requests[int(f[1])].detail = "%s: %s" % [f[2],detail]
				request_changed.emit(int(f[1]))
			rejected.emit(int(f[1]),f[2],detail)
		"ack":
			if f.size() != 3 or not is_int(f[1]): return _bad()
			if requests.has(int(f[1])):
				requests[int(f[1])].status = "applied"
				request_changed.emit(int(f[1]))
		"saved":
			if f.size() != 5 or not is_int(f[1]): return _bad()
			last_saved = "%s (%s targets, sha256 %s…)" % [f[2],f[3],f[4]]
			if requests.has(int(f[1])):
				requests[int(f[1])].status = "applied"
				requests[int(f[1])].detail = last_saved
				request_changed.emit(int(f[1]))
		"lock":
			if f.size() != 3: return _bad()
			locks[f[1]] = f[2]
			locks_changed.emit(f[1])
		"unlock":
			if f.size() != 2: return _bad()
			locks.erase(f[1])
			locks_changed.emit(f[1])
		"pv":
			if f.size() != 4: return _bad()
			if not previews.has(f[1]): previews[f[1]] = {}
			previews[f[1]][f[2]] = f[3]
			previews_changed.emit(f[1])
		"pvclear":
			if f.size() != 2: return _bad()
			previews.erase(f[1])
			previews_changed.emit(f[1])
		"who":
			if f.size() != 3 or not f[2] in ["on","off"]: return _bad()
			if f[2] == "on": editors[f[1]] = true
			else:
				editors.erase(f[1])
				previews.erase(f[1])
				previews_changed.emit(f[1])
			session_changed.emit()
		"ask":
			if f.size() < 4 or not is_int(f[1]): return _bad()
			asks[int(f[1])] = {"author":f[2],"text":"|".join(f.slice(3)),"status":"open","answers":[],"proposal":[],"proposed_by":""}
			conversation_changed.emit(int(f[1]))
		"answer":
			if f.size() < 4 or not is_int(f[1]) or not asks.has(int(f[1])): return _bad()
			asks[int(f[1])].answers.append("%s: %s" % [f[2],"|".join(f.slice(3))])
			if asks[int(f[1])].status == "open": asks[int(f[1])].status = "answered"
			conversation_changed.emit(int(f[1]))
		"prop":
			if f.size() < 6 or not is_int(f[1]) or not is_int(f[3]) or not is_int(f[4]) or not asks.has(int(f[1])): return _bad()
			var id := int(f[1])
			if int(f[3]) == 1: proposal_parts[id] = []
			if not proposal_parts.has(id) or proposal_parts[id].size() != int(f[3])-1: return _bad()
			proposal_parts[id].append("|".join(f.slice(5)))
			if int(f[3]) == int(f[4]):
				asks[id].proposal = proposal_parts[id]
				asks[id].proposed_by = f[2]
				asks[id].status = "proposed"
				proposal_parts.erase(id)
				conversation_changed.emit(id)
		"resolved":
			if f.size() != 4 or not is_int(f[1]) or not asks.has(int(f[1])): return _bad()
			asks[int(f[1])].status = f[3]
			conversation_changed.emit(int(f[1]))
		"status", "left":
			session_changed.emit()
		_:
			return _bad()
	return true

func _bad() -> bool:
	malformed += 1
	return false

func _commit(seq: int, op: Dictionary) -> void:
	if op.changes.size() != int(op.count):
		malformed += 1
		return
	var touched: Array = []
	for change in op.changes:
		targets[change[0]] = {"state":change[1],"rev":seq,"author":op.author}
		touched.append(change[0])
	history[seq] = {"author":op.author,"action":op.action,"reverts":op.reverts,"reverted_by":0,"count":op.count}
	if op.reverts > 0 and history.has(op.reverts): history[op.reverts].reverted_by = seq
	revision = maxi(revision,seq)
	if op.author == me and requests.has(op.request):
		requests[op.request].status = "applied"
		requests[op.request].seq = seq
		requests[op.request].applied_msec = Time.get_ticks_msec()
		request_changed.emit(op.request)
	targets_changed.emit(touched,seq,op.author,op.action)

# ---- undo/redo stacks derived from server history ----

func latest_edit() -> int:
	var latest := 0
	for seq in history:
		if history[seq].author == me and not history[seq].action in ["undo","redo","commit"]: latest = maxi(latest,seq)
	return latest

func undo_candidate() -> int:
	var best := 0
	for seq in history:
		var h: Dictionary = history[seq]
		if h.author == me and not h.action in ["undo","commit"] and int(h.reverted_by) == 0: best = maxi(best,seq)
	return best

func redo_candidate() -> int:
	var best := 0
	var latest := latest_edit()
	for seq in history:
		var h: Dictionary = history[seq]
		if h.author == me and h.action == "undo" and int(h.reverted_by) == 0 and seq > latest: best = maxi(best,seq)
	return best

# ---- command model (each returns the request id, or 0 if not encodable) ----

func _request(kind: String, description: String, command: String, sender: Callable) -> int:
	var id := next_request
	var text := command % id if "%d" in command else command
	if text.length() > 119 or not sender.call(text): return 0
	next_request += 1
	requests[id] = {"kind":kind,"description":description,"status":"pending","detail":"","sent_msec":Time.get_ticks_msec(),"seq":0}
	request_changed.emit(id)
	return id

func join(sender: Callable, assistant := false) -> bool: return sender.call("join assistant" if assistant else "join")
func leave(sender: Callable) -> bool: return sender.call("leave")

func set_state(target: String, state: String, description: String, sender: Callable) -> int:
	return _request("set",description,"set %%d %s %d %s" % [target,revision_of(target),state if state != "" else "-"],sender)

func place(asset: int, x: float, y: float, z: int, yaw: int, sender: Callable) -> int:
	return _request("place","place %d at %s,%s,%d" % [asset,number(x),number(y),z],"place %%d %d %s %s %d %d" % [asset,number(x),number(y),z,yaw],sender)

func brush(x: int, y: int, radius: int, delta: int, surface: String, sender: Callable) -> int:
	return _request("brush","terrain brush r%d %+d %s at %d,%d" % [radius,delta,surface,x,y],"brush %%d %d %d %d %d %s" % [x,y,radius,delta,surface],sender)

func pet(kind: String, sender: Callable) -> int:
	return _request("pet","tame %s" % kind,"pet %%d %s" % kind,sender)

func undo(sender: Callable) -> int:
	var seq := undo_candidate()
	return 0 if seq == 0 else _request("undo","undo revision %d" % seq,"undo %%d %d" % seq,sender)

func redo(sender: Callable) -> int:
	var seq := redo_candidate()
	return 0 if seq == 0 else _request("redo","redo revision %d" % seq,"redo %%d %d" % seq,sender)

func reserve(target: String, sender: Callable) -> int:
	return _request("lock","reserve "+target,"lock %%d %s" % target,sender)

func release(target: String, sender: Callable) -> bool:
	return sender.call("unlock 0 "+target)

func preview(target: String, state: String, sender: Callable) -> bool:
	return sender.call("preview %s %s" % [target,state if state != "" else "-"])

func clear_preview(sender: Callable) -> bool:
	return sender.call("preview clear")

# Several targets as one atomic, attributed operation (one undo). items are
# [target, state] pairs; base revisions come from the synced state.
func batch(action: String, items: Array, description: String, sender: Callable) -> int:
	if items.is_empty() or items.size() > 256: return 0
	var lines: Array[String] = []
	for item in items:
		var line := "batch %%d add %s %d %s" % [item[0],revision_of(item[0]),item[1] if item[1] != "" else "-"]
		if line.length() > 115: return 0
		lines.append(line)
	var id := next_request
	if not sender.call("batch %d begin %d %s" % [id,items.size(),action]): return 0
	for line in lines: sender.call(line % id)
	return _request(action,description,"batch %d commit",sender)

# Plain-language request, split into numbered parts within the speech limit.
# Splits text at word boundaries into pieces that fit one speech line.
static func pieces(text: String, width: int) -> Array[String]:
	var parts: Array[String] = []
	var current := ""
	for word in text.strip_edges().replace("|","/").split(" ",false):
		word = word.left(width)
		if (current+" "+word).length() > width and current != "":
			parts.append(current);current = word
		else: current = word if current == "" else current+" "+word
	if current != "": parts.append(current)
	return parts

func ask(text: String, sender: Callable) -> bool:
	var parts := pieces(text,100)
	if parts.is_empty() or parts.size() > 4: return false
	for i in parts.size():
		if not sender.call("ask %d/%d %s" % [i+1,parts.size(),parts[i]]): return false
	return true

# A long answer goes out as consecutive answer lines (up to 8).
func answer(id: int, text: String, sender: Callable) -> bool:
	var parts := pieces(text,110)
	if parts.is_empty() or parts.size() > 8: return false
	for part in parts:
		if not sender.call("answer %d %s" % [id,part]): return false
	return true

func propose(id: int, lines: Array, sender: Callable) -> bool:
	if lines.is_empty() or lines.size() > 32: return false
	for i in lines.size():
		if not sender.call("propose %d %d/%d %s" % [id,i+1,lines.size(),str(lines[i])]): return false
	return true

func resolve(id: int, outcome: String, sender: Callable) -> bool:
	return sender.call("resolve %d %s" % [id,outcome])

func save(name: String, sender: Callable) -> int:
	return _request("save","save edit set "+name,"save %%d %s" % name,sender)

func load_set(name: String, sender: Callable) -> int:
	return _request("load","load edit set "+name,"load %%d %s" % name,sender)

# Same canonical decimal formatting as the server (2 decimals, trimmed).
static func number(value: float) -> String:
	var rounded := snappedf(value,0.01)
	var text := "%.2f" % rounded
	while text.ends_with("0"): text = text.left(-1)
	if text.ends_with("."): text = text.left(-1)
	return "0" if text == "-0" else text

# Deterministic brush falloff, identical to DevEditSession.BrushCells.
static func brush_cells(x: int, y: int, radius: int, delta: int) -> Dictionary:
	var cells := {}
	for cy in range(y-radius,y+radius+1):
		for cx in range(x-radius,x+radius+1):
			var square := (cx-x)*(cx-x)+(cy-y)*(cy-y)
			if square > radius*radius: continue
			var weight := float(delta)*(float(radius+1)-sqrt(float(square)))/float(radius+1)
			cells[Vector2i(cx,cy)] = int(signf(weight)*floorf(absf(weight)+0.5))
	return cells

# Parses "s:X:Y:Z:ID:K" / "p:N" / "t:X:Y" and their states for the overlay.
static func static_identity(target: String) -> Dictionary:
	var f := target.split(":")
	if f.size() != 6 or f[0] != "s": return {}
	return {"x":int(f[1]),"y":int(f[2]),"z":int(f[3]),"id":int(f[4]),"k":int(f[5])}

static func placement(state: String) -> Dictionary:
	var f := state.split(":")
	if f.size() == 6 and f[0] == "m": return {"x":float(f[1]),"y":float(f[2]),"z":int(f[3]),"yaw":int(f[4]),"id":int(f[5])}
	if f.size() == 6 and f[0] == "a": return {"id":int(f[1]),"x":float(f[2]),"y":float(f[3]),"z":int(f[4]),"yaw":int(f[5])}
	return {}

static func terrain(state: String) -> Dictionary:
	var f := state.split(":")
	if f.size() == 3 and f[0] == "h": return {"dz":int(f[1]),"surface":f[2]}
	return {"dz":0,"surface":"-"}
