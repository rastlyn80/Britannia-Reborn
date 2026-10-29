extends RefCounted
# One command grammar for every way of editing: the in-game panel, typed or
# spoken requests (DevEditIntent), proposals from Claude Code, and the CLI.
# plan(line) is a dry run: it resolves rules and the selection into concrete
# targets and states and describes the exact scope; send(plan) submits it.
#   place ID X Y Z [YAW] | brush X Y R DZ [SURFACE] | undo | redo | save NAME | load NAME
#   hide T | restore T | move T X Y Z [YAW] | rotate T DEG | replace T ID
#   select RULE | hide all RULE | restore all RULE | remove all RULE
#   replace all RULE ID | shift all RULE DX DY [DZ] | rotate all RULE DEG
# T is a target (s:…, p:…); RULE is a DevEditQuery rule or "selection".
const State = preload("res://DevEdit/DevEditState.gd")
const Query = preload("res://DevEdit/DevEditQuery.gd")
# Tame creatures "pet <kind>" asks the server for (Server DevEditSession.PetKinds).
const PETS := ["horse","packhorse","llama","packllama","desertostard","forestostard","dog","cat"]
var state: State
var sender: Callable
# Callable(area: Rect2i) -> Array of source records (see DevEditQuery).
var records: Callable
var selection: Array = []
var assets: Dictionary = {}

func _init(edit_state: State, send: Callable, record_source: Callable) -> void:
	state = edit_state
	sender = send
	records = record_source
	var catalogue: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://DevEdit/approved-assets.json"))
	if catalogue is Dictionary:
		for asset in catalogue.assets: assets[int(asset.id)] = str(asset.label)

static func fail(line: String, reason: String) -> Dictionary:
	return {"ok":false,"line":line,"error":reason}

# Current placement of an editable target (overlay state or its identity).
func placement_of(target: String) -> Dictionary:
	var place := State.placement(state.state_of(target))
	if not place.is_empty(): return place
	var identity := State.static_identity(target)
	if identity.is_empty(): return {}
	return {"x":float(identity.x),"y":float(identity.y),"z":int(identity.z),"yaw":0,"id":int(identity.id)}

static func encode(target: String, p: Dictionary) -> String:
	if target.begins_with("p:"): return "a:%d:%s:%s:%d:%d" % [p.id,State.number(p.x),State.number(p.y),p.z,posmod(int(p.yaw),360)]
	return "m:%s:%s:%d:%d:%d" % [State.number(p.x),State.number(p.y),p.z,posmod(int(p.yaw),360),p.id]

func resolve(rule_text: String) -> Dictionary:
	if rule_text == "selection":
		return {"targets":selection.duplicate(),"description":"%d selected object(s)" % selection.size(),"rule":"selection"}
	var rule := Query.parse(rule_text)
	if rule.has("error"): return {"error":rule.error}
	var source: Array = records.call(rule.get("area",Rect2i())) if rule.has("area") else []
	var result := Query.evaluate(rule,source,state)
	return {"targets":result.targets,"description":Query.describe(rule,result),"rule":rule_text}

func plan(line: String) -> Dictionary:
	var a := line.strip_edges().split(" ",false)
	if a.is_empty(): return fail(line,"empty command")
	var verb := a[0].to_lower()
	# A code fix to review in the world (scripts/code-preview.ps1); nothing is sent.
	if verb == "codepreview":
		if a.size() != 2 or RegEx.create_from_string("^[a-z][a-z0-9-]{2,40}$").search(a[1]) == null: return fail(line,"codepreview takes one preview id")
		return {"ok":true,"line":line,"kind":"codepreview","id":a[1],"targets":[],"description":"code fix preview "+a[1]}
	# A tame creature at the developer's feet: server-only, nothing goes to Git.
	if verb == "pet":
		if a.size() != 2 or not a[1].to_lower() in PETS: return fail(line,"pet takes one of: "+", ".join(PETS))
		return {"ok":true,"line":line,"kind":"pet","pet":a[1].to_lower(),"targets":[],"description":"a tame %s at your feet (server only)" % a[1].to_lower()}
	var all := a.size() > 2 and a[1] == "all"
	if all:
		var scope := resolve(a[2])
		if scope.has("error"): return fail(line,scope.error)
		if scope.targets.is_empty(): return fail(line,"nothing matches: "+str(scope.description))
		var items: Array = []
		match verb:
			"select":
				return {"ok":true,"line":line,"kind":"select","targets":scope.targets,"description":"select "+scope.description}
			"hide":
				for t in scope.targets:
					if t.begins_with("s:"): items.append([t,"hide"])
			"restore", "remove":
				for t in scope.targets: items.append([t,""])
			"replace":
				if a.size() != 4 or not a[3].is_valid_int(): return fail(line,"replace all RULE ID")
				if not assets.has(int(a[3])): return fail(line,"graphic %s is not an approved asset" % a[3])
				for t in scope.targets:
					var p := placement_of(t)
					p.id = int(a[3])
					items.append([t,encode(t,p)])
			"shift":
				if a.size() < 5 or not a[3].is_valid_float() or not a[4].is_valid_float(): return fail(line,"shift all RULE DX DY [DZ]")
				for t in scope.targets:
					var p := placement_of(t)
					p.x += float(a[3]);p.y += float(a[4]);p.z += int(a[5]) if a.size() > 5 else 0
					items.append([t,encode(t,p)])
			"rotate":
				if a.size() != 4 or not a[3].is_valid_int(): return fail(line,"rotate all RULE DEGREES")
				for t in scope.targets:
					var p := placement_of(t)
					p.yaw = int(p.yaw)+int(a[3])
					items.append([t,encode(t,p)])
			_: return fail(line,"'%s all' is not a group command" % verb)
		if items.is_empty(): return fail(line,"no editable targets for that action")
		var action: String = {"shift":"move","remove":"remove"}.get(verb,verb)
		if items.size() == 1:
			return {"ok":true,"line":line,"kind":"set","target":items[0][0],"state":items[0][1],"targets":[items[0][0]],"description":"%s %s" % [verb,items[0][0]]}
		return {"ok":true,"line":line,"kind":"batch","action":action,"items":items,"targets":items.map(func(i: Array): return i[0]),"description":"%s %s" % [verb,scope.description],"rule":scope.rule}
	match verb:
		"place":
			if a.size() < 5 or not a[1].is_valid_int(): return fail(line,"place ID X Y Z [YAW]")
			if not assets.has(int(a[1])): return fail(line,"graphic %s is not an approved asset" % a[1])
			return {"ok":true,"line":line,"kind":"place","id":int(a[1]),"x":float(a[2]),"y":float(a[3]),"z":int(a[4]),"yaw":int(a[5]) if a.size() > 5 else 0,"targets":[],"description":"place %s at %s, %s, Z %s" % [assets[int(a[1])],a[2],a[3],a[4]]}
		"brush":
			if a.size() < 5: return fail(line,"brush X Y R DZ [SURFACE]")
			var surface := a[5] if a.size() > 5 else "-"
			if not surface in State.SURFACES: return fail(line,"surfaces: "+", ".join(State.SURFACES))
			return {"ok":true,"line":line,"kind":"brush","x":int(a[1]),"y":int(a[2]),"r":int(a[3]),"dz":int(a[4]),"surface":surface,"targets":[],"description":"terrain disc r%s %+d Z, surface %s at %s,%s (visual only)" % [a[3],int(a[4]),surface,a[1],a[2]]}
		"undo", "redo":
			var seq := state.undo_candidate() if verb == "undo" else state.redo_candidate()
			if seq == 0: return fail(line,"nothing to "+verb)
			return {"ok":true,"line":line,"kind":verb,"targets":[],"description":"%s revision %d" % [verb,seq]}
		"save", "load":
			if a.size() != 2: return fail(line,verb+" NAME")
			return {"ok":true,"line":line,"kind":verb,"name":a[1],"targets":[],"description":"%s edit set %s" % [verb,a[1]]}
		"hide", "restore":
			if a.size() != 2: return fail(line,verb+" TARGET")
			return {"ok":true,"line":line,"kind":"set","target":a[1],"state":"hide" if verb == "hide" else "","targets":[a[1]],"description":"%s %s" % [verb,a[1]]}
		"move", "rotate", "replace":
			if a.size() < 3: return fail(line,"%s TARGET …" % verb)
			var p := placement_of(a[1])
			if p.is_empty(): return fail(line,"unknown target "+a[1])
			if verb == "move":
				if a.size() < 5: return fail(line,"move TARGET X Y Z [YAW]")
				p.x = float(a[2]);p.y = float(a[3]);p.z = int(a[4])
				if a.size() > 5: p.yaw = int(a[5])
			elif verb == "rotate": p.yaw = int(p.yaw)+int(a[2])
			else:
				if not assets.has(int(a[2])): return fail(line,"graphic %s is not an approved asset" % a[2])
				p.id = int(a[2])
			return {"ok":true,"line":line,"kind":"set","target":a[1],"state":encode(a[1],p),"targets":[a[1]],"description":"%s %s" % [verb,a[1]]}
	return fail(line,"unknown command '%s'" % verb)

# Submits a plan; returns the request id (0 if not sent). "select" sends nothing.
func send(p: Dictionary) -> int:
	if not p.ok: return 0
	match p.kind:
		"select":
			selection = p.targets.duplicate()
			return -1
		"set": return state.set_state(p.target,p.state,p.description,sender)
		"batch": return state.batch(p.action,p.items,p.description,sender)
		"place": return state.place(p.id,p.x,p.y,p.z,p.yaw,sender)
		"brush": return state.brush(p.x,p.y,p.r,p.dz,p.surface,sender)
		"undo": return state.undo(sender)
		"redo": return state.redo(sender)
		"save": return state.save(p.name,sender)
		"load": return state.load_set(p.name,sender)
		"pet": return state.pet(p.pet,sender)
	return 0
