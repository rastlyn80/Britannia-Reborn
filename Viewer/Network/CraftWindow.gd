extends "res://Network/ModernWindow.gd"
# Crafting (ModernUO CraftGump, every trade): the server's craft gump read by
# its button scheme (id = 1 + type + index*7) and shown as a modern window:
# categories on the left, the selection as cards with each item's 3D icon
# (most craft names are the item's own "1020000 + graphic" cliloc), and the
# actions along the bottom: make last, material choice, smelt, repair,
# enhance, maker's mark, and the server's notices. Every click answers the
# server's gump, which sends the next page; the generic gump stays hidden.
const Studio = preload("res://Presentation/ItemStudio.gd")
const Artwork = preload("res://Network/Artwork.gd")
const MISC := {0:"Material",1:"Smelt item",2:"Make last",3:"Last ten",4:"Use material colour",5:"Repair item",6:"Maker's mark",7:"Material",8:"Enhance item"}
var session: Node
var gump := {}
var title_text: Label
var notice: Label
var groups := VBoxContainer.new()
var grid := GridContainer.new()
var actions := HBoxContainer.new()

static func button_id(type: int, index: int) -> int: return 1+type+index*7

# A craft gump: the "CATEGORIES" and "SELECTIONS" headings (1044010/1044011).
static func is_craft(value: Dictionary) -> bool:
	var marks := 0
	for command in value.get("commands",[]):
		if str(command[0]) == "xmfhtmlgump" and command.size() > 5 and int(command[5]) in [1044010,1044011]: marks += 1
	return marks >= 2

func _ready() -> void:
	setup("craft","Crafting",Vector2(940,600),Vector2(320,90))
	title_text = Look.label("",15,Look.GOLD,600)
	body.add_child(title_text)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation",14)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(split)
	var left := ScrollContainer.new()
	left.custom_minimum_size = Vector2(220,0)
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(left)
	groups.add_theme_constant_override("separation",4)
	groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(groups)
	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(right)
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	right.add_child(grid)
	notice = Look.label("",14,Color("f3dca2"),500)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(notice)
	actions.add_theme_constant_override("separation",8)
	body.add_child(actions)
	visibility_changed.connect(func():
		if not visible and not gump.is_empty() and session and session.gumps.has(int(gump.type)):
			session.respond_gump(gump,0)
			gump = {})

func configure(game: Node) -> void:
	session = game
	session.gump_received.connect(func(value: Dictionary): if is_craft(value): open(value))
	session.gump_closed.connect(func(type: int): if not gump.is_empty() and int(gump.type) == type: _close())
	session.ended.connect(_close)
	if Studio.instance: Studio.instance.icon_ready.connect(func(_g: int,_h: int,_t: Texture2D): if visible: _render())

func _close() -> void:
	gump = {}
	hide()

func open(value: Dictionary) -> void:
	gump = value
	_hide_generic.call_deferred(int(value.type))
	_render()
	show()
	move_to_front()

# The generic window the session layer made for this gump is not shown.
func _hide_generic(type: int) -> void:
	for view in get_tree().root.find_children("*","",true,false):
		if view.get_script() == preload("res://Network/GumpView.gd") and int(view.data.get("type",-1)) == type: view.queue_free()

# Text of a label command, and where it sits.
func _label(command: Array) -> Dictionary:
	var name := str(command[0])
	var text := ""
	match name:
		"xmfhtmlgump","xmfhtmlgumpcolor": text = session.labels.resolve(int(command[5]))
		"xmfhtmltok": text = session.labels.resolve(int(command[7]),str(command[9]).trim_prefix("@").trim_suffix("@") if command.size() > 9 else "")
		"htmlgump": text = str(gump.texts[int(command[5])]) if int(command[5]) < gump.texts.size() else ""
		"text": text = str(gump.texts[int(command[4])]) if int(command[4]) < gump.texts.size() else ""
		_: return {}
	var cliloc := int(command[5]) if name.begins_with("xmfhtml") and name != "xmfhtmltok" else (int(command[7]) if name == "xmfhtmltok" else 0)
	return {"x":int(command[1]),"y":int(command[2]),"text":preload("res://Network/GumpView.gd").plain_html(text).strip_edges(),"cliloc":cliloc}

func _parse() -> Dictionary:
	var buttons: Array = []
	var labels: Array = []
	for command in gump.commands:
		var name := str(command[0])
		if name == "button" and command.size() >= 8 and int(command[5]) == 1: buttons.append({"x":int(command[1]),"y":int(command[2]),"id":int(command[7])})
		else:
			var found := _label(command)
			if not found.is_empty(): labels.append(found)
	var label_for := func(button: Dictionary) -> Dictionary:
		for label in labels:
			if absi(int(label.y)-int(button.y)) <= 5 and int(label.x) > int(button.x) and int(label.x)-int(button.x) <= 45: return label
		return {}
	var result := {"title":"","notice":"","groups":[],"items":[],"misc":[],"details":{},"resources":[]}
	for label in labels:
		if int(label.x) == 10 and int(label.y) == 12: result.title = label.text
		if int(label.x) == 170 and int(label.y) == 295: result.notice = label.text
	for button in buttons:
		var id: int = int(button.id)
		if id == 0: continue
		var type := (id-1)%7
		var index := (id-1)/7
		var label: Dictionary = label_for.call(button)
		match type:
			0: result.groups.append({"id":id,"text":label.get("text","")})
			1, 3: result.items.append({"id":id,"index":index,"type":type,"text":label.get("text",""),"cliloc":int(label.get("cliloc",0))})
			2, 4: result.details[index*10+type] = id
			5: result.resources.append({"id":id,"text":label.get("text","")})
			6: result.misc.append({"id":id,"index":index,"text":label.get("text","") if label.get("text","") != "" else str(MISC.get(index,""))})
	return result

func _reply(id: int) -> void:
	if gump.is_empty(): return
	var answered := gump
	gump = {}
	session.respond_gump(answered,id)

func _render() -> void:
	if gump.is_empty() or session == null: return
	var parsed := _parse()
	title_text.text = str(parsed.title).capitalize() if str(parsed.title) != "" else "Crafting"
	title_label.text = "Crafting"
	notice.text = str(parsed.notice)
	clear(groups)
	clear(grid)
	clear(actions)
	for group in parsed.groups:
		var b := Button.new()
		b.text = str(group.text).capitalize()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0,34)
		b.pressed.connect(_reply.bind(int(group.id)))
		groups.add_child(b)
	for misc in parsed.misc:
		if int(misc.index) == 3:
			var last := Button.new()
			last.text = "Last ten made"
			last.alignment = HORIZONTAL_ALIGNMENT_LEFT
			last.custom_minimum_size = Vector2(0,34)
			last.pressed.connect(_reply.bind(int(misc.id)))
			groups.add_child(last)
			groups.move_child(last,0)
	var entries: Array = parsed.items if not parsed.items.is_empty() else parsed.resources
	for entry in entries:
		grid.add_child(_card(entry,parsed.details.get(int(entry.get("index",-1))*10+int(entry.get("type",1))+1,0)))
	if entries.is_empty(): grid.add_child(Look.label("Choose a category.",14,Look.ASH,500))
	for misc in parsed.misc:
		if int(misc.index) == 3: continue
		var b := Button.new()
		b.text = str(misc.text).capitalize()
		b.custom_minimum_size = Vector2(0,40)
		if int(misc.index) == 2:
			b.add_theme_stylebox_override("normal",Look.box(Look.BRASS,Look.BRASS,8,1,8))
			b.add_theme_color_override("font_color",Color("14110b"))
		b.pressed.connect(_reply.bind(int(misc.id)))
		actions.add_child(b)

static func graphic_of(cliloc: int) -> int:
	return cliloc-1020000 if cliloc >= 1020000 and cliloc < 1040000 else 0

func _card(entry: Dictionary, details: int) -> Control:
	var card := Button.new()
	card.custom_minimum_size = Vector2(150,128)
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal",Look.box(Color(1,1,1,0.03),Color(0.84,0.7,0.43,0.18),10,1,8))
	card.add_theme_stylebox_override("hover",Look.box(Color(0.84,0.7,0.43,0.12),Look.BRASS,10,1,8))
	card.tooltip_text = "%s\nClick to make" % entry.text
	card.pressed.connect(_reply.bind(int(entry.id)))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 6
	column.offset_right = -6
	column.offset_top = 6
	card.add_child(column)
	var graphic := graphic_of(int(entry.get("cliloc",0)))
	var art := TextureRect.new()
	if graphic:
		var rendered := Studio.lookup(graphic,0)
		art.texture = rendered if rendered else Artwork.item(graphic,0)
	if art.texture == null: art.texture = Look.icon("star",Look.DIM,40)
	art.custom_minimum_size = Vector2(0,70)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(art)
	var name := Look.label(str(entry.text).capitalize(),12,Look.IVORY,600)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name)
	if details:
		var info := Button.new()
		info.text = "i"
		info.tooltip_text = "Materials and skill"
		info.custom_minimum_size = Vector2(24,24)
		info.position = Vector2(120,4)
		info.focus_mode = Control.FOCUS_NONE
		info.pressed.connect(_reply.bind(details))
		card.add_child(info)
	return card
