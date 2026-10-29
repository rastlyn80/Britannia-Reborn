extends RefCounted
# Rule-based scope ("every barrel near me"). A rule is compact text that fits
# a group preview and is evaluated identically by every client on its own
# source records:  name~barrel;kind=flower;id=3206,3204;near=1602,1591,12;
# rect=1590,1580,1610,1600;by=Ann;edited;placed
# Static rules must be bounded by near= (radius <= 32) or rect= (<= 96x96), so
# a sentence can never silently touch the whole city.
const MAX_RADIUS := 32
const MAX_SIDE := 96

static func parse(rule: String) -> Dictionary:
	var result := {"text":rule}
	if rule.is_empty() or rule.length() > 100: return {"error":"rules hold 1-100 characters"}
	for clause in rule.split(";",false):
		if clause.begins_with("name~"): result.name = clause.substr(5).replace("_"," ")
		elif clause.begins_with("kind="): result.kinds = Array(clause.substr(5).split(",",false))
		elif clause.begins_with("id="):
			result.ids = []
			for id in clause.substr(3).split(",",false):
				if not id.is_valid_int(): return {"error":"id= takes graphic numbers"}
				result.ids.append(int(id))
		elif clause.begins_with("near="):
			var n := clause.substr(5).split(",")
			if n.size() != 3 or not (n[0].is_valid_int() and n[1].is_valid_int() and n[2].is_valid_int()) or int(n[2]) < 0 or int(n[2]) > MAX_RADIUS: return {"error":"near=X,Y,R with R up to %d" % MAX_RADIUS}
			result.area = Rect2i(int(n[0])-int(n[2]),int(n[1])-int(n[2]),int(n[2])*2+1,int(n[2])*2+1)
			result.centre = Vector2i(int(n[0]),int(n[1]))
			result.radius = int(n[2])
		elif clause.begins_with("rect="):
			var r := clause.substr(5).split(",")
			if r.size() != 4 or not Array(r).all(func(v: String): return v.is_valid_int()): return {"error":"rect=X1,Y1,X2,Y2"}
			var area := Rect2i(mini(int(r[0]),int(r[2])),mini(int(r[1]),int(r[3])),absi(int(r[2])-int(r[0]))+1,absi(int(r[3])-int(r[1]))+1)
			if area.size.x > MAX_SIDE or area.size.y > MAX_SIDE: return {"error":"rect= is limited to %dx%d tiles" % [MAX_SIDE,MAX_SIDE]}
			result.area = area
		elif clause.begins_with("by="): result.by = clause.substr(3).replace("_"," ")
		elif clause == "edited": result.edited = true
		elif clause == "placed": result.placed = true
		else: return {"error":"unknown rule clause '%s'" % clause}
	if not result.has("area") and not result.has("placed") and not result.has("edited"): return {"error":"a rule needs near= or rect= (or placed/edited)"}
	return result

# records: Array of {target, x, y, z, id, name, kind, editable, reason}.
# state: DevEditState for edited/placed/by clauses. Returns targets plus an
# explanation of what matched and what was skipped and why.
static func evaluate(rule: Dictionary, records: Array, state: RefCounted) -> Dictionary:
	var targets: Array = []
	var skipped := {}
	var matched := 0
	var candidates: Array = []
	if rule.get("placed",false):
		for target in state.targets:
			if target.begins_with("p:") and state.state_of(target) != "":
				var p: Dictionary = preload("res://DevEdit/DevEditState.gd").placement(state.state_of(target))
				candidates.append({"target":target,"x":floori(p.x),"y":floori(p.y),"z":p.z,"id":p.id,"name":"","kind":"placed","editable":true,"reason":""})
	else: candidates = records
	for record in candidates:
		if rule.has("area") and not rule.area.has_point(Vector2i(record.x,record.y)): continue
		if rule.has("radius") and Vector2(record.x,record.y).distance_to(Vector2(rule.centre)) > float(rule.radius)+0.01: continue
		if rule.has("name") and not str(rule.name).to_lower() in str(record.name).to_lower(): continue
		if rule.has("kinds") and not str(record.kind) in rule.kinds: continue
		if rule.has("ids") and not int(record.id) in rule.ids: continue
		if rule.get("edited",false) and state.state_of(record.target) == "": continue
		if rule.has("by") and state.author_of(record.target) != rule.by: continue
		matched += 1
		if not record.editable:
			skipped[record.reason] = int(skipped.get(record.reason,0))+1
			continue
		targets.append(record.target)
	targets.sort()
	return {"targets":targets,"matched":matched,"skipped":skipped}

static func describe(rule: Dictionary, result: Dictionary) -> String:
	var where := ""
	if rule.has("radius"): where = " within %d tiles of %d,%d" % [rule.radius,rule.centre.x,rule.centre.y]
	elif rule.has("area"): where = " in %d,%d–%d,%d" % [rule.area.position.x,rule.area.position.y,rule.area.end.x-1,rule.area.end.y-1]
	var what := "placed objects" if rule.get("placed",false) else "statics"
	if rule.has("name"): what = "'%s' %s" % [rule.name,what]
	if rule.has("kinds"): what += " of kind "+",".join(rule.kinds)
	var text := "%d %s%s" % [result.targets.size(),what,where]
	if result.matched > result.targets.size():
		var reasons: Array[String] = []
		for reason in result.skipped: reasons.append("%d %s" % [result.skipped[reason],reason.split(" (")[0].split(":")[0]])
		text += " (%d matched; skipped %s)" % [result.matched,", ".join(reasons)]
	return text
