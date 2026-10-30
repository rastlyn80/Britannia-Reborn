extends "res://Network/ModernWindow.gd"
# Developer console (`): server commands ([PreviewCommands, [PreviewWhere…)
# with their replies, a command history (Up/Down) and quick buttons. Replaces
# the old panel's "Server commands" box.
var session: Node
var input := LineEdit.new()
var log_view := RichTextLabel.new()
var history: Array = []
var recall := 0

func _ready() -> void:
	setup("console","Console",Vector2(520,340),Vector2(460,120))
	right_click_closes = false
	log_view.custom_minimum_size = Vector2(0,190)
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view.bbcode_enabled = true
	log_view.scroll_following = true
	log_view.selection_enabled = true
	log_view.add_theme_font_size_override("normal_font_size",13)
	log_view.add_theme_color_override("default_color",Look.IVORY)
	body.add_child(log_view)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	body.add_child(row)
	input.placeholder_text = "[PreviewCommands"
	input.custom_minimum_size = Vector2(0,38)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_submitted.connect(func(_t: String): submit())
	input.gui_input.connect(_recall)
	row.add_child(input)
	var run := Button.new()
	run.text = "Run"
	run.custom_minimum_size = Vector2(70,38)
	run.pressed.connect(submit)
	row.add_child(run)
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation",6)
	body.add_child(quick)
	for entry in [["Where am I","[PreviewWhere"],["Commands","[PreviewCommands"]]:
		var b := chip(entry[0])
		b.pressed.connect(func(): send(entry[1]))
		quick.add_child(b)
	var home := chip("Return to Britain")
	home.pressed.connect(func(): session.return_to_britain())
	quick.add_child(home)

func configure(game: Node) -> void:
	session = game
	session.message_received.connect(func(text: String):
		log_view.append_text(text.replace("[","[lb]")+"\n")
		if log_view.get_paragraph_count() > 400: log_view.remove_paragraph(0))

func open() -> void:
	show()
	input.grab_focus.call_deferred()

func submit() -> void:
	var command := input.text.strip_edges()
	if command.is_empty(): return
	send(command)
	input.clear()

func send(command: String) -> void:
	if session.send_command(command):
		log_view.append_text("[color=#e2c27a]› %s[/color]\n" % command.replace("[","[lb]"))
		history.append(command)
		recall = history.size()
	else: log_view.append_text("[color=#f0a59b]Commands begin with [lb] and are at most 128 characters.[/color]\n")

func _recall(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or history.is_empty(): return
	if event.keycode == KEY_UP: recall = maxi(0,recall-1)
	elif event.keycode == KEY_DOWN: recall = mini(history.size(),recall+1)
	else: return
	input.text = history[recall] if recall < history.size() else ""
	input.caret_column = input.text.length()
	input.accept_event()
