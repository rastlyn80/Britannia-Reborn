extends Control
# Death (0x2C death status, ghost bodies 402/403): "You have died" over a
# darkened screen, which after a few seconds settles into a quiet grey veil
# with a short reminder while you walk as a ghost. Resurrection (back to a
# living body) lifts it. The server's resurrection offers arrive as gumps.
const Look = preload("res://Network/ModernSkin.gd")
const GHOSTS := [402,403,607,608,970]
var session: Node
var veil := ColorRect.new()
var title: Label
var hint: Label
var dead := false
var since := 0
var died_at := -100000

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.color = Color(0.04,0.045,0.06,0.0)
	add_child(veil)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	column.offset_top = 210
	column.offset_left = -360
	column.offset_right = 360
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	title = Label.new()
	title.text = "You have died"
	title.add_theme_font_override("font",Look.title_font())
	title.add_theme_font_size_override("font_size",54)
	title.add_theme_color_override("font_color",Color("e7d9c0"))
	title.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
	title.add_theme_constant_override("shadow_offset_y",3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	hint = Look.label("Your spirit lingers. Seek a healer or a shrine to return to life.",16,Look.ASH,500)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	modulate.a = 0.0
	hide()

func configure(game: Node) -> void:
	session = game
	# The death status may come just before the ghost body: it holds for a
	# few seconds, after which the body alone decides.
	session.module("player").died.connect(func(is_dead: bool):
		if is_dead:
			died_at = Time.get_ticks_msec()
			_set_dead(true))
	session.entity_changed.connect(func(serial: int, _p: Dictionary):
		if serial != int(session.player.get("serial",0)): return
		var ghost := int(session.player.get("body",0)) in GHOSTS
		_set_dead(ghost or Time.get_ticks_msec()-died_at < 5000))
	session.ended.connect(func(): _set_dead(false))

func _set_dead(is_dead: bool) -> void:
	if is_dead == dead: return
	dead = is_dead
	if dead:
		since = Time.get_ticks_msec()
		show()
	var fade := create_tween()
	fade.tween_property(self,"modulate:a",1.0 if dead else 0.0,1.2 if dead else 0.8)
	if not dead: fade.tween_callback(hide)

func _process(_delta: float) -> void:
	if not dead: return
	# Darkest at the moment of death, then a light veil while a ghost.
	var age := (Time.get_ticks_msec()-since)/1000.0
	var settle := clampf((age-3.5)/2.0,0.0,1.0)
	veil.color.a = lerpf(0.62,0.18,settle)
	title.add_theme_font_size_override("font_size",int(lerpf(54,30,settle)))
	title.modulate.a = lerpf(1.0,0.55,settle)
	hint.modulate.a = lerpf(1.0,0.7,settle)
