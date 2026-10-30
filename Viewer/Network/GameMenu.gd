extends Control
# The game menu (Esc, or the gear on the menu bar): Resume, Settings, Keys
# and help, Developer, Log out and Quit. It replaces the old right-hand panel's
# buttons; everything that panel did lives here or in the HUD.
const Look = preload("res://Network/ModernSkin.gd")
const KEYS := [["W A S D","Walk; hold Shift to run"],["Space","Hop"],["Right mouse","Look around"],["Wheel","Zoom"],["E","Use the nearest object"],["Click","Use or pick up what you click"],["1 – 0, - , =","Quickbar; hold Shift, Ctrl or Alt for other sets"],["C · B · K · P · J · M","Character, backpack, skills, spellbook, journal, map"],["Enter","Talk; /e emote, /w whisper, /y yell, /p party"],["V (hold)","Voice chat: speak, release to say it"],["`","Developer console"],["F6","Return to Britain (developer)"],["F7","Cycle the sky (view only)"],["F9","World editor (developer)"],["Esc","This menu"]]
var scene: Node3D
var card: PanelContainer
var body: VBoxContainer
var sky_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Look.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02,0.03,0.05,0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed: close())
	add_child(dim)
	card = PanelContainer.new()
	# Settings and the rest of the menu: drag it anywhere by its background.
	preload("res://Network/Movable.gd").attach(card,"gamemenu")
	card.add_theme_stylebox_override("panel",Look.box(Color(0.055,0.063,0.078,0.97),Color(0.84,0.7,0.43,0.45),16,1,22))
	card.custom_minimum_size = Vector2(440,0)
	add_child(card)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation",8)
	card.add_child(body)
	hide()

func configure(world_scene: Node3D) -> void:
	scene = world_scene

func open() -> void:
	show()
	_main()

func close() -> void:
	hide()

func toggle() -> void:
	if visible: close()
	else: open()

func _reset(title: String) -> void:
	preload("res://Network/ModernWindow.gd").clear(body)
	var head := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.add_theme_font_override("font",Look.title_font())
	label.add_theme_font_size_override("font_size",22)
	label.add_theme_color_override("font_color",Look.GOLD)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	head.add_child(Look.label("Esc",12,Look.DIM,600))
	body.add_child(head)
	(func():
		card.reset_size()
		card.position = preload("res://Network/Movable.gd").place("gamemenu",(size-card.size)/2)
		preload("res://Network/Movable.gd").keep_on_screen(card)).call_deferred()

func _row(text: String, hint: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text+("   ·   "+hint if hint != "" else "")
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0,46)
	button.add_theme_font_size_override("font_size",15)
	if primary:
		button.add_theme_stylebox_override("normal",Look.box(Look.BRASS,Look.BRASS,10,1,12))
		button.add_theme_stylebox_override("hover",Look.box(Color("e6c588"),Color("e6c588"),10,1,12))
		for state in ["font_color","font_hover_color","font_pressed_color"]: button.add_theme_color_override(state,Color("17140e"))
	button.pressed.connect(action)
	body.add_child(button)
	return button

func _main() -> void:
	_reset("Game menu")
	_row("Resume","",close,true)
	_row("Settings","graphics, controls, sky",_settings)
	_row("Voice chat","hold V and speak · language, translation, microphone",_voice)
	_row("Keys and help","",_keys)
	_row("Developer","console, travel, world editor",_developer)
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation",8)
	body.add_child(pair)
	for entry in [["Change character",func():
		close()
		scene.log_out("characters")],["Log out",func():
		close()
		scene.log_out()],["Quit game",func(): get_tree().quit()]]:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(0,44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(entry[1])
		pair.add_child(b)
	pair.get_child(2).add_theme_color_override("font_color",Color("f0a59b"))

func _back() -> void:
	_row("Back","",_main)

func _settings() -> void:
	_reset("Settings")
	var graphics := preload("res://Presentation/GraphicsMode.gd")
	var look_button := _row("World look: %s" % ("modern" if graphics.modern() else "classic"),"takes effect after restart",func(): pass)
	look_button.pressed.connect(func():
		graphics.set_modern(not graphics.modern())
		look_button.text = "World look: %s   ·   restart to apply" % ("modern" if graphics.modern() else "classic"))
	sky_button = _row(scene.lighting_rig.sky_label() if scene.lighting_rig else "Sky","view only",func(): pass)
	sky_button.pressed.connect(func():
		scene.cycle_sky()
		if scene.lighting_rig: sky_button.text = scene.lighting_rig.sky_label())
	if scene.audio and scene.audio.available():
		for entry in [["Sound effects","sound_volume"],["Music","music_volume"]]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation",12)
			var name := Look.label(entry[0],14,Look.IVORY,500)
			name.custom_minimum_size = Vector2(130,0)
			row.add_child(name)
			var slider := HSlider.new()
			slider.min_value = 0.0
			slider.max_value = 1.0
			slider.step = 0.05
			slider.value = scene.audio.get(entry[1])
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.custom_minimum_size = Vector2(0,30)
			slider.value_changed.connect(func(value: float):
				scene.audio.set(entry[1],value)
				preload("res://Network/Profile.gd").store("audio",entry[1],value)
				if entry[1] == "music_volume":
					for player in scene.audio.music_players:
						if player.playing: player.volume_db = linear_to_db(maxf(0.001,value)))
			row.add_child(slider)
			body.add_child(row)
	else: body.add_child(Look.label("Sound: run scripts/prepare-audio.py to use your UO install's audio.",13,Look.ASH,500))
	# Interface size: on top of the automatic scaling to the window.
	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation",12)
	var scale_name := Look.label("Interface size",14,Look.IVORY,500)
	scale_name.custom_minimum_size = Vector2(130,0)
	scale_row.add_child(scale_name)
	var Scale := preload("res://Presentation/InterfaceScale.gd")
	var scale_slider := HSlider.new()
	scale_slider.min_value = Scale.SMALLEST
	scale_slider.max_value = Scale.LARGEST
	scale_slider.step = 0.05
	scale_slider.value = Scale.size()
	scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_slider.custom_minimum_size = Vector2(0,30)
	var scale_value := Look.label("%d%%" % roundi(Scale.size()*100),13,Look.ASH,600)
	scale_value.custom_minimum_size = Vector2(48,0)
	# Applied on release, so the slider does not move under the mouse while dragging.
	scale_slider.drag_ended.connect(func(_changed: bool):
		Scale.set_size(get_tree().root,scale_slider.value)
		(func():
			card.reset_size()
			card.position = (size-card.size)/2
			preload("res://Network/Movable.gd").keep_on_screen(card)).call_deferred())
	scale_slider.value_changed.connect(func(value: float): scale_value.text = "%d%%" % roundi(value*100))
	scale_row.add_child(scale_slider)
	scale_row.add_child(scale_value)
	body.add_child(scale_row)
	var pad := CheckButton.new()
	pad.text = "Gamepad"
	pad.button_pressed = scene.controller_enabled
	pad.custom_minimum_size = Vector2(0,44)
	pad.toggled.connect(func(enabled: bool):
		scene.controller_enabled = enabled
		preload("res://Network/Profile.gd").store("input","gamepad",enabled))
	body.add_child(pad)
	_back()

# Voice chat settings (Network/VoiceChat.gd), saved per character.
func _voice() -> void:
	_reset("Voice chat")
	var chat: Control = scene.voice_chat
	if chat == null:
		_back()
		return
	var Voice := preload("res://DevEdit/DevEditVoice.gd")
	var engine: Dictionary = Voice.engine()
	body.add_child(Look.label("Hold V (or click the microphone by the talk line) and speak; release to say it. Recognized on this computer: %s." % ("Whisper, %s" % str(engine.get("modelName","")) if not engine.is_empty() else "Windows speech recognition (run scripts/setup-speech.ps1 for offline Whisper in 99 languages)"),13,Look.ASH,500))
	var options := [["Language you speak",Voice.LANGUAGES.map(func(entry): return entry[1]),Voice.LANGUAGES.map(func(entry): return entry[0]).find(chat.voice.language),func(index: int): chat.store("language",Voice.LANGUAGES[index][0])]]
	var mics: Array = Array(chat.voice.devices())
	options.append(["Microphone",mics,mics.find(chat.voice.device),func(index: int): chat.store("device",mics[index])])
	for option in options:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		var name := Look.label(option[0],14,Look.IVORY,500)
		name.custom_minimum_size = Vector2(180,0)
		row.add_child(name)
		var pick := OptionButton.new()
		for entry in option[1]: pick.add_item(str(entry))
		pick.selected = maxi(0,int(option[2]))
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.item_selected.connect(option[3])
		row.add_child(pick)
		body.add_child(row)
	for toggle in [["Speak English to others (Whisper translates)","translate",chat.voice.translate],["Review before sending (text goes to the talk line)","review",chat.review]]:
		var check := CheckButton.new()
		check.text = toggle[0]
		check.button_pressed = toggle[2]
		check.custom_minimum_size = Vector2(0,40)
		check.toggled.connect(func(on: bool): chat.store(toggle[1],on))
		body.add_child(check)
	_back()

func _keys() -> void:
	_reset("Keys and help")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",18)
	grid.add_theme_constant_override("v_separation",6)
	body.add_child(grid)
	for entry in KEYS:
		grid.add_child(Look.label(entry[0],13,Look.GOLD,600))
		grid.add_child(Look.label(entry[1],13,Look.IVORY,500))
	_row("Ask the server for help","opens the shard's help menu",func():
		scene.game.request_help()
		close())
	_back()

func _developer() -> void:
	_reset("Developer")
	_row("Console","`",func():
		close()
		scene.open_console())
	_row("Return to Britain","F6",func():
		scene.game.return_to_britain()
		close())
	if scene.dev_edit:
		_row("World editor","F9",func():
			close()
			scene.dev_edit.toggle())
	_back()

