extends "res://Network/ModernWindow.gd"
# The helm: opens when you board a boat and closes when you leave it; drag it
# anywhere like the other windows (its place is remembered). Arrows sail in
# eight directions relative to the bow, with turn left/right, come about,
# stop, anchor and a slow toggle. Each control speaks the tillerman's order
# ("forward left", "raise anchor"...), sent with its speech keywords as
# ModernUO expects, so the server decides and the tillerman answers.
const Ships = preload("res://Presentation/ShipBuilder.gd")
const Multis = preload("res://Presentation/MultiPresenter.gd")
const ActionProtocol = preload("res://Network/ActionProtocol.gd")
var game: Node
var slow: CheckButton
var anchor: Button
var anchored := true
var was_aboard := 0

func _ready() -> void:
	setup("helm","Helm",Vector2(340,0),Vector2(630,470))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation",4)
	pad.add_theme_constant_override("v_separation",4)
	row.add_child(pad)
	# Bow is up: the arrows read as the ship sees them.
	for order in [["↖","forward left"],["↑","forward"],["↗","forward right"],["←","left"],["■","stop"],["→","right"],["↙","back left"],["↓","back"],["↘","back right"]]:
		var button := Button.new()
		button.text = order[0]
		button.tooltip_text = str(order[1]).capitalize()
		button.custom_minimum_size = Vector2(46,40)
		button.add_theme_font_size_override("font_size",18)
		if order[1] == "stop": button.add_theme_color_override("font_color",Look.AMBER)
		button.pressed.connect(func(): say(str(order[1]),order[1] != "stop"))
		pad.add_child(button)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation",4)
	row.add_child(side)
	for order in [["Turn left","turn left"],["Turn right","turn right"],["Come about","come about"]]:
		var button := Button.new()
		button.text = order[0]
		button.custom_minimum_size = Vector2(120,30)
		button.pressed.connect(func(): say(str(order[1])))
		side.add_child(button)
	anchor = Button.new()
	anchor.custom_minimum_size = Vector2(120,30)
	anchor.pressed.connect(func():
		say("raise anchor" if anchored else "drop anchor")
		anchored = not anchored
		_anchor_label())
	side.add_child(anchor)
	slow = CheckButton.new()
	slow.text = "Slow"
	side.add_child(slow)
	_anchor_label()

func configure(session: Node) -> void:
	game = session
	game.message_received.connect(func(text: String):
		# The tillerman's answers keep the anchor button honest.
		var lower := text.to_lower()
		if "anchor raised" in lower or "anchor is already raised" in lower or "anchor is up" in lower or "has not been dropped" in lower: anchored = false
		elif "anchor dropped" in lower or "anchor is down" in lower or "anchor is already dropped" in lower or "has not been raised" in lower: anchored = true
		_anchor_label())
	game.ended.connect(hide)

func _anchor_label() -> void:
	if anchor: anchor.text = "Raise anchor" if anchored else "Drop anchor"

# Movement orders take "slow" in front when the toggle is on (ModernUO keywords).
func say(order: String, moving := false) -> void:
	var line := ("slow " if moving and slow.button_pressed else "")+order
	game.send(ActionProtocol.speech(line))

func aboard() -> int:
	var me := Vector2i(int(game.player.get("x",0)),int(game.player.get("y",0)))
	for serial in game.multis:
		var multi: Dictionary = game.multis[serial]
		if not Ships.handles(int(multi.id)): continue
		var box := Multis.bounds(int(multi.id))
		if Rect2i(box.position,box.size+Vector2i.ONE).has_point(me-Vector2i(int(multi.x),int(multi.y))): return int(serial)
	return 0

# Opens on boarding and closes on leaving; closed by hand, it stays closed
# until you next board.
func _process(_delta: float) -> void:
	if game == null: return
	var boat := aboard() if game.phase == "world" else 0
	if boat != was_aboard:
		if boat and not visible: toggle()
		elif not boat: hide()
		was_aboard = boat
