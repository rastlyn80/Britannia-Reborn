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
# Open microphone: tap V (or click the microphone) to keep listening, and
# again to close it; holding V still talks only while held.
var open := false
var pressed_at := 0
const TAP_MS := 300
# Quiet that ends a sentence on the open microphone (owner: 0.9 s cut people
# off mid-thought). Chosen in the menu, saved per character.
const PAUSES := [1.2,1.8,2.5,3.5]
var pause := 1.8
# Live translation of what others say (Translator.gd), chosen here too.
var translator: Node

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
	translator = preload("res://Network/Translator.gd").new()
	add_child(translator)
	translator.status_changed.connect(_flash)
	# A microphone button on the talk line: click to start, click to stop.
	mic = Button.new()
	mic.icon = Look.icon("chat",Look.ASH,16)
	mic.flat = true
	mic.focus_mode = Control.FOCUS_NONE
	mic.tooltip_text = "Voice chat: click (or tap V) to open the microphone, again to close it; or hold V to talk"
	mic.pressed.connect(func(): if session.phase == "world": set_open(not open))
	journal.input.get_parent().add_child(mic)
	session.entered.connect(func(_p: Dictionary): load_settings())
	session.ended.connect(func():
		set_open(false)
		if voice.state == "recording": voice.cancel()
		hide())

# Per character (Profile.gd), like the other settings.
func load_settings() -> void:
	voice.language = str(Profile.value("voice","language",voice.language))
	voice.translate = bool(Profile.value("voice","translate",voice.translate))
	review = bool(Profile.value("voice","review",review))
	var device := str(Profile.value("voice","device",voice.device))
	if device != voice.device: voice.set_device(device)
	translator.set_language(str(Profile.value("voice","show_in","")))
	pause = float(Profile.value("voice","pause",pause))
	if open: voice.silence_seconds = pause

func store(name: String, value: Variant) -> void:
	Profile.store("voice",name,value)
	match name:
		"language": voice.language = str(value)
		"translate": voice.translate = bool(value)
		"review": review = bool(value)
		"device": voice.set_device(str(value))
		"show_in": translator.set_language(str(value))
		"pause":
			pause = float(value)
			if open: voice.silence_seconds = pause

func set_open(value: bool) -> void:
	if value == open: return
	open = value
	voice.open_mic = open
	voice.silence_seconds = pause if open else voice.SILENCE_SECONDS
	if open:
		if voice.state == "idle": voice.start()
	else:
		if voice.state == "recording": voice.stop()
		_flash("Microphone closed.")
	_state(voice.state)

func _unhandled_input(event: InputEvent) -> void:
	if session == null or session.phase != "world" or not event is InputEventKey or event.keycode != KEY or event.echo: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event.pressed and open:
		set_open(false)
	elif event.pressed and not holding:
		holding = true
		pressed_at = Time.get_ticks_msec()
		voice.hold(true)
	elif not event.pressed and holding:
		holding = false
		# A tap opens the microphone; a hold was push-to-talk.
		if Time.get_ticks_msec()-pressed_at < TAP_MS:
			voice.held = false
			voice.cancel()
			set_open(true)
		else: voice.hold(false)
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if voice and voice.state == "recording": meter.value = voice.level
	# The open microphone listens again as soon as the last line is sent.
	if open and voice and voice.state == "idle" and session and session.phase == "world": voice.start()

func _state(state: String) -> void:
	mic.icon = Look.icon("chat",Color("f0716a") if state == "recording" or open else (Look.GOLD if state == "recognizing" else Look.ASH),16)
	match state:
		"recording":
			text.text = "Microphone open · speak freely · V or the microphone closes it" if open else ("Listening… release V to send" if voice.held else "Listening… click the microphone to send")
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
	if not open: hide()
	if session == null or session.phase != "world": return
	if review:
		journal.input.text = said
		journal.input.grab_focus()
		journal.input.caret_column = said.length()
		return
	for line in lines(said): session.send(Protocol.speech(line,0))
