extends RefCounted
# The character list (0xA9) carries names only, so the front end remembers how
# each character looked when it last entered the world on this computer: body,
# skin hue, worn items and where it stood. No secrets; one file per account.
const FOLDER := "user://characters"

static func _path(account: String) -> String:
	var safe := ""
	for i in account.length():
		var c := account[i]
		safe += c if c.is_valid_identifier() or c.is_valid_int() else "_"
	return FOLDER.path_join(safe.to_lower()+".json")

static func load_all(account: String) -> Dictionary:
	var path := _path(account)
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func remember(account: String, name: String, look: Dictionary) -> void:
	if account.is_empty() or name.is_empty(): return
	var all := load_all(account)
	all[name] = look
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	var file := FileAccess.open(_path(account),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(all,"\t"))

# What the session currently shows of the player.
static func capture(session: Node) -> Dictionary:
	var serial := int(session.player.get("serial",0))
	var worn: Array = []
	for item: Dictionary in session.mobile_equipment.get(serial,{}).values():
		worn.append({"id":int(item.get("id",0)),"hue":int(item.get("hue",0)),"layer":int(item.get("layer",0))})
	var x := int(session.player.get("x",0))
	var y := int(session.player.get("y",0))
	return {"body":int(session.player.get("body",400)),"hue":int(session.player.get("hue",1002)),"worn":worn,"x":x,"y":y,"place":place(x,y),"at":Time.get_datetime_string_from_system()}

# A readable place for a Trammel tile.
static func place(x: int, y: int) -> String:
	for town in [["Britain",Rect2i(1300,1450,450,400)],["Trinsic",Rect2i(1800,2650,350,350)],["Yew",Rect2i(400,800,400,300)],["Minoc",Rect2i(2400,350,250,300)],["Vesper",Rect2i(2800,600,250,450)],["Moonglow",Rect2i(4300,1000,300,300)],["Magincia",Rect2i(3600,2050,250,250)],["Jhelom",Rect2i(1250,3650,300,350)],["Skara Brae",Rect2i(550,2050,200,250)],["Serpent's Hold",Rect2i(2850,3350,200,200)],["Cove",Rect2i(2200,1100,120,150)],["Buccaneer's Den",Rect2i(2600,2000,200,250)],["Ocllo",Rect2i(3550,2450,250,300)],["Nujel'm",Rect2i(3600,1100,250,300)]]:
		if town[1].has_point(Vector2i(x,y)): return town[0]
	if Rect2i(1600,1800,500,850).has_point(Vector2i(x,y)): return "The road to Trinsic"
	return "Trammel %d, %d" % [x,y]

# Starting clothes ModernUO gives a new character, for previews.
static func starter(female: bool) -> Array:
	return [{"id":0x1517,"hue":0x0386,"layer":5},{"id":0x1516 if female else 0x152E,"hue":0x0362,"layer":4},{"id":0x170F,"hue":0x0455,"layer":3}]
