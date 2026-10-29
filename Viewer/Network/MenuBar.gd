extends PanelContainer
# Bottom-right window menu: one button per window with its key, so every
# window is a click or a key away (Character C, Backpack B, Skills K,
# Spellbook P, Journal J, Map M), and the game menu (Esc).
signal chosen(window: String)
const Look = preload("res://Network/ModernSkin.gd")
const ENTRIES := [["character","Character","C","user"],["backpack","Backpack","B","bag"],["skills","Skills","K","skills"],["spellbook","Spellbook","P","book"],["journal","Journal","J","chat"],["map","World map","M","map"],["menu","Game menu","Esc","gear"]]
const KEYS := {KEY_B:"backpack",KEY_K:"skills",KEY_P:"spellbook",KEY_J:"journal",KEY_M:"map"}

func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -20
	offset_bottom = -20
	add_theme_stylebox_override("panel",Look.box(Look.NIGHT,Look.EDGE,12,1,6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	add_child(row)
	for entry in ENTRIES:
		var b := preload("res://Network/MenuButtonKey.gd").new()
		b.key_text = entry[2]
		b.icon = Look.icon(entry[3],Look.IVORY,22)
		b.tooltip_text = "%s (%s)" % [entry[1],entry[2]]
		b.custom_minimum_size = Vector2(48,48)
		b.focus_mode = Control.FOCUS_NONE
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_stylebox_override("normal",Look.box(Color(1,1,1,0.04),Color(0.84,0.7,0.43,0.2),8,1,4))
		b.add_theme_stylebox_override("hover",Look.box(Color(0.84,0.7,0.43,0.16),Look.BRASS,8,1,4))
		b.add_theme_stylebox_override("pressed",Look.box(Color(0.84,0.7,0.43,0.26),Look.BRASS,8,1,4))
		b.pressed.connect(func(): chosen.emit(entry[0]))
		row.add_child(b)
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.ctrl_pressed or event.alt_pressed or event.shift_pressed: return
	if KEYS.has(event.keycode):
		chosen.emit(KEYS[event.keycode])
		get_viewport().set_input_as_handled()
