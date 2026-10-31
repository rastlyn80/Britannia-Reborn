extends PanelContainer
# The server's context menu (0xBF 0x14) for whatever you clicked: a small
# glass card at the cursor with the creature's or item's name and every
# entry the server offers (greyed when it says so). Choosing sends 0xBF 0x15;
# Esc or a click elsewhere closes it. Replaces the old panel's action list.
# A pet you own (or are a friend of) lists its orders first, under "Orders",
# as plain verbs (Kill, Follow, Guard, Stop, Stay, Drop), then the rest.
# Labels the cliloc leaves blank fall back to their known names.
const FALLBACK := {3006098:"Rename"}
const Look = preload("res://Network/ModernSkin.gd")
var session: Node
var title: Label
var rows: VBoxContainer
var serial := 0

func _ready() -> void:
	theme = Look.theme()
	add_theme_stylebox_override("panel",Look.box(Color(0.055,0.063,0.078,0.97),Color(0.84,0.7,0.43,0.45),12,1,10))
	custom_minimum_size = Vector2(220,0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",4)
	add_child(column)
	title = Label.new()
	title.add_theme_font_override("font",Look.title_font())
	title.add_theme_font_size_override("font_size",15)
	title.add_theme_color_override("font_color",Look.GOLD)
	column.add_child(title)
	var line := ColorRect.new()
	line.color = Color(0.84,0.7,0.43,0.25)
	line.custom_minimum_size = Vector2(0,1)
	column.add_child(line)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation",2)
	column.add_child(rows)
	hide()

func configure(game: Node) -> void:
	session = game
	session.context_received.connect(open)
	session.entity_name_received.connect(func(changed: int, name_text: String): if visible and changed == serial: title.text = name_text)
	session.ended.connect(hide)

func open(menu: Dictionary) -> void:
	if int(session.get_meta("quiet_context",0)) == int(menu.serial):
		session.remove_meta("quiet_context")
		return
	serial = int(menu.serial)
	var named: String = session.module("tooltips").name_of(serial)
	title.text = str(session.entity_names.get(serial,named if named != "" else "Actions"))
	preload("res://Network/ModernWindow.gd").clear(rows)
	var orders: Array = []
	var others: Array = []
	for option in menu.options:
		var text := label_of(int(option.label))
		if text.begins_with("Command: "): orders.append([option,text.substr(9)])
		else: others.append([option,text.capitalize()])
	if not orders.is_empty():
		rows.add_child(_heading("Orders"))
		for entry in orders: rows.add_child(_row(entry[0],entry[1]))
		if not others.is_empty(): rows.add_child(_heading("Pet"))
	for entry in others: rows.add_child(_row(entry[0],entry[1]))
	reset_size()
	var at := get_viewport().get_mouse_position()+Vector2(12,12)
	var room := get_viewport().get_visible_rect().size
	(func():
		reset_size()
		position = Vector2(minf(at.x,room.x-size.x-8),minf(at.y,room.y-size.y-8))).call_deferred()
	show()

func label_of(number: int) -> String:
	var text: String = session.labels.resolve(number)
	if text == "" or text.begins_with("Server label #"): text = FALLBACK.get(number,text)
	return text

func _heading(text: String) -> Label:
	var heading := Look.label(text.to_upper(),10,Look.ASH,700)
	heading.add_theme_constant_override("line_spacing",0)
	return heading

func _row(option: Dictionary, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.flat = true
	button.custom_minimum_size = Vector2(0,34)
	button.disabled = (int(option.flags)&1) != 0
	button.add_theme_stylebox_override("hover",Look.box(Color(0.84,0.7,0.43,0.16),Color(0,0,0,0),6,0,6))
	button.add_theme_color_override("font_color",Look.IVORY)
	button.add_theme_color_override("font_disabled_color",Look.DIM)
	button.pressed.connect(func():
		session.choose_context(int(option.index))
		hide())
	return button

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not get_global_rect().has_point(event.position):
		hide()
