extends RefCounted
# Committed developer edits ("manual overrides") applied by the converter on
# every bake. They come from live editing (DevEdit/, Commit) and from persistent
# rules ("always hide weeds on the streets"). Overrides are presentation only:
# hidden or moved statics keep their original collision, placed objects have
# none, and terrain collision keeps the source heights, so the baked client
# stays consistent with ModernUO. Files are local by default:
# <dataset>/overrides/committed.overrides.json (ignored with the dataset), plus
# res://DevEdit/overrides/*.overrides.json if the owner chooses to publish some.
# Schema 1: {"format","schema","baseline","statics":{key:[state,author]},
# "placed":{"N":[state,author]},"terrain":{"x:y":[dz,surface,author]},
# "rules":[{"rule","action","author","text"}]}
const FORMAT := "britannia-reborn-overrides"
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

# Merges published then local files in name order (later wins); returns false
# and records nothing from a malformed file.
func load_from(dataset: String) -> void:
	var paths: Array = []
	for base in ["res://DevEdit/overrides",folder(dataset)]:
		if not DirAccess.dir_exists_absolute(base): continue
		var names := Array(DirAccess.get_files_at(base)).filter(func(n: String): return n.ends_with(".overrides.json"))
		names.sort()
		for name in names: paths.append(base.path_join(name))
	for path in paths:
		var data := read(path)
		if data.is_empty():
			push_error("Ignoring malformed overrides file: "+path)
			continue
		files.append(path)
		statics.merge(data.get("statics",{}),true)
		placed.merge(data.get("placed",{}),true)
		for cell in data.get("terrain",{}): terrain[cell] = data.terrain[cell]
		rules.append_array(data.get("rules",[]))

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

# Folds the session's current overlay into the committed file. Statics and
# placed objects take the new absolute state; terrain deltas add to what was
# already committed (the session edits relative to the baked result). A copy
# goes to history/ so a commit can be reviewed or reverted.
static func commit(dataset: String, targets: Dictionary, new_rules: Array, author: String) -> Dictionary:
	var path := committed_path(dataset)
	var data := read(path)
	if data.is_empty(): data = empty()
	var counts := {"statics":0,"placed":0,"terrain":0,"rules":new_rules.size()}
	for target in targets:
		var state: String = targets[target].state
		var who: String = targets[target].author
		if target.begins_with("s:"):
			if state == "": data.statics.erase(target.substr(2))
			else: data.statics[target.substr(2)] = [state,who]
			counts.statics += 1
		elif target.begins_with("p:"):
			if state == "": data.placed.erase(target.substr(2))
			else: data.placed[target.substr(2)] = [state,who]
			counts.placed += 1
		elif target.begins_with("t:") and state != "":
			var f := state.split(":")
			var key: String = target.substr(2)
			var before: Array = data.terrain.get(key,[0,"-",""])
			var dz := clampi(int(before[0])+int(f[1]),-40,40)
			var surface: String = f[2] if f[2] != "-" else str(before[1])
			if dz == 0 and surface == "-": data.terrain.erase(key)
			else: data.terrain[key] = [dz,surface,who]
			counts.terrain += 1
	for rule in new_rules: data.rules.append(rule)
	DirAccess.make_dir_recursive_absolute(folder(dataset).path_join("history"))
	var text := JSON.stringify(data,"  ",true)
	var stamp := Time.get_datetime_string_from_system(true).replace(":","").replace("-","")
	var history := FileAccess.open(folder(dataset).path_join("history/%s-%s.overrides.json" % [stamp,author.to_lower().replace(" ","-")]),FileAccess.WRITE)
	history.store_string(text)
	history.close()
	var file := FileAccess.open(path+".pending",FileAccess.WRITE)
	file.store_string(text)
	file.close()
	DirAccess.rename_absolute(path+".pending",path)
	counts.digest = text.sha256_text().left(16)
	return counts
