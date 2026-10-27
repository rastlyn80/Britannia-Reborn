extends PanelContainer
# Compact player vitals (hits, stamina, mana) from native status packets.
# Clicking it opens the character sheet.
const UiLook = preload("res://Network/UiSkin.gd")
signal opened
var session: Node
var name_label := Label.new()
var bars := {}
var amounts := {}

func configure(game: Node) -> void:
	session = game
	session.status_changed.connect(func(_status: Dictionary): refresh())
	session.entered.connect(func(_position: Dictionary): show())
	session.ended.connect(func(): hide())

func _ready() -> void:
	position = Vector2(16,16)
	custom_minimum_size = Vector2(260,0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Character sheet (C)"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09,0.07,0.05,0.82)
	style.border_color = Color("8a6d3b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",4)
	add_child(column)
	name_label.add_theme_font_override("font",UiLook.heading_font())
	name_label.add_theme_font_size_override("font_size",20)
	name_label.add_theme_color_override("font_color",UiLook.TITLE)
	column.add_child(name_label)
	for entry in [["hits",Color("b52e22")],["stam",Color("c09a26")],["mana",Color("3466c0")]]:
		var line := HBoxContainer.new()
		var bar := UiLook.meter(entry[1])
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(bar)
		var amount := Label.new()
		amount.custom_minimum_size = Vector2(70,0)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount.add_theme_font_size_override("font_size",13)
		amount.add_theme_color_override("font_color",Color("e8dcc0"))
		line.add_child(amount)
		column.add_child(line)
		bars[entry[0]] = bar
		amounts[entry[0]] = amount
	hide()

func refresh() -> void:
	var s: Dictionary = session.player_status
	name_label.text = str(s.get("name",""))
	for key in bars:
		var maximum := int(s.get(key+"_max",0))
		bars[key].max_value = maxi(1,maximum)
		bars[key].value = int(s.get(key,0))
		amounts[key].text = "%d / %d" % [int(s.get(key,0)),maximum] if maximum > 0 else ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		opened.emit()
		accept_event()
