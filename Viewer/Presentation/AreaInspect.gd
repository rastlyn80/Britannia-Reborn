extends SceneTree
# Lists source statics in a native rectangle of the prepared Britain atlas with
# their tiledata name, height, flags, passability and resolved presentation rule.
# Diagnostic only (prints local source facts; nothing is written or committed).
#   -- X0 Y0 X1 Y1 [kind,kind...]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var data := preload("res://Presentation/AtlasData.gd").new()
	if not data.open(ProjectSettings.globalize_path("res://../outputs/britain/atlas.json")):
		push_error("Prepare Britain first (scripts/prepare-britain.ps1)")
		quit(1)
		return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../outputs/britain/prepared/index.json"))).catalog
	var x0 := int(args[0])
	var y0 := int(args[1])
	var x1 := int(args[2])
	var y1 := int(args[3])
	var kinds: PackedStringArray = args[4].split(",") if args.size() > 4 else PackedStringArray()
	var rows: Array[String] = []
	for entry in data.manifest.chunks:
		if int(entry.x)+64 <= x0 or int(entry.x) > x1 or int(entry.y)+64 <= y0 or int(entry.y) > y1: continue
		for s in data.chunk(Vector2i(entry.x,entry.y)).get("statics",[]):
			if s.x < x0 or s.x > x1 or s.y < y0 or s.y > y1: continue
			var rule: Dictionary = catalog.get(str(int(s.id)),{})
			if not kinds.is_empty() and not str(rule.get("kind","")) in kinds: continue
			var info: Dictionary = data.manifest.staticData.get(str(int(s.id)),{})
			var flags := int(info.get("flags",0))
			rows.append("%4d,%4d,%4d\t%5d\t%-20s\th%-3d %s%s\t%s %s %s" % [s.x,s.y,s.z,int(s.id),str(info.get("name","")),int(info.get("height",0)),"IMPASS " if flags & 0x40 else "pass   ","WALL " if flags & 0x10 else "",rule.get("kind","-"),rule.get("axis",""),rule.get("asset",rule.get("model",rule.get("material",rule.get("surface",""))))])
	rows.sort()
	for row in rows: print(row)
	print("AREA INSPECT: %d statics" % rows.size())
	quit()
