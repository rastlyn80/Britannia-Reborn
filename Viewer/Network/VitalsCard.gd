extends PanelContainer
# Top-left vitals card: name, attributes, gold and weight, and hits, stamina
# and mana bars with their numbers (hits turn green while poisoned). Clicking
# it opens the character sheet.
signal opened
const Look = preload("res://Network/ModernSkin.gd")
const Frame = preload("res://Network/ModernWindow.gd")
var session: Node
var portrait := Label.new()
var name_label: Label
var detail: Label
var purse: Label
var bars := {}
var numbers := {}
# Peace/War switch (replaces the old panel's war toggle).
var stance := Button.new()

func _ready() -> void:
	position = Vector2(20,20)
	custom_minimum_size = Vector2(360,0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Character (C)"
	add_theme_stylebox_override("panel",Look.box(Look.NIGHT,Look.EDGE,12,1,12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",7)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation",10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	portrait.custom_minimum_size = Vector2(46,46)
	portrait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait.add_theme_font_override("font",Look.title_font())
	portrait.add_theme_font_size_override("font_size",20)
	portrait.add_theme_color_override("font_color",Look.BRASS)
	var ring := Look.box(Color("2b3138"),Look.BRASS,23,2,0)
	portrait.add_theme_stylebox_override("normal",ring)
	head.add_child(portrait)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation",0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	name_label = Label.new()
	name_label.add_theme_font_override("font",Look.title_font())
	name_label.add_theme_font_size_override("font_size",18)
	name_label.add_theme_color_override("font_color",Color("f3ebd9"))
	names.add_child(name_label)
	detail = Look.label("",12,Look.ASH,500)
	names.add_child(detail)
	stance.focus_mode = Control.FOCUS_NONE
	stance.custom_minimum_size = Vector2(64,26)
	stance.add_theme_font_override("font",Look.ui_font(700))
	stance.add_theme_font_size_override("font_size",11)
	stance.tooltip_text = "Switch between peace and war"
	stance.pressed.connect(func(): session.set_war_mode((int(session.player.get("flags",0))&0x40)==0))
	purse = Look.label("",12,Look.ASH,500)
	purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(purse)
	var stance_box := VBoxContainer.new()
	stance_box.alignment = BoxContainer.ALIGNMENT_CENTER
	stance_box.add_child(stance)
	head.add_child(stance_box)
	for entry in [["hits","HITS",Look.BLOOD],["stam","STAM",Look.AMBER],["mana","MANA",Look.SKY]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation",8)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(line)
		var tag := Look.label(entry[1],11,Look.ASH,700)
		tag.custom_minimum_size = Vector2(40,0)
		line.add_child(tag)
		var bar := Frame.meter(entry[2],12)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(bar)
		bars[entry[0]] = bar
		var number := Look.label("",12,Look.IVORY,600)
		number.custom_minimum_size = Vector2(70,0)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(number)
		numbers[entry[0]] = number
	hide()

func configure(game: Node) -> void:
	session = game
	session.status_changed.connect(func(_s: Dictionary): refresh())
	session.entity_changed.connect(func(serial: int, _p: Dictionary): if serial == int(session.player.get("serial",0)): refresh())
	session.entered.connect(func(_p: Dictionary):
		show()
		session.request_character()
		refresh())
	session.ended.connect(hide)

func refresh() -> void:
	var s: Dictionary = session.player_status
	var name := str(s.get("name",session.entity_names.get(int(session.player.get("serial",0)),"")))
	name_label.text = name
	portrait.text = name.left(1).to_upper()
	detail.text = "Str %d · Dex %d · Int %d" % [int(s.get("str",0)),int(s.get("dex",0)),int(s.get("int",0))] if s.has("str") else ""
	purse.text = "%s gold\n%d / %d st" % [_grouped(int(s.get("gold",0))),int(s.get("weight",0)),int(s.get("weight_max",0))] if s.has("gold") else ""
	var poisoned := (int(session.player.get("flags",0)) & 0x04) != 0 or bool(s.get("poisoned",false))
	var war := (int(session.player.get("flags",0)) & 0x40) != 0
	stance.text = "War" if war else "Peace"
	var tone: Color = Look.BLOOD if war else Look.HERB
	for state in ["normal","hover","pressed"]: stance.add_theme_stylebox_override(state,Look.box(Color(tone.r,tone.g,tone.b,0.16 if state == "normal" else 0.28),Color(tone.r,tone.g,tone.b,0.6),13,1,4))
	stance.add_theme_color_override("font_color",tone.lightened(0.3))
	stance.add_theme_color_override("font_hover_color",tone.lightened(0.45))
	for key in bars:
		var top := maxi(1,int(s.get(key+"_max",0)))
		bars[key].max_value = top
		bars[key].value = int(s.get(key,0))
		numbers[key].text = "%d / %d" % [int(s.get(key,0)),int(s.get(key+"_max",0))] if s.has(key) else "—"
	bars.hits.add_theme_stylebox_override("fill",Look.box(Color("6dbe5a") if poisoned else Look.BLOOD,Color(0,0,0,0),6,0,0))

static func _grouped(value: int) -> String:
	var text := str(value)
	var out := ""
	while text.length() > 3:
		out = ","+text.right(3)+out
		text = text.left(text.length()-3)
	return text+out

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# A waiting target cursor (a spell, a bandage) takes you; otherwise
		# the card opens your character sheet.
		if session != null and not session.target_request.is_empty(): preload("res://Network/ActionRunner.gd").target_entity(session,int(session.player.get("serial",0)))
		else: opened.emit()
		accept_event()
