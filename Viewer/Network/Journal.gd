extends PanelContainer
# Bottom-left journal and chat: what the server tells you and the quickbar's
# notes, filterable, with a talk line. Enter starts
# typing; plain text is said aloud, and /e emote, /w whisper, /y yell,
# /p party; "[" sends a server command. Escape stops typing.
const Look = preload("res://Network/ModernSkin.gd")
const Protocol = preload("res://Network/ActionProtocol.gd")
const KEEP := 200
var session: Node
var tabs := {}
var tab := "All"
var log := RichTextLabel.new()
var input := LineEdit.new()
var mode_label: Label
var entries := []

func _ready() -> void:
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 20
	offset_right = 540
	offset_top = -280
	offset_bottom = -20
	theme = Look.theme()
	add_theme_stylebox_override("panel",Look.box(Color(0.055,0.063,0.078,0.78),Color(0.84,0.7,0.43,0.25),12,1,10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	add_child(column)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation",4)
	column.add_child(bar)
	for name in ["All","Server","Party","Chat","Quickbar"]:
		var b := preload("res://Network/ModernWindow.gd").chip(name,name == tab)
		b.pressed.connect(func():
			tab = name
			for other in tabs: tabs[other].set_pressed_no_signal(other == tab)
			_render())
		bar.add_child(b)
		tabs[name] = b
	log.bbcode_enabled = true
	log.scroll_following = true
	log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log.add_theme_font_override("normal_font",Look.ui_font(500))
	log.add_theme_font_override("bold_font",Look.ui_font(700))
	log.add_theme_font_size_override("normal_font_size",13)
	log.add_theme_font_size_override("bold_font_size",13)
	log.add_theme_color_override("default_color",Color("dcd5c5"))
	column.add_child(log)
	var talk := HBoxContainer.new()
	talk.add_theme_constant_override("separation",6)
	column.add_child(talk)
	mode_label = Look.label("Say",12,Look.GOLD,700)
	mode_label.custom_minimum_size = Vector2(44,0)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	talk.add_child(mode_label)
	input.placeholder_text = "Enter to talk · /e emote · /w whisper · /y yell · /p party"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.max_length = 128
	input.text_changed.connect(func(text: String): mode_label.text = _mode(text)[0])
	input.text_submitted.connect(_submit)
	talk.add_child(input)
	hide()

var speech := {}

func configure(game: Node) -> void:
	session = game
	# Spoken lines come with their speaker just before the text itself: the
	# journal names the speaker, in the same colour as the overhead text.
	session.speech_received.connect(func(serial: int, text: String, type: int, hue: int): speech = {"serial":serial,"text":text,"type":type,"hue":hue})
	session.message_received.connect(func(text: String):
		if not speech.is_empty() and str(speech.text) == text and int(speech.type) not in [1,6,7] and int(speech.serial) not in [0,0xffffffff]:
			var serial := int(speech.serial)
			var own := serial == int(session.player.get("serial",0))
			var name := str(session.entity_names.get(serial,""))
			var shown := ("*%s*" % text) if int(speech.type) == 2 and not text.begins_with("*") else text
			add("%s: %s" % [name,shown] if name != "" else shown,"Chat",preload("res://Network/OverheadText.gd").voice(serial,int(speech.hue),own))
		else: add(text,"Server")
		speech = {})
	if session.has_method("module"):
		var social: RefCounted = session.module("social")
		social.party_message.connect(func(serial: int, text: String, private: bool): add("%s%s: %s" % ["(private) " if private else "",session.entity_names.get(serial,"Member"),text],"Party"))
		social.chat.connect(func(command: int, first: String, second: String): add(" ".join([first,second]).strip_edges() if first != "" or second != "" else "Chat %d" % command,"Chat"))
	session.entered.connect(func(_p: Dictionary): show())
	session.ended.connect(func():
		input.release_focus()
		hide())

func add(text: String, kind: String, colour := Color(0,0,0,0)) -> void:
	entries.append([Time.get_time_string_from_system().left(5),kind,text,colour])
	if entries.size() > KEEP: entries = entries.slice(entries.size()-KEEP)
	_render()

func _render() -> void:
	var lines := []
	for entry in entries:
		if tab != "All" and entry[1] != tab: continue
		var color: String = {"Server":"eee7d7","Quickbar":"8fc1ff"}.get(entry[1],"dcd5c5")
		if entry.size() > 3 and entry[3].a > 0.0: color = entry[3].to_html(false)
		lines.append("[color=#7d776b]%s[/color] [color=#%s]%s[/color]" % [entry[0],color,str(entry[2]).replace("[","[lb]")])
	log.text = "\n".join(lines)

static func _mode(text: String) -> Array:
	for prefix in [["/e ","Emote"],["/w ","Whisper"],["/y ","Yell"],["/p ","Party"]]:
		if text.begins_with(prefix[0]): return [prefix[1],text.substr(3)]
	if text.begins_with("["): return ["Cmd",text]
	return ["Say",text]

func _submit(text: String) -> void:
	var mode := _mode(text.strip_edges())
	input.clear()
	mode_label.text = "Say"
	input.release_focus()
	if str(mode[1]).strip_edges() == "" or session == null or session.phase != "world": return
	match mode[0]:
		"Cmd": session.send_command(str(mode[1]))
		"Party": session.send(Protocol.party_say(str(mode[1])))
		_: session.send(Protocol.speech(str(mode[1]),int(Protocol.SPEECH.get(mode[0],0))))

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode in [KEY_ENTER,KEY_KP_ENTER] and not input.has_focus():
		input.grab_focus()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if input.has_focus() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		input.clear()
		input.release_focus()
		get_viewport().set_input_as_handled()
