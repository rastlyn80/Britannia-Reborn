extends PanelContainer
# Voice chat by speech-to-text: hold V (or click the microphone beside the
# talk line) and speak; on release your words are recognized on this
# computer by local Whisper (whisper.cpp, scripts/setup-speech.ps1; Windows
# speech recognition without it) and said in game as ordinary speech, so
# they reach the journal and float over your head like typed lines. Nothing
# but the text leaves the computer. Settings (Game menu › Voice chat, saved
# per character): language, speaking English to others (Whisper translates),
# review before sending (the text goes to the talk line instead), and the
# microphone. Recording itself is DevEdit/DevEditVoice.gd.
const Look = preload("res://Network/ModernSkin.gd")
const Frame = preload("res://Network/ModernWindow.gd")
const Voice = preload("res://DevEdit/DevEditVoice.gd")
const Protocol = preload("res://Network/ActionProtocol.gd")
const Profile = preload("res://Network/Profile.gd")
const KEY := KEY_V
# One speech line carries at most this many characters (the talk line's cap).
const LINE := 120
var session: Node
var journal: Control
var voice: Node
var review := false
var text: Label
var meter: ProgressBar
var mic: Button
var holding := false

func _ready() -> void:
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 20
	offset_top = -330
	offset_bottom = -290
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel",Look.box(Color(0.045,0.05,0.065,0.92),Look.EDGE,10,1,8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var dot := TextureRect.new()
	dot.texture = Look.icon("chat",Color("f0716a"),16)
	dot.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(dot)
	text = Look.label("",13,Look.IVORY,600)
	row.add_child(text)
	meter = Frame.meter(Color("f0716a"),6)
	meter.custom_minimum_size = Vector2(80,6)
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.max_value = 0.4
	row.add_child(meter)
	hide()

func configure(game: Node, talk_journal: Control) -> void:
	session = game
	journal = talk_journal
	voice = Voice.new()
	voice.settings_path = "user://voice-chat.cfg"
	voice.file_base = "voice-chat"
	# Chat defaults: your own language as spoken, sent at once.
	voice.translate = false
	add_child(voice)
	voice.heard.connect(_heard)
	voice.failed.connect(func(reason: String): _flash(reason))
	voice.state_changed.connect(_state)
	# A microphone button on the talk line: click to start, click to stop.
	mic = Button.new()
	mic.icon = Look.icon("chat",Look.ASH,16)
	mic.flat = true
	mic.focus_mode = Control.FOCUS_NONE
	mic.tooltip_text = "Voice chat: hold V and speak, or click to start and stop"
	mic.pressed.connect(func(): if session.phase == "world": voice.toggle())
	journal.input.get_parent().add_child(mic)
	session.entered.connect(func(_p: Dictionary): load_settings())
	session.ended.connect(func():
		if voice.state == "recording": voice.stop()
		hide())

# Per character (Profile.gd), like the other settings.
func load_settings() -> void:
	voice.language = str(Profile.value("voice","language",voice.language))
	voice.translate = bool(Profile.value("voice","translate",voice.translate))
	review = bool(Profile.value("voice","review",review))
	var device := str(Profile.value("voice","device",voice.device))
	if device != voice.device: voice.set_device(device)

func store(name: String, value: Variant) -> void:
	Profile.store("voice",name,value)
	match name:
		"language": voice.language = str(value)
		"translate": voice.translate = bool(value)
		"review": review = bool(value)
		"device": voice.set_device(str(value))

func _unhandled_input(event: InputEvent) -> void:
	if session == null or session.phase != "world" or not event is InputEventKey or event.keycode != KEY or event.echo: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event.pressed and not holding:
		holding = true
		voice.hold(true)
	elif not event.pressed and holding:
		holding = false
		voice.hold(false)
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if voice and voice.state == "recording": meter.value = voice.level

func _state(state: String) -> void:
	mic.icon = Look.icon("chat",Color("f0716a") if state == "recording" else (Look.GOLD if state == "recognizing" else Look.ASH),16)
	match state:
		"recording":
			text.text = "Listening… release V to send" if voice.held else "Listening… click the microphone to send"
			meter.show()
			modulate.a = 1.0
			show()
		"recognizing":
			text.text = "Recognizing…"
			meter.hide()
			show()

func _flash(message: String) -> void:
	text.text = message
	meter.hide()
	show()
	modulate.a = 1.0
	var fade := create_tween()
	fade.tween_interval(2.5)
	fade.tween_property(self,"modulate:a",0.0,0.4)
	fade.tween_callback(hide)

# Long speech goes out as several lines, split between words.
static func lines(said: String) -> PackedStringArray:
	var result := PackedStringArray()
	var line := ""
	for word in said.split(" ",false):
		if line != "" and line.length()+1+word.length() > LINE:
			result.append(line)
			line = ""
		line = word if line == "" else line+" "+word
		while line.length() > LINE:
			result.append(line.left(LINE))
			line = line.substr(LINE)
	if line != "": result.append(line)
	return result

func _heard(said: String, _info: Dictionary) -> void:
	hide()
	if session == null or session.phase != "world": return
	if review:
		journal.input.text = said
		journal.input.grab_focus()
		journal.input.caret_column = said.length()
		return
	for line in lines(said): session.send(Protocol.speech(line,0))
