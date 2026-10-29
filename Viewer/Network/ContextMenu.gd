extends PanelContainer
# The server's context menu (0xBF 0x14) for whatever you clicked: a small
# glass card at the cursor with the creature's or item's name and every
# entry the server offers (greyed when it says so). Choosing sends 0xBF 0x15;
# Esc or a click elsewhere closes it. Replaces the old panel's action list.
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
	for option in menu.options:
		var button := Button.new()
		button.text = str(session.labels.resolve(int(option.label))).capitalize()
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
		rows.add_child(button)
	reset_size()
	var at := get_viewport().get_mouse_position()+Vector2(12,12)
	var room := get_viewport().get_visible_rect().size
	(func():
		reset_size()
		position = Vector2(minf(at.x,room.x-size.x-8),minf(at.y,room.y-size.y-8))).call_deferred()
	show()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not get_global_rect().has_point(event.position):
		hide()
