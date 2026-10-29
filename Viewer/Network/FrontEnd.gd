extends Control
# The front end: sign in, choose a character, create one, and the loading
# screen while the districts around the character's real position stream in.
# It draws its own small 3D stage (FrontStage) instead of a map district, and
# hands over to the world only when the near districts are installed.
signal finished
const Look = preload("res://Network/ModernSkin.gd")
const Looks = preload("res://Network/CharacterLooks.gd")
const HAIR := [["Bald",0],["Short",0x203b],["Long",0x203c],["Ponytail",0x203d],["Pageboy",0x2045],["Afro",0x2047]]
const BEARD := [["None",0],["Long",0x203e],["Short",0x203f],["Goatee",0x2040],["Moustache",0x2041],["Short + moustache",0x204b],["Long + moustache",0x204c],["Vandyke",0x204d]]
const HAIR_HUES := [["Dark brown",1147,"3b2a1f"],["Charcoal",1109,"24242a"],["Blond",1118,"c9a95c"],["Copper",1135,"9a4f26"],["Silver",1102,"b9b7b0"]]
const SKINS := [["Light",1002,"e3b99a"],["Medium",1021,"a7735a"],["Dark",1040,"6a4432"]]
const TIPS := ["Hold Shift, Ctrl or Alt to switch quickbar sets.","Right-click any quickbar slot to change what it does.","E uses the nearest object; click anything to use it.","Esc opens the game menu: settings, keys and log out.","Enter talks; /e emotes, /w whispers, /y yells, /p talks to your party."]
var session: Node
var scene: Node3D
var login_panel: Control
var stage: Node3D
var viewport: SubViewport
var screens := {}
var message: Label
var username := LineEdit.new()
var password := LineEdit.new()
var remember := CheckBox.new()
var roster: VBoxContainer
var chosen := {}
var shown_name: Label
var shown_detail: Label
var looks := {}
var account := ""
var creation := {"female":false,"skin":1021,"hair":0x203c,"hair_hue":1147,"beard":0,"beard_hue":1147,"city":-1}
var creation_rows := {}
var new_name := LineEdit.new()
var cities_box: VBoxContainer
var beard_rows: Array = []
var loading_title: Label
var loading_bar: ProgressBar
var loading_detail: Label
var loading_tip: Label
var loading_started := 0
var dragging := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Look.theme()
	_build_stage()
	message = Look.label("",14,Look.ASH,500)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screens.signin = _signin()
	screens.characters = _characters()
	screens.create = _create()
	screens.loading = _loading()
	for key in screens: add_child(screens[key])
	go("signin")

func configure(game: Node, world_scene: Node3D, panel: Control) -> void:
	session = game
	scene = world_scene
	login_panel = panel
	username.text = panel.username.text
	password.text = panel.password.text
	session.failed.connect(func(reason: String):
		if visible:
			message.text = reason
			if session.phase in ["idle","login","connecting"] or screens.loading.visible: go("signin"))
	session.characters_received.connect(func(characters: Array, _cities: Array): _show_roster(characters))
	session.entered.connect(func(position: Dictionary):
		if not visible: return
		loading_title.text = Looks.place(int(position.x),int(position.y))
		loading_started = Time.get_ticks_msec()
		go("loading"))
	session.ended.connect(func():
		if not visible: back_to_front("Signed out."))

# --- the stage --------------------------------------------------------------
static func _still() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility" or "--front-still" in OS.get_cmdline_user_args()

func _build_stage() -> void:
	if _still():
		# A still night for weak GPUs: a gradient sky and nothing else to draw.
		var gradient := Gradient.new()
		gradient.set_color(0,Color("070a14"))
		gradient.set_color(1,Color("2b2a3a"))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill_from = Vector2(0,0)
		texture.fill_to = Vector2(0,1)
		var still := TextureRect.new()
		still.texture = texture
		still.stretch_mode = TextureRect.STRETCH_SCALE
		still.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		still.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(still)
		return
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.use_taa = false
	container.add_child(viewport)
	stage = preload("res://Presentation/FrontStage.gd").new()
	viewport.add_child(stage)
	stage.camera.current = true
	container.gui_input.connect(_stage_input)

func _stage_input(event: InputEvent) -> void:
	if stage == null or not (screens.characters.visible or screens.create.visible): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed
	if event is InputEventMouseMotion and dragging: stage.turn(event.relative.x*0.012)

func go(screen: String) -> void:
	for key in screens: screens[key].visible = key == screen
	if stage:
		stage.frame("stage" if screen in ["characters","create"] else "vista")
		if screen == "signin" or screen == "loading": stage.show_character({},[])
	if message.get_parent(): message.get_parent().remove_child(message)
	var holder: Node = screens[screen].get_meta("message_holder",null)
	if holder: holder.add_child(message)
	if screen in ["create","loading"]: message.text = ""
	if screen == "create": _preview_creation()
	if screen == "signin" and username.text.is_empty(): username.grab_focus.call_deferred()

# Logging out (or losing the connection) in the world brings the front end back.
func back_to_front(text: String) -> void:
	if stage == null and not _still(): _build_stage_again()
	show()
	scene.front_end_shown(true)
	message.text = text
	go("signin")

func _build_stage_again() -> void:
	_build_stage()
	# The new stage goes behind the screens.
	move_child(get_child(get_child_count()-1),0)

# --- shared pieces -------------------------------------------------------
func _card(width: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(width,0)
	card.add_theme_stylebox_override("panel",Look.box(Color(0.055,0.063,0.078,0.88),Look.EDGE,16,1,24))
	return card

func _primary(text: String, action: Callable, height := 50) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0,height)
	button.add_theme_font_override("font",Look.ui_font(600))
	button.add_theme_font_size_override("font_size",16)
	button.add_theme_stylebox_override("normal",Look.box(Look.BRASS,Look.BRASS,10,1,8))
	button.add_theme_stylebox_override("hover",Look.box(Color("e6c588"),Color("e6c588"),10,1,8))
	button.add_theme_stylebox_override("pressed",Look.box(Color("bf9b58"),Color("bf9b58"),10,1,8))
	button.add_theme_color_override("font_color",Color("17140e"))
	button.add_theme_color_override("font_hover_color",Color("17140e"))
	button.add_theme_color_override("font_pressed_color",Color("17140e"))
	button.pressed.connect(action)
	return button

func _secondary(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0,42)
	button.pressed.connect(action)
	return button

func _field(title: String, input: LineEdit) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",6)
	box.add_child(Look.label(title,13,Look.ASH,500))
	input.custom_minimum_size = Vector2(0,44)
	input.add_theme_font_size_override("font_size",15)
	box.add_child(input)
	return box

func _heading(text: String, size := 22) -> Label:
	var title := Label.new()
	title.text = text
	title.add_theme_font_override("font",Look.title_font())
	title.add_theme_font_size_override("font_size",size)
	title.add_theme_color_override("font_color",Look.GOLD)
	return title

func _full() -> Control:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return screen

# --- 1 · sign in ---------------------------------------------------------
func _signin() -> Control:
	var screen := _full()
	var column := VBoxContainer.new()
	column.position = Vector2(110,100)
	column.add_theme_constant_override("separation",26)
	screen.add_child(column)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation",2)
	var big := _heading("Britannia",58)
	brand.add_child(big)
	var sub := Look.label("R E B O R N",26,Look.IVORY,500)
	sub.add_theme_font_override("font",Look._font("Cinzel.ttf",500))
	brand.add_child(sub)
	column.add_child(brand)
	var card := _card(440)
	column.add_child(card)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation",16)
	card.add_child(form)
	var head := HBoxContainer.new()
	var title := _heading("Sign in",20)
	title.add_theme_color_override("font_color",Look.IVORY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(Look.label("Local shard · 127.0.0.1",12,Color("b7e3a8"),600))
	form.add_child(head)
	username.placeholder_text = "Account name"
	password.placeholder_text = "Password"
	password.secret = true
	form.add_child(_field("Account",username))
	form.add_child(_field("Password",password))
	username.text_submitted.connect(func(_t: String): password.grab_focus())
	password.text_submitted.connect(func(_t: String): _enter())
	remember.text = "Remember me on this computer"
	remember.button_pressed = true
	remember.toggled.connect(func(enabled: bool): if not enabled and login_panel: login_panel.memory.forget())
	form.add_child(remember)
	form.add_child(_primary("Enter",_enter))
	var note := Look.label("New name? A local account is created when you enter.",13,Look.ASH,500)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(note)
	if OS.get_environment("UO_DEV_USER") != "":
		form.add_child(_secondary("Use the local development account",func():
			username.text = OS.get_environment("UO_DEV_USER")
			password.text = OS.get_environment("UO_DEV_PASSWORD")
			_enter()))
	var holder := VBoxContainer.new()
	form.add_child(holder)
	screen.set_meta("message_holder",holder)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",10)
	footer.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(110,-76)
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	screen.add_child(footer)
	footer.add_child(_secondary("Settings",func(): scene.open_settings()))
	footer.add_child(_secondary("Credits",func(): preload("res://Presentation/CharacterCredits.gd").show_dialog(self)))
	footer.add_child(_secondary("Quit",func(): get_tree().quit()))
	var mode := Look.label("%s graphics · %s" % ["Modern" if preload("res://Presentation/GraphicsMode.gd").modern() else "Classic",preload("res://Presentation/LiveDistricts.gd").region().capitalize()],13,Look.ASH,500)
	mode.anchor_left = 1.0
	mode.anchor_right = 1.0
	mode.anchor_top = 1.0
	mode.anchor_bottom = 1.0
	mode.offset_left = -420
	mode.offset_right = -110
	mode.offset_top = -64
	mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	screen.add_child(mode)
	return screen

func _enter() -> void:
	if username.text.strip_edges().is_empty():
		message.text = "Enter an account name."
		return
	account = username.text.strip_edges()
	message.text = "Connecting…"
	if login_panel:
		login_panel.username.text = username.text
		login_panel.password.text = password.text
		login_panel.remember.button_pressed = remember.button_pressed
		login_panel.store_login()
	session.connect_account(account,password.text)

# --- 2 · characters ------------------------------------------------------
func _characters() -> Control:
	var screen := _full()
	var left := VBoxContainer.new()
	left.position = Vector2(64,64)
	left.custom_minimum_size = Vector2(360,0)
	left.add_theme_constant_override("separation",12)
	screen.add_child(left)
	left.add_child(_heading("Your characters",26))
	roster = VBoxContainer.new()
	roster.add_theme_constant_override("separation",10)
	left.add_child(roster)
	var holder := VBoxContainer.new()
	left.add_child(holder)
	screen.set_meta("message_holder",holder)
	left.add_child(_secondary("Back to sign in",func():
		session.close()
		message.text = ""
		go("signin")))
	var bottom := VBoxContainer.new()
	bottom.anchor_left = 0.5
	bottom.anchor_right = 0.5
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = -300
	bottom.offset_right = 300
	bottom.offset_top = -150
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	screen.add_child(bottom)
	shown_name = _heading("",38)
	shown_name.add_theme_color_override("font_color",Color("f3dca2"))
	shown_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(shown_name)
	shown_detail = Look.label("",14,Look.ASH,500)
	shown_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(shown_detail)
	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -364
	right.offset_right = -64
	right.offset_top = -190
	right.add_theme_constant_override("separation",12)
	screen.add_child(right)
	var hint := Look.label("Drag the character to turn it.",13,Look.ASH,500)
	right.add_child(hint)
	right.add_child(_primary("Enter Britannia",func():
		if chosen.is_empty(): return
		message.text = "Entering…"
		session.select_character(int(chosen.slot),str(chosen.name)),56))
	return screen

func _show_roster(characters: Array) -> void:
	_clear(roster)
	looks = Looks.load_all(account)
	var first := {}
	var used := 0
	for character in characters:
		if str(character.name).is_empty(): continue
		used += 1
		var entry: Dictionary = character
		var look: Dictionary = looks.get(str(entry.name),{})
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(360,64)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s\n%s" % [entry.name,"Last seen: "+str(look.place) if look.has("place") else "Not played on this computer yet"]
		button.add_theme_font_size_override("font_size",15)
		button.pressed.connect(func(): _choose(entry))
		roster.add_child(button)
		if first.is_empty(): first = entry
	var free := characters.size()-used
	if free > 0:
		roster.add_child(_secondary("+  Create a new character",func(): go("create")))
	message.text = "%d of %d slots used." % [used,characters.size()]
	if first.is_empty():
		go("create")
		return
	go("characters")
	_choose(first)

func _clear(node: Node) -> void:
	preload("res://Network/ModernWindow.gd").clear(node)

func _choose(entry: Dictionary) -> void:
	chosen = entry
	for button in roster.get_children():
		if button is Button and button.toggle_mode: button.set_pressed_no_signal(button.text.begins_with(str(entry.name)+"\n"))
	shown_name.text = str(entry.name)
	var look: Dictionary = looks.get(str(entry.name),{})
	if look.is_empty():
		shown_detail.text = "Its look appears here after you play it once on this computer."
		if stage: stage.show_character({"body":400,"hue":1002},Looks.starter(false))
	else:
		var female := int(look.get("body",400)) in [401,403,605,607]
		shown_detail.text = "Human · %s · last seen: %s" % ["Female" if female else "Male",look.get("place","")]
		if stage: stage.show_character({"body":int(look.body),"hue":int(look.hue)},look.get("worn",[]))

# --- 3 · create ----------------------------------------------------------
func _create() -> Control:
	var screen := _full()
	var left := _card(420)
	left.position = Vector2(64,64)
	screen.add_child(left)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	left.add_child(column)
	column.add_child(_heading("Appearance",24))
	var sexes := HBoxContainer.new()
	sexes.add_theme_constant_override("separation",8)
	column.add_child(sexes)
	creation_rows.sex = []
	for entry in [["Male",false],["Female",true]]:
		var button := _choice(entry[0],func():
			creation.female = entry[1]
			if entry[1]: creation.beard = 0
			_preview_creation())
		button.set_meta("value",entry[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sexes.add_child(button)
		creation_rows.sex.append(button)
	column.add_child(_swatches("Skin","skin",SKINS,50))
	column.add_child(_options("Hair","hair",HAIR,3))
	column.add_child(_swatches("Hair colour","hair_hue",HAIR_HUES,40))
	var beard := _options("Beard","beard",BEARD,4)
	column.add_child(beard)
	var beard_colour := _swatches("Beard colour","beard_hue",HAIR_HUES,40)
	column.add_child(beard_colour)
	beard_rows = [beard,beard_colour]
	var right := _card(380)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -444
	right.offset_right = -64
	right.offset_top = 64
	screen.add_child(right)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation",16)
	right.add_child(side)
	side.add_child(_heading("Identity",24))
	new_name.placeholder_text = "2 to 29 letters"
	new_name.max_length = 29
	side.add_child(_field("Name",new_name))
	side.add_child(Look.label("Starting city",13,Look.ASH,500))
	cities_box = VBoxContainer.new()
	cities_box.add_theme_constant_override("separation",8)
	side.add_child(cities_box)
	var later := Look.label("Profession and skills: the server's defaults for now.",13,Look.DIM,500)
	later.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(later)
	var holder := VBoxContainer.new()
	side.add_child(holder)
	screen.set_meta("message_holder",holder)
	side.add_child(_primary("Create and enter",_create_character,56))
	side.add_child(_secondary("Back",func(): go("characters") if not chosen.is_empty() else go("signin")))
	var turns := HBoxContainer.new()
	turns.anchor_left = 0.5
	turns.anchor_right = 0.5
	turns.anchor_top = 1.0
	turns.anchor_bottom = 1.0
	turns.offset_left = -50
	turns.offset_top = -100
	turns.offset_bottom = -56
	turns.add_theme_constant_override("separation",12)
	screen.add_child(turns)
	for step in [-0.6,0.6]:
		var b := Button.new()
		b.text = "◀" if step < 0 else "▶"
		b.custom_minimum_size = Vector2(44,44)
		b.tooltip_text = "Turn"
		b.pressed.connect(func(): if stage: stage.turn(step))
		turns.add_child(b)
	return screen

func _choice(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0,44)
	button.add_theme_stylebox_override("pressed",Look.box(Color(0.84,0.7,0.43,0.22),Look.BRASS,8,1,8))
	button.pressed.connect(action)
	return button

func _options(title: String, key: String, entries: Array, columns: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	box.add_child(Look.label(title,13,Look.ASH,500))
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	box.add_child(grid)
	creation_rows[key] = []
	for entry in entries:
		var button := _choice(entry[0],func():
			creation[key] = entry[1]
			_preview_creation())
		button.set_meta("value",entry[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",13)
		grid.add_child(button)
		creation_rows[key].append(button)
	return box

func _swatches(title: String, key: String, entries: Array, size: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	box.add_child(Look.label(title,13,Look.ASH,500))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	box.add_child(row)
	creation_rows[key] = []
	for entry in entries:
		var swatch := Button.new()
		swatch.toggle_mode = true
		swatch.tooltip_text = entry[0]
		swatch.custom_minimum_size = Vector2(size,size)
		var colour := Color(entry[2])
		swatch.add_theme_stylebox_override("normal",Look.box(colour,Color(0,0,0,0),size/2,2,0))
		swatch.add_theme_stylebox_override("hover",Look.box(colour,Look.EDGE,size/2,2,0))
		swatch.add_theme_stylebox_override("pressed",Look.box(colour,Color("f3dca2"),size/2,3,0))
		swatch.add_theme_stylebox_override("focus",Look.box(Color(0,0,0,0),Color(0,0,0,0),size/2,0,0))
		swatch.pressed.connect(func():
			creation[key] = entry[1]
			_preview_creation())
		swatch.set_meta("value",entry[1])
		row.add_child(swatch)
		creation_rows[key].append(swatch)
	return box

func _preview_creation() -> void:
	for key in creation_rows:
		var value = creation.female if key == "sex" else creation[key]
		for button in creation_rows[key]: button.set_pressed_no_signal(button.get_meta("value") == value)
	for row in beard_rows: row.visible = not creation.female
	if cities_box.get_child_count() == 0 and session: _fill_cities()
	if stage == null: return
	var worn: Array = Looks.starter(creation.female)
	if int(creation.hair) != 0: worn.append({"id":int(creation.hair),"hue":int(creation.hair_hue),"layer":11})
	if not creation.female and int(creation.beard) != 0: worn.append({"id":int(creation.beard),"hue":int(creation.beard_hue),"layer":16})
	stage.show_character({"body":401 if creation.female else 400,"hue":int(creation.skin)},worn)

# Starting cities the server offers inside the prepared region (outside it the
# world would be empty); Britain is preselected.
func _fill_cities() -> void:
	_clear(cities_box)
	var inside: Callable = scene.region_contains if scene and scene.has_method("region_contains") else Callable()
	for place: Dictionary in session.cities:
		if inside.is_valid() and not inside.call(int(place.x),int(place.y)): continue
		var city := int(place.index)
		var button := _choice(str(place.name),func():
			creation.city = city
			for other in cities_box.get_children(): other.set_pressed_no_signal(other.get_meta("value") == city))
		button.set_meta("value",city)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		cities_box.add_child(button)
		if creation.city == -1 or str(place.name) == "Britain": creation.city = city
	for other in cities_box.get_children(): other.set_pressed_no_signal(other.get_meta("value") == creation.city)
	if cities_box.get_child_count() == 0: cities_box.add_child(Look.label("No starting city inside this region.",13,Look.BLOOD,500))

func _create_character() -> void:
	var slot := -1
	for character in session.characters:
		if str(character.name).is_empty():
			slot = int(character.slot)
			break
	if slot == -1:
		message.text = "Every character slot is in use."
		return
	if creation.city == -1:
		message.text = "Choose a starting city."
		return
	message.text = "Creating your character…"
	chosen = {"slot":slot,"name":new_name.text.strip_edges()}
	session.create_character(new_name.text.strip_edges(),slot,int(creation.city),creation.female,{"skin_hue":creation.skin,"hair_id":creation.hair,"hair_hue":creation.hair_hue,"beard_id":creation.beard,"beard_hue":creation.beard_hue})

# --- 4 · loading -------------------------------------------------------
func _loading() -> Control:
	var screen := _full()
	var column := VBoxContainer.new()
	column.anchor_left = 0.5
	column.anchor_right = 0.5
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = -320
	column.offset_right = 320
	column.offset_top = -260
	column.add_theme_constant_override("separation",16)
	screen.add_child(column)
	loading_title = _heading("",34)
	loading_title.add_theme_color_override("font_color",Color("f3dca2"))
	loading_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(loading_title)
	loading_bar = preload("res://Network/ModernWindow.gd").meter(Look.BRASS,8)
	column.add_child(loading_bar)
	loading_detail = Look.label("",14,Color("c9c2b2"),500)
	loading_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(loading_detail)
	loading_tip = Look.label(TIPS.pick_random(),15,Look.ASH,500)
	loading_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(loading_tip)
	var holder := VBoxContainer.new()
	column.add_child(holder)
	screen.set_meta("message_holder",holder)
	return screen

func _process(_delta: float) -> void:
	if not visible or not screens.loading.visible or scene == null: return
	var progress: Vector2i = scene.district_progress()
	loading_bar.max_value = maxi(1,progress.y)
	loading_bar.value = progress.x
	loading_detail.text = "Districts %d of %d" % [progress.x,progress.y] if progress.y > 0 else "Preparing the world…"
	if progress.y > 0 and progress.x >= progress.y and Time.get_ticks_msec()-loading_started > 400:
		Looks.remember(account,str(chosen.get("name","")),Looks.capture(session))
		_hand_over()

# The world takes over: the stage and its viewport are freed, not hidden.
func _hand_over() -> void:
	hide()
	if viewport:
		viewport.get_parent().queue_free()
	viewport = null
	stage = null
	scene.front_end_shown(false)
	finished.emit()
