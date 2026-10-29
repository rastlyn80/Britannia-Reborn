extends PanelContainer
# Shard state above the minimap: Online (green), Connecting (amber) or
# Disconnected (red), with the facet and nearest town. Replaces the old
# panel's "Online / Trammel" status line.
const Look = preload("res://Network/ModernSkin.gd")
const Looks = preload("res://Network/CharacterLooks.gd")
var session: Node
var dot := Label.new()
var text: Label
var clock := 0.0

func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -20
	offset_bottom = -370
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel",Look.box(Look.NIGHT,Look.EDGE,999,1,6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	add_child(row)
	dot.text = "●"
	dot.add_theme_font_size_override("font_size",12)
	row.add_child(dot)
	text = Look.label("",12,Look.IVORY,600)
	row.add_child(text)
	hide()

func configure(game: Node) -> void:
	session = game

func _process(delta: float) -> void:
	clock -= delta
	if clock > 0.0 or session == null: return
	clock = 0.5
	var state: String = session.phase
	visible = state != "idle"
	var colour := Look.HERB
	var words := ""
	match state:
		"world":
			words = "Online · %s" % Looks.place(int(session.player.get("x",0)),int(session.player.get("y",0)))
		"login","connecting","characters_pending","characters","entering":
			colour = Look.AMBER
			words = "Connecting"
		_:
			colour = Look.BLOOD
			words = "Disconnected"
	dot.add_theme_color_override("font_color",colour)
	if text.text != words:
		text.text = words
