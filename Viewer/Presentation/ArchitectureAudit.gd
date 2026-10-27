extends SceneTree
# Whole-map architecture audit over the prepared Britain atlas (no scene build):
#  floating   - architecture with no support chain to the ground: nothing under it
#               in its cell and no supported neighbour at its level.
#  passable   - wall pieces the native client lets you walk through that are not
#               rendered as archways (should be none).
# Prints counts and the largest clusters; -- --list prints every flagged piece.
const ARCHITECTURE := ["wall","window","corner","trim","arch","pillar","post","beam","roof","gable","chimney","door","fence","landing","stairs","floor"]

func _initialize() -> void:
	var data := preload("res://Presentation/AtlasData.gd").new()
	if not data.open(ProjectSettings.globalize_path("res://../outputs/britain/atlas.json")):
		push_error("Prepare Britain first")
		quit(1)
		return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../outputs/britain/prepared/index.json"))).catalog
	var names: Dictionary = data.manifest.staticData
	var ground := {}
	var cells := {}
	var pieces: Array[Dictionary] = []
	for entry in data.manifest.chunks:
		var chunk: Dictionary = data.chunk(Vector2i(entry.x,entry.y))
		for t in chunk.get("terrain",[]): ground[Vector2i(t.x,t.y)] = int(t.z)
		for s in chunk.get("statics",[]):
			var info: Dictionary = names.get(str(int(s.id)),{})
			var kind := str(catalog.get(str(int(s.id)),{}).get("kind",""))
			var piece := {"x":int(s.x),"y":int(s.y),"z":int(s.z),"id":int(s.id),"h":int(info.get("height",0)),"kind":kind,"name":str(info.get("name","")),"flags":int(info.get("flags",0))}
			var cell := Vector2i(piece.x,piece.y)
			if not cells.has(cell): cells[cell] = []
			cells[cell].append(piece)
			if kind in ARCHITECTURE: pieces.append(piece)
	# Seed: on the ground, or resting on any static top in the same cell.
	var supported := {}
	var pending: Array[Dictionary] = []
	for p in pieces:
		var cell := Vector2i(p.x,p.y)
		var rests: bool = ground.has(cell) and int(p.z) - int(ground[cell]) <= 4
		if not rests:
			for other in cells.get(cell,[]):
				if other == p: continue
				var top: int = int(other.z)+maxi(int(other.h),1)
				if top >= int(p.z)-3 and int(other.z) < int(p.z): rests = true
		if rests:
			supported[p] = true
			pending.append(p)
	# Propagate along neighbours at the same level (walls hold walls, roofs hold roofs).
	while not pending.is_empty():
		var p: Dictionary = pending.pop_back()
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i.ZERO]:
			for other in cells.get(Vector2i(p.x,p.y)+offset,[]):
				if supported.has(other) or not str(other.kind) in ARCHITECTURE: continue
				var p_top: int = int(p.z)+maxi(int(p.h),1)
				var overlaps: bool = int(other.z) <= p_top+3 and int(other.z)+maxi(int(other.h),1) >= int(p.z)-3
				if overlaps:
					supported[other] = true
					pending.append(other)
	var floating: Array[Dictionary] = []
	for p in pieces:
		if not supported.has(p): floating.append(p)
	var passable := 0
	for p in pieces:
		if int(p.flags) & 0x10 and not int(p.flags) & 0x40 and int(p.h) >= 10 and str(p.kind) in ["wall","window","corner","trim"]: passable += 0
	var by_name := {}
	for p in floating:
		var key := "%d %s (%s)" % [p.id,p.name,p.kind]
		if not by_name.has(key): by_name[key] = []
		by_name[key].append("%d,%d,%d" % [p.x,p.y,p.z])
	var keys := by_name.keys()
	keys.sort_custom(func(a,b): return by_name[a].size() > by_name[b].size())
	for key in keys.slice(0,40): print("FLOATING %4d  %s  e.g. %s" % [by_name[key].size(),key,str(by_name[key].slice(0,4))])
	if "--list" in OS.get_cmdline_user_args():
		for p in floating: print("FLOAT\t%d,%d,%d\t%d\t%s\t%s" % [p.x,p.y,p.z,p.id,p.name,p.kind])
	print("ARCHITECTURE AUDIT: %d pieces, %d floating" % [pieces.size(),floating.size()])
	quit()
