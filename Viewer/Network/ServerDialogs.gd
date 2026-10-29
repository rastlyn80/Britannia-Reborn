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
	session.module("player").race_change_requested.connect(func(female: bool, race: int):
		# Race 0xFF: the server withdrew the offer (timeout or answered).
		if race == 0xff:
			if str(current.get("kind","")) == "race": _done()
		else: _push({"kind":"race","data":{"female":female,"race":race}}))
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
		"race": _race(current.data)
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
	# The prompt may be replaced before the next frame.
	(func(): if is_instance_valid(field) and field.is_visible_in_tree(): field.grab_focus()).call_deferred()

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

# Race change (0xBF 0x2A): choices as ModernUO's RaceDefinitions accept them
# (race byte = race id + 1: 1 human, 2 elf, 3 gargoyle).
const RACES := {
	1:{"name":"Human","skin":[1002,1006,1010,1014,1018,1022,1026,1030,1034,1038,1042,1046,1050,1054,1058],
		"hair":[[0,"Bald"],[0x203b,"Short"],[0x203c,"Long"],[0x203d,"Ponytail"],[0x2044,"Mohawk"],[0x2045,"Pageboy"],[0x2046,"Buns","f"],[0x2047,"Afro"],[0x2048,"Receding","m"],[0x2049,"Pigtails"],[0x204a,"Krisna"]],
		"beard":[[0,"None"],[0x203e,"Long beard"],[0x203f,"Short beard"],[0x2040,"Goatee"],[0x2041,"Moustache"],[0x204b,"Short with moustache"],[0x204c,"Long with moustache"],[0x204d,"Vandyke"]],
		"hair_hues":[1102,1105,1108,1111,1114,1117,1120,1123,1126,1129,1132,1135,1138,1141,1144,1147]},
	2:{"name":"Elf","skin":[0x0bf,0x24d,0x24e,0x24f,0x353,0x361,0x367,0x374,0x375,0x376,0x381,0x382,0x383,0x384,0x385,0x389,0x3de,0x3e5,0x3e6,0x3e8,0x3e9,0x430,0x4a7,0x4de,0x51d,0x53f,0x579,0x76b,0x76c,0x76d,0x835,0x903],
		"hair":[[0,"Bald"],[0x2fbf,"Mid-long","m"],[0x2fc0,"Long feather"],[0x2fc1,"Short"],[0x2fc2,"Mullet"],[0x2fcc,"Flower","f"],[0x2fcd,"Long","m"],[0x2fce,"Topknot"],[0x2fcf,"Long braid"],[0x2fd0,"Buns","f"],[0x2fd1,"Spiked"]],
		"beard":[],
		"hair_hues":[0x034,0x035,0x036,0x037,0x038,0x039,0x058,0x08e,0x08f,0x090,0x091,0x092,0x101,0x159,0x15a,0x15b,0x15c,0x15d,0x15e,0x128,0x12f,0x1bd,0x1e4,0x1f3,0x207,0x211,0x239,0x251,0x26c,0x2c3,0x2c9,0x31d,0x369,0x386,0x59d,0x6b8,0x725,0x853]},
	3:{"name":"Gargoyle","skin":[1755,1757,1759,1761,1763,1765,1767,1769,1771,1773,1775,1777,1779],
		"hair":[[0,"None"],[0x4258,"Horns 1","m"],[0x4259,"Horns 2","m"],[0x425a,"Horns 3","m"],[0x425b,"Horns 4","m"],[0x425c,"Horns 5","m"],[0x425d,"Horns 6","m"],[0x425e,"Horns 7","m"],[0x425f,"Horns 8","m"],[0x4261,"Horns 1","f"],[0x4262,"Horns 2","f"],[0x4273,"Horns 3","f"],[0x4274,"Horns 4","f"],[0x4275,"Horns 5","f"],[0x42aa,"Horns 6","f"],[0x42ab,"Horns 7","f"],[0x42b1,"Horns 8","f"]],
		"beard":[[0,"None"],[0x42ad,"Facial horns 1"],[0x42ae,"Facial horns 2"],[0x42af,"Facial horns 3"],[0x42b0,"Facial horns 4"]],
		"hair_hues":[0x709,0x70b,0x70d,0x70f,0x711,0x763,0x765,0x768,0x76b,0x6f3,0x6f1,0x6ef,0x6e4,0x6e2,0x6e0]}}

func _race(offer: Dictionary) -> void:
	var race: Dictionary = RACES.get(int(offer.race),RACES[1])
	var female: bool = offer.female
	_title("Become %s %s" % ["an" if str(race.name) == "Elf" else "a",str(race.name).to_lower()])
	var note := Look.label("Choose how you will look. The server checks every choice.",13,Look.ASH,500)
	body.add_child(note)
	var choice := {"skin":int(race.skin[0]),"hair":0,"hair_hue":int(race.hair_hues[0]),"beard":0,"beard_hue":int(race.hair_hues[0])}
	_swatches("Skin",race.skin,choice,"skin")
	var hair: Array = race.hair.filter(func(entry): return entry.size() < 3 or entry[2] == ("f" if female else "m"))
	_options("Hair" if str(race.name) != "Gargoyle" else "Horns",hair,choice,"hair")
	_swatches("Hair colour" if str(race.name) != "Gargoyle" else "Horn colour",race.hair_hues,choice,"hair_hue")
	if not female and not race.beard.is_empty():
		_options("Beard" if str(race.name) != "Gargoyle" else "Facial horns",race.beard,choice,"beard")
	_buttons([["Not now",func():
		session.send(preload("res://Network/Packets/Player.gd").race_change_reply())
		_done()],["Change",func():
		choice.beard_hue = choice.hair_hue
		session.send(preload("res://Network/Packets/Player.gd").race_change_reply(int(choice.skin),int(choice.hair),int(choice.hair_hue),int(choice.beard),int(choice.beard_hue)))
		_done(),true]])

func _swatches(heading: String, hues: Array, choice: Dictionary, key: String) -> void:
	body.add_child(Look.label(heading,13,Look.GOLD,700))
	var flow := HFlowContainer.new()
	flow.custom_minimum_size = Vector2(420,0)
	body.add_child(flow)
	for hue in hues:
		var swatch := Button.new()
		swatch.toggle_mode = true
		swatch.custom_minimum_size = Vector2(26,26)
		swatch.tooltip_text = "Hue %d" % hue
		var colour := Artwork.color(int(hue),Color(0.5,0.5,0.5))
		swatch.add_theme_stylebox_override("normal",Look.box(colour,Color(0,0,0,0.4),5,1,0))
		swatch.add_theme_stylebox_override("hover",Look.box(colour,Look.IVORY,5,1,0))
		swatch.add_theme_stylebox_override("pressed",Look.box(colour,Look.GOLD,5,3,0))
		swatch.button_pressed = int(hue) == int(choice[key])
		swatch.pressed.connect(func():
			choice[key] = int(hue)
			for other in flow.get_children(): other.set_pressed_no_signal(other == swatch))
		flow.add_child(swatch)

func _options(heading: String, entries: Array, choice: Dictionary, key: String) -> void:
	body.add_child(Look.label(heading,13,Look.GOLD,700))
	var flow := HFlowContainer.new()
	flow.custom_minimum_size = Vector2(420,0)
	body.add_child(flow)
	for entry in entries:
		var option := Button.new()
		option.toggle_mode = true
		option.text = str(entry[1])
		option.button_pressed = int(entry[0]) == int(choice[key])
		option.pressed.connect(func():
			choice[key] = int(entry[0])
			for other in flow.get_children(): other.set_pressed_no_signal(other == option))
		flow.add_child(option)

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
