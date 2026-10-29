extends PanelContainer
# When the server puts you somewhere the 3D world has not been converted yet
# (another facet: Felucca, Ilshenar, Malas, Tokuno, Ter Mur), a banner says
# where you are and points to the world map, which has every facet. The
# protocol carries the facet (0xBF 0x08); the 3D data for it is world
# pipeline work.
const Look = preload("res://Network/ModernSkin.gd")
const NAMES := {0:"Felucca",1:"Trammel",2:"Ilshenar",3:"Malas",4:"Tokuno",5:"Ter Mur"}
var game: Node
var text: Label

func _ready() -> void:
	add_theme_stylebox_override("panel",Look.box(Color(0.055,0.063,0.078,0.92),Color(0.84,0.7,0.43,0.5),12,1,14))
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_top = 120
	offset_left = -300
	offset_right = 300
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = Look.label("",15,Look.IVORY,600)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(text)
	hide()

func configure(session: Node) -> void:
	game = session

func _process(_delta: float) -> void:
	if game == null: return
	var facet := int(game.player.get("facet",1))
	var away: bool = game.phase == "world" and facet != 1
	if away:
		text.text = "You are in %s. This facet is not built in 3D yet; the world map (M) shows where you are." % NAMES.get(facet,"another facet")
	visible = away
