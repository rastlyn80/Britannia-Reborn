extends RefCounted
# Committed developer edits ("manual overrides") applied by the converter on
# every bake. They come from live editing (DevEdit/, Commit) and from persistent
# rules ("always hide weeds on the streets"). Overrides are presentation only:
# hidden or moved statics keep their original collision, placed objects have
# none, and terrain collision keeps the source heights, so the baked client
# stays consistent with ModernUO. Client-side edits (statics, placed objects,
# terrain, rules) are shared through Git: every Commit writes one change file
# and scripts/publish-world-edit.ps1 publishes it as
# res://DevEdit/overrides/<id>.overrides.json on a branch with a pull request;
# merged files reach every collaborator on pull. Until merged, the cumulative
# local copy <dataset>/overrides/committed.overrides.json keeps the edits in
# this world. Server-only state (the ModernUO session journal) never goes to Git.
# Schema 1: {"format","schema","baseline","id","commits","statics":{key:[state,author]},
# "placed":{"N":[state,author]},"terrain":{"x:y":[dz,surface,author]},
# "rules":[{"rule","action","author","text"}]}. A "" static/placed state or a
# [0,"-"] terrain entry restores the baseline over earlier files.
const FORMAT := "britannia-reborn-overrides"
const PUBLISHED := "res://DevEdit/overrides"
const SURFACES := ["grass","forest","dirt","cobblestones","sand","brick"]
var statics: Dictionary = {}
var placed: Dictionary = {}
var terrain: Dictionary = {}
var rules: Array = []
var files: Array = []

static func folder(dataset: String) -> String:
	return dataset.path_join("overrides")

static func committed_path(dataset: String) -> String:
	return folder(dataset).path_join("committed.overrides.json")

static func empty() -> Dictionary:
	return {"format":FORMAT,"schema":1,"baseline":"trammel-britain-1088-1408-704x512","statics":{},"placed":{},"terrain":{},"rules":[]}

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("format","") != FORMAT or int(data.get("schema",0)) != 1: return {}
	return data

# Merges the published change files in name (time) order, then the local
# cumulative copy unless every commit in it is already published; later wins
# and a malformed file is skipped. Restore entries are dropped after merging.
func load_from(dataset: String, published: String = PUBLISHED) -> void:
	var paths: Array = []
	if DirAccess.dir_exists_absolute(published):
		var names := Array(DirAccess.get_files_at(published)).filter(func(n: String): return n.ends_with(".overrides.json"))
		names.sort()
		for name in names: paths.append(published.path_join(name))
	paths.append(committed_path(dataset))
	var ids := {}
	for path in paths:
		var data := read(path)
		if data.is_empty():
			if FileAccess.file_exists(path): push_error("Ignoring malformed overrides file: "+path)
			continue
		if path == committed_path(dataset):
			var local: Array = data.get("commits",[])
			if not local.is_empty() and local.all(func(id: String): return ids.has(id)): continue
		elif data.has("id"): ids[str(data.id)] = true
		files.append(path)
		statics.merge(data.get("statics",{}),true)
		placed.merge(data.get("placed",{}),true)
		for cell in data.get("terrain",{}): terrain[cell] = data.terrain[cell]
		for rule in data.get("rules",[]):
			if not rules.any(func(r: Dictionary): return r.rule == rule.rule and r.action == rule.action): rules.append(rule)
	for key in statics.keys():
		if str(statics[key][0]) == "": statics.erase(key)
	for n in placed.keys():
		if str(placed[n][0]) == "": placed.erase(n)
	for cell in terrain.keys():
		if int(terrain[cell][0]) == 0 and str(terrain[cell][1]) == "-": terrain.erase(cell)

func is_empty() -> bool:
	return statics.is_empty() and placed.is_empty() and terrain.is_empty() and rules.is_empty()

static func cell(key: String) -> Vector2i:
	var f := key.split(":")
	return Vector2i(int(f[0]),int(f[1]))

# Everything that can change one district's baked scene, for its bake stamp.
# Terrain samples influence the cells on both sides; rules are global.
func chunk_digest(at: Vector2i) -> String:
	var parts: Array[String] = []
	for key in statics:
		var f: PackedStringArray = key.split(":")
		if Vector2i(floori(float(f[0])/64)*64,floori(float(f[1])/64)*64) == at: parts.append(key+"="+str(statics[key][0]))
	for n in placed:
		var p := placement(str(placed[n][0]))
		if not p.is_empty() and Vector2i(floori(p.x/64)*64,floori(p.y/64)*64) == at: parts.append("p"+str(n)+"="+str(placed[n][0]))
	for key in terrain:
		var c := cell(key)
		if c.x >= at.x-1 and c.x <= at.x+64 and c.y >= at.y-1 and c.y <= at.y+64: parts.append("t"+key+"="+str(terrain[key][0])+str(terrain[key][1]))
	for rule in rules: parts.append(JSON.stringify(rule))
	parts.sort()
	return "" if parts.is_empty() else "|".join(parts).sha256_text()

func digest() -> String:
	return "" if is_empty() else JSON.stringify([statics,placed,terrain,rules]).sha256_text()

static func placement(state: String) -> Dictionary:
	var f := state.split(":")
	if f.size() == 6 and f[0] == "m": return {"x":float(f[1]),"y":float(f[2]),"z":int(f[3]),"yaw":int(f[4]),"id":int(f[5])}
	if f.size() == 6 and f[0] == "a": return {"id":int(f[1]),"x":float(f[2]),"y":float(f[3]),"z":int(f[4]),"yaw":int(f[5])}
	return {}

# Persistent rules over source statics (bake time): name~, kind=, id=, rect=.
static func rule_matches(rule: Dictionary, s: Dictionary, name: String, kind: String) -> bool:
	for clause in str(rule.rule).split(";",false):
		if clause.begins_with("name~") and not clause.substr(5).replace("_"," ") in name.to_lower(): return false
		if clause.begins_with("kind=") and not kind in clause.substr(5).split(","): return false
		if clause.begins_with("id=") and not str(int(s.id)) in clause.substr(3).split(","): return false
		if clause.begins_with("rect="):
			var r := clause.substr(5).split(",")
			if r.size() != 4 or int(s.x) < mini(int(r[0]),int(r[2])) or int(s.x) > maxi(int(r[0]),int(r[2])) or int(s.y) < mini(int(r[1]),int(r[3])) or int(s.y) > maxi(int(r[1]),int(r[3])): return false
	return true

# ---- writing (client Commit) ----

# Folds the session's current overlay into the committed overrides. Statics and
# placed objects take the new absolute state ("" restores); terrain deltas add
# to what the world already shows (published plus local: the session edits
# relative to the baked result). Writes the local cumulative copy (plus a
# history/ copy for revert) and this commit's change file in outgoing/, which
# the caller publishes to Git. Returns counts, the commit id and change path.
static func commit(dataset: String, targets: Dictionary, new_rules: Array, author: String, published: String = PUBLISHED) -> Dictionary:
	var path := committed_path(dataset)
	var data := read(path)
	if data.is_empty(): data = empty()
	var world: RefCounted = load("res://Presentation/ManualOverrides.gd").new()
	world.load_from(dataset,published)
	var stamp := Time.get_datetime_string_from_system(true).replace(":","").replace("-","")
	var id := "%s-%s" % [stamp,author.to_lower().replace(" ","-").validate_filename()]
	var change := empty()
	change.id = id
	var counts := {"statics":0,"placed":0,"terrain":0,"rules":new_rules.size(),"id":id}
	for target in targets:
		var state: String = targets[target].state
		var who: String = targets[target].author
		if target.begins_with("s:") or target.begins_with("p:"):
			var group: String = "statics" if target.begins_with("s:") else "placed"
			data[group][target.substr(2)] = [state,who]
			change[group][target.substr(2)] = [state,who]
			counts[group] += 1
		elif target.begins_with("t:") and state != "":
			var f := state.split(":")
			var key: String = target.substr(2)
			var before: Array = world.terrain.get(key,[0,"-",""])
			var dz := clampi(int(before[0])+int(f[1]),-40,40)
			var surface: String = f[2] if f[2] != "-" else str(before[1])
			data.terrain[key] = [dz,surface,who]
			change.terrain[key] = [dz,surface,who]
			counts.terrain += 1
	for rule in new_rules:
		data.rules.append(rule)
		change.rules.append(rule)
	var commits: Array = data.get("commits",[])
	commits.append(id)
	data.commits = commits
	for sub in ["history","outgoing"]: DirAccess.make_dir_recursive_absolute(folder(dataset).path_join(sub))
	var text := JSON.stringify(data,"  ",true)
	write(folder(dataset).path_join("history/%s.overrides.json" % id),text)
	write(path,text)
	counts.change = folder(dataset).path_join("outgoing/%s.overrides.json" % id)
	write(counts.change,JSON.stringify(change,"  ",true))
	counts.digest = text.sha256_text().left(16)
	return counts

static func write(path: String, text: String) -> void:
	var file := FileAccess.open(path+".pending",FileAccess.WRITE)
	file.store_string(text)
	file.close()
	DirAccess.rename_absolute(path+".pending",path)
