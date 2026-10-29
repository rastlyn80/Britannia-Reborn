extends PanelContainer
# Shown above the quickbar while the server waits for a target: Self answers
# with yourself, Esc (World.gd) or the button cancels. Replaces the
# old panel's "Use on yourself / Cancel action".
const Look = preload("res://Network/ModernSkin.gd")
var session: Node
var text: Label

func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -196
	add_theme_stylebox_override("panel",Look.box(Color(0.055,0.063,0.078,0.95),Look.BRASS,22,1,6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	add_child(row)
	var mark := TextureRect.new()
	mark.texture = Look.icon("target",Look.GOLD,20)
	mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(mark)
	text = Look.label("Choose a target",14,Look.IVORY,600)
	row.add_child(text)
	var self_button := Button.new()
	self_button.text = "Self"
	self_button.focus_mode = Control.FOCUS_NONE
	self_button.add_theme_stylebox_override("normal",Look.box(Look.BRASS,Look.BRASS,14,1,6))
	self_button.add_theme_color_override("font_color",Color("17140e"))
	self_button.pressed.connect(func(): session.target_item(int(session.player.serial)))
	row.add_child(self_button)
	var cancel := Button.new()
	cancel.text = "Esc"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func(): session.target_item())
	row.add_child(cancel)
	hide()

func configure(game: Node) -> void:
	session = game
	session.target_changed.connect(func(active: bool):
		visible = active
		)
	session.ended.connect(hide)

