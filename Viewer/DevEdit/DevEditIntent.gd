extends RefCounted
# Typed or spoken requests -> command lines (DevEditCommands grammar). This is
# a small, deterministic, offline interpreter for common requests; anything it
# does not recognise is not guessed: the panel offers to ask Claude Code, which
# answers through the shared session (ask/answer/propose). Every interpreted
# plan is shown with its exact scope and applies only after confirmation.
# Context keys: x, y, z (player tile), facing (UO direction 0-7), me.
const DIRECTIONS := {"north":Vector2(0,-1),"south":Vector2(0,1),"east":Vector2(1,0),"west":Vector2(-1,0)}
const FACING := [Vector2(0,-1),Vector2(1,-1),Vector2(1,0),Vector2(1,1),Vector2(0,1),Vector2(-1,1),Vector2(-1,0),Vector2(-1,-1)]
const NUMBERS := {"a":1,"an":1,"one":1,"two":2,"three":3,"four":4,"five":5,"six":6,"seven":7,"eight":8,"nine":9,"ten":10,"some":3,"a few":3,"several":4}
const KINDS := ["flower","bush","grass","tree","rock","log","mushroom","vine","planter"]
const SURFACES := ["dirt","grass","sand","cobblestones","forest","brick"]
var assets: Dictionary = {}

func _init() -> void:
	var catalogue: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://DevEdit/approved-assets.json"))
	if catalogue is Dictionary:
		for asset in catalogue.assets: assets[int(asset.id)] = str(asset.label).to_lower()

static func re(pattern: String) -> RegEx:
	var r := RegEx.new()
	r.compile(pattern)
	return r

static func singular(word: String) -> String:
	word = word.strip_edges()
	if word.ends_with("ies") and word.length() > 4: return word.left(-3)+"y"
	for suffix in ["sses","ches","shes","xes"]:
		if word.ends_with(suffix): return word.left(-2)
	if word.ends_with("s") and not word.ends_with("ss") and word.length() > 3: return word.left(-1)
	return word

static func amount(text: String) -> int:
	text = text.strip_edges()
	if text.is_valid_int(): return int(text)
	return int(NUMBERS.get(text,1))

func asset_for(thing: String) -> int:
	var wanted := singular(thing.to_lower().replace("some ","").strip_edges())
	var best := 0
	for id in assets:
		var label: String = assets[id]
		if label == wanted or singular(label) == wanted: return id
		if best == 0 and (wanted in label or singular(label) in wanted): best = id
	return best

# "here" -> the player's tile; "in front of me" -> two tiles ahead.
func point(where: String, context: Dictionary) -> Vector2:
	var at := Vector2(context.x,context.y)
	var m := re("(\\d+) tiles? (north|south|east|west)").search(where)
	if m: return at+DIRECTIONS[m.get_string(2)]*float(m.get_string(1))
	m = re("at (\\d+)[ ,]+(\\d+)").search(where)
	if m: return Vector2(float(m.get_string(1)),float(m.get_string(2)))
	if "front" in where or where.strip_edges() in ["","here"] or "next to me" in where:
		return at+FACING[int(context.get("facing",0)) & 7]*2.0
	return at

func area(where: String, context: Dictionary) -> String:
	var radius := 8
	var m := re("within (\\d+)").search(where)
	if m: radius = mini(int(m.get_string(1)),32)
	var centre := point(where,context) if ("front" in where or " at " in (" "+where)) else Vector2(context.x,context.y)
	return "near=%d,%d,%d" % [roundi(centre.x),roundi(centre.y),radius]

func thing_rule(thing: String) -> String:
	var word := singular(thing.replace("the ","").replace("all ","").replace("every ","").strip_edges())
	if word in KINDS: return "kind="+word
	return "name~"+word.replace(" ","_")

static func result(lines: Array, summary: String) -> Dictionary:
	return {"understood":true,"lines":lines,"summary":summary}

func interpret(text: String, context: Dictionary) -> Dictionary:
	var t := text.to_lower().strip_edges().trim_suffix(".").trim_suffix("!").replace("please ","").replace(",","")
	var m: RegExMatch
	if re("^(commit( (it|this|these|them|the edits|my edits|everything))?|make (it|this|these|them|the edits|everything) permanent|bake (it|this|the edits|everything)( into the world)?|save (it|this|everything) (into|to) the world)$").search(t):
		return {"understood":true,"commit":true,"lines":[],"summary":"commit the session's edits into the converted world"}
	# Persistent rules: data rules are stored for every bake; anything about how
	# things are built (roofs meeting walls, …) is a code change for Claude.
	m = re("^(?:always |from now on |everywhere |make sure (?:that )?|never )(.*)$").search(t)
	if m:
		var never := t.begins_with("never")
		var body := m.get_string(1).replace("always ","").replace("everywhere","").strip_edges()
		var local := ""
		for phrase in [" in this area"," around here"," near here"," here"]:
			if body.ends_with(phrase):
				body = body.trim_suffix(phrase)
				local = ";rect=%d,%d,%d,%d" % [int(context.x)-32,int(context.y)-32,int(context.x)+32,int(context.y)+32]
		var r := re("^(?:hide|remove|get rid of|don't show|do not show|show no|show|have|place|put)? ?(?:all |every |the |any )?(.+?)$").search(body)
		var rr := re("^replace (?:all |every |the |any )?(.+?) with (?:an? |some )?(.+)$").search(body)
		if rr:
			var asset := asset_for(rr.get_string(2))
			if asset != 0: return {"understood":true,"rule":{"rule":thing_rule(rr.get_string(1))+local,"action":"replace:%d" % asset},"lines":[],"summary":"persistent rule: replace %s with %s" % [rr.get_string(1),assets[asset]]}
		var hides := never or body.begins_with("hide") or body.begins_with("remove") or body.begins_with("get rid") or body.begins_with("don't show") or body.begins_with("do not show") or body.begins_with("show no")
		if hides and r and singular(r.get_string(1)).strip_edges().split(" ",false).size() <= 2:
			return {"understood":true,"rule":{"rule":thing_rule(r.get_string(1))+local,"action":"hide"},"lines":[],"summary":"persistent rule: never show %s" % r.get_string(1)}
		return {"understood":false,"behaviour":true,"reason":"a behaviour rule changes how the world is reconstructed; Ask Claude to change the converter code"}
	m = re("^(undo|redo)( that| it| the last( edit| change)?)?$").search(t)
	if m: return result([m.get_string(1)],m.get_string(1)+" your latest edit")
	m = re("^save (?:this |these |the edits |it |everything )?(?:as |to )?([a-z0-9-]{1,32})$").search(t)
	if m: return result(["save "+m.get_string(1)],"save the session as edit set "+m.get_string(1))
	m = re("^(?:place|put|add|plant|drop) (a few |some |several |an? |one |two |three |four |five |six |\\d+ )?(.+?)( here| in front of me| next to me| \\d+ tiles? (?:north|south|east|west)(?: of me)?| at \\d+[ ,]+\\d+)?$").search(t)
	if m:
		var asset := asset_for(m.get_string(2))
		if asset == 0: return {"understood":false,"reason":"no approved asset matches '%s'" % m.get_string(2)}
		var count := clampi(amount(m.get_string(1)),1,12)
		var at := point(m.get_string(3),context)
		var across: Vector2 = FACING[(int(context.get("facing",0))+2) & 7]
		var lines: Array = []
		for i in count:
			var offset := across*(float(i)-float(count-1)/2.0)
			lines.append("place %d %s %s %d 0" % [asset,preload("res://DevEdit/DevEditState.gd").number(at.x+offset.x),preload("res://DevEdit/DevEditState.gd").number(at.y+offset.y),context.z])
		return result(lines,"place %d %s at %d,%d" % [count,assets[asset],roundi(at.x),roundi(at.y)])
	m = re("^(raise|lift|lower|sink|dig) (?:the )?(?:ground|terrain|land|earth)(.*?)(?: by (\\d+))?(?: (?:radius|wide|across) (\\d+))?$").search(t)
	if m:
		var at := point(m.get_string(2),context)
		var dz := int(m.get_string(3)) if m.get_string(3) != "" else 4
		if m.get_string(1) in ["lower","sink","dig"]: dz = -dz
		var r := int(m.get_string(4)) if m.get_string(4) != "" else 2
		return result(["brush %d %d %d %d -" % [roundi(at.x),roundi(at.y),mini(r,6),clampi(dz,-40,40)]],"%s the ground by %d at %d,%d (visual only)" % [m.get_string(1),absi(dz),roundi(at.x),roundi(at.y)])
	m = re("^(?:paint|cover|make|turn) (?:the )?(?:ground|terrain|path|street)(.*?) (?:with |into |to )?(dirt|grass|sand|cobblestones|cobbles|forest|brick)(?: (?:radius|wide|across) (\\d+))?$").search(t)
	if m:
		var at := point(m.get_string(1),context)
		var surface := "cobblestones" if m.get_string(2) == "cobbles" else m.get_string(2)
		var r := int(m.get_string(3)) if m.get_string(3) != "" else 2
		return result(["brush %d %d %d 0 %s" % [roundi(at.x),roundi(at.y),mini(r,6),surface]],"paint the ground %s at %d,%d" % [surface,roundi(at.x),roundi(at.y)])
	m = re("^(?:remove|delete|clear) (?:everything |all |the things |the objects )?(?:that )?i (?:placed|added|put)(?: here)?$").search(t)
	if m: return result(["remove all placed;by=%s" % str(context.me).replace(" ","_")],"remove every object you placed")
	m = re("^replace (?:all |every |the )?(.+?)( near me| around me| here| within \\d+ tiles?(?: of me)?| in front of me)? with (?:an? |some )?(.+)$").search(t)
	if m:
		var asset := asset_for(m.get_string(3))
		if asset == 0: return {"understood":false,"reason":"no approved asset matches '%s'" % m.get_string(3)}
		if m.get_string(1) in ["it","them","this","these","the selection","selection","selected"]: return result(["replace all selection %d" % asset],"replace the selection with "+assets[asset])
		return result(["replace all %s;%s %d" % [thing_rule(m.get_string(1)),area(m.get_string(2),context),asset]],"replace %s with %s" % [m.get_string(1),assets[asset]])
	m = re("^(hide|remove|delete|clear|get rid of|restore|bring back|show|select) (?:all |every |the )?(.+?)( near me| around me| here| within \\d+ tiles?(?: of me)?| in front of me)?$").search(t)
	if m:
		var verb := m.get_string(1)
		var thing := m.get_string(2)
		if thing in ["it","them","this","these","the selection","selection","selected"]:
			return result(["%s all selection" % ("restore" if verb in ["restore","bring back","show"] else ("select" if verb == "select" else "hide"))],"%s the selection" % verb)
		var rule := thing_rule(thing)+";"+area(m.get_string(3),context)
		match verb:
			"restore", "bring back", "show": return result(["restore all %s;edited" % rule],"restore hidden/edited %s nearby" % thing)
			"select": return result(["select all "+rule],"select %s nearby" % thing)
		return result(["hide all "+rule],"hide %s nearby (visual only)" % thing)
	m = re("^(?:move|shift|nudge|push) (?:it|them|this|these|the selection|selected|selection)(?: (\\d+(?:\\.\\d+)?) tiles?)? (north|south|east|west|up|down)$").search(t)
	if m:
		var step := float(m.get_string(1)) if m.get_string(1) != "" else 1.0
		var dir := m.get_string(2)
		if dir in ["up","down"]: return result(["shift all selection 0 0 %d" % (roundi(step) if dir == "up" else -roundi(step))],"move the selection %s" % dir)
		var d: Vector2 = DIRECTIONS[dir]*step
		return result(["shift all selection %s %s" % [preload("res://DevEdit/DevEditState.gd").number(d.x),preload("res://DevEdit/DevEditState.gd").number(d.y)]],"move the selection %s %s" % [str(step),dir])
	m = re("^(?:rotate|turn|spin) (?:it|them|this|these|the selection|selected|selection)(?: by)? (-?\\d+)(?: degrees?)?(?: (left|right|clockwise|counterclockwise|counter-clockwise|anticlockwise))?$").search(t)
	if m:
		var degrees := int(m.get_string(1))
		if m.get_string(2) in ["left","counterclockwise","counter-clockwise","anticlockwise"]: degrees = -degrees
		return result(["rotate all selection %d" % degrees],"rotate the selection %d°" % degrees)
	return {"understood":false,"reason":"not a request this offline interpreter knows"}
