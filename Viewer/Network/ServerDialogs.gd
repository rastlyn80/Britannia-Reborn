extends Control
# Server dialogs that are not gumps (Dialogs module), one modern card at a
# time in the middle of the screen:
# - item and question menus (0x7C → 0x7D), item menus with 3D icons;
# - text prompts (0x9A/0xC2 → answer or cancel), e.g. renaming a pet;
# - the hue picker (0x95 → chosen hue) as a palette of the install's hues;
# - web links (0xA5), opened only after you confirm;
# - tips and notices (0xA6, with previous/next) and sign text (0x8B).
# Help text for objects (0xB7) and help topics appear as notices.
const Look = preload("res://Network/ModernSkin.gd")
const Dialogs = preload("res://Network/Packets/Dialogs.gd")
const Studio = preload("res://Presentation/ItemStudio.gd")
const Artwork = preload("res://Network/Artwork.gd")
var session: Node
var card := PanelContainer.new()
var body := VBoxContainer.new()
var queue: Array = []
var current := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Look.theme()
	card.add_theme_stylebox_override("panel",Look.box(Color(0.055,0.063,0.078,0.97),Color(0.84,0.7,0.43,0.45),14,1,20))
	card.custom_minimum_size = Vector2(440,0)
	add_child(card)
	body.add_theme_constant_override("separation",10)
	card.add_child(body)
	card.hide()

func configure(game: Node) -> void:
	session = game
	var dialogs: RefCounted = session.module("dialogs")
	dialogs.menu_opened.connect(func(menu: Dictionary): _push({"kind":"menu","data":menu}))
	dialogs.prompt_opened.connect(func(prompt: Dictionary): _push({"kind":"prompt","data":prompt}))
	dialogs.hue_picker_opened.connect(func(picker: Dictionary): _push({"kind":"hue","data":picker}))
	dialogs.url_requested.connect(func(url: String): _push({"kind":"url","data":{"url":url}}))
	dialogs.tip_opened.connect(func(tip: Dictionary): _push({"kind":"tip","data":tip}))
	dialogs.sign_opened.connect(func(sign: Dictionary): _push({"kind":"sign","data":sign}))
	dialogs.help_text.connect(func(_serial: int, text: String): session.message_received.emit(text))
	session.ended.connect(func():
		queue.clear()
		_close())

func _push(entry: Dictionary) -> void:
	queue.append(entry)
	if current.is_empty(): _next()

func _next() -> void:
	preload("res://Network/ModernWindow.gd").clear(body)
	if queue.is_empty():
		_close()
		return
	current = queue.pop_front()
	match str(current.kind):
		"menu": _menu(current.data)
		"prompt": _prompt(current.data)
		"hue": _hue(current.data)
		"url": _url(current.data.url)
		"tip": _tip(current.data)
		"sign": _sign(current.data)
	card.show()
	(func():
		card.reset_size()
		card.position = ((size-card.size)/2.0).round()).call_deferred()

func _close() -> void:
	current = {}
	card.hide()

func _done() -> void:
	current = {}
	_next()

func _title(text: String) -> void:
	var title := Label.new()
	title.text = text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(400,0)
	title.add_theme_font_override("font",Look.title_font())
	title.add_theme_font_size_override("font_size",19)
	title.add_theme_color_override("font_color",Look.GOLD)
	body.add_child(title)

func _buttons(entries: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	row.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(row)
	for entry in entries:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(110,40)
		if entry.size() > 2 and entry[2]:
			b.add_theme_stylebox_override("normal",Look.box(Look.BRASS,Look.BRASS,8,1,6))
			b.add_theme_color_override("font_color",Color("14110b"))
		b.pressed.connect(entry[1])
		row.add_child(b)

func _menu(menu: Dictionary) -> void:
	_title(str(menu.question) if str(menu.question) != "" else "Choose")
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation",6)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400,mini(360,menu.entries.size()*58))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(list)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	for i in menu.entries.size():
		var entry: Dictionary = menu.entries[i]
		var b := Button.new()
		b.text = "  "+str(entry.name)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0,52 if int(entry.graphic) else 40)
		if int(entry.graphic):
			var rendered := Studio.lookup(int(entry.graphic),int(entry.hue))
			b.icon = rendered if rendered else Artwork.item(int(entry.graphic),int(entry.hue))
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width",44)
		var index: int = i+1
		b.pressed.connect(func():
			session.send(Dialogs.menu_choice(menu,index))
			_done())
		list.add_child(b)
	_buttons([["Cancel",func():
		session.send(Dialogs.menu_choice(menu,0))
		_done()]])

func _prompt(prompt: Dictionary) -> void:
	_title("The server asks for text")
	var field := LineEdit.new()
	field.custom_minimum_size = Vector2(400,42)
	field.max_length = 128
	body.add_child(field)
	var answer := func():
		session.send(Dialogs.prompt_answer(prompt,field.text))
		_done()
	field.text_submitted.connect(func(_t: String): answer.call())
	_buttons([["Cancel",func():
		session.send(Dialogs.prompt_answer(prompt,"",true))
		_done()],["Send",answer,true]])
	field.grab_focus.call_deferred()

func _hue(picker: Dictionary) -> void:
	_title("Choose a colour")
	var chosen := {"hue":0}
	var preview := ColorRect.new()
	preview.custom_minimum_size = Vector2(400,28)
	preview.color = Color(0.3,0.3,0.3)
	body.add_child(preview)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400,260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 20
	grid.add_theme_constant_override("h_separation",2)
	grid.add_theme_constant_override("v_separation",2)
	scroll.add_child(grid)
	for hue in range(2,1002):
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(18,18)
		swatch.color = Artwork.color(hue,Color(0.2,0.2,0.2))
		swatch.tooltip_text = "Hue %d" % hue
		swatch.mouse_filter = Control.MOUSE_FILTER_STOP
		swatch.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				chosen.hue = hue
				preview.color = swatch.color)
		grid.add_child(swatch)
	_buttons([["Cancel",func(): _done()],["Dye",func():
		if int(chosen.hue) > 0: session.send(Dialogs.hue_choice(picker,int(chosen.hue)))
		_done(),true]])

func _url(url: String) -> void:
	_title("The server wants to open a web page")
	var text := Look.label(url,14,Look.IVORY,500)
	text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	text.custom_minimum_size = Vector2(400,0)
	body.add_child(text)
	_buttons([["Not now",func(): _done()],["Open in browser",func():
		if url.begins_with("http://") or url.begins_with("https://"): OS.shell_open(url)
		_done(),true]])

func _tip(tip: Dictionary) -> void:
	_title("Notice" if int(tip.type) == 1 else "Tip")
	var text := Look.label(str(tip.text).replace("<br>","\n"),14,Look.IVORY,500)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(400,0)
	body.add_child(text)
	var entries := [["Close",func(): _done(),true]]
	if int(tip.type) == 0:
		entries.push_front(["Next tip",func():
			session.send(Dialogs.tip_request(int(tip.number),true))
			_done()])
	_buttons(entries)

func _sign(sign: Dictionary) -> void:
	_title(str(sign.caption) if str(sign.caption) != "" else "Sign")
	var text := Look.label(str(sign.text),15,Look.IVORY,500)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(400,0)
	body.add_child(text)
	_buttons([["Close",func(): _done(),true]])

func _unhandled_key_input(event: InputEvent) -> void:
	if card.visible and event.pressed and event.keycode == KEY_ESCAPE:
		match str(current.get("kind","")):
			"menu": session.send(Dialogs.menu_choice(current.data,0))
			"prompt": session.send(Dialogs.prompt_answer(current.data,"",true))
		_done()
		get_viewport().set_input_as_handled()
