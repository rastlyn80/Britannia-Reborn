extends PanelContainer

signal controller_toggled(enabled: bool)
signal sky_requested
var sky_button: Button
var memory := preload("res://Network/LoginMemory.gd").new()
var remember := CheckBox.new()
var session: Node
var username := LineEdit.new()
var password := LineEdit.new()
var message := Label.new()
var choices := OptionButton.new()
var new_name := LineEdit.new()
var new_sex := OptionButton.new()
var account_controls := VBoxContainer.new()
var character_controls := VBoxContainer.new()
var world_controls := VBoxContainer.new()
var controller := CheckBox.new()
var command_input := LineEdit.new()
var command_log := RichTextLabel.new()

func button(parent: Node, title: String, action: Callable) -> Button:
	var control := Button.new()
	control.text = title
	control.pressed.connect(action)
	parent.add_child(control)
	return control

func _ready() -> void:
	self.position = Vector2(875,24)
	custom_minimum_size = Vector2(380,0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04,0.065,0.09,0.96)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: style.set_content_margin(side,14)
	add_theme_stylebox_override("panel",style)
	var content := VBoxContainer.new()
	add_child(content)
	var title := Label.new()
	title.text = "BRITANNIA REBORN · BRITAIN"
	content.add_child(title)
	content.add_child(account_controls)
	username.placeholder_text = "Account name (new accounts created locally)"
	password.placeholder_text = "Password"
	password.secret = true
	account_controls.add_child(username)
	account_controls.add_child(password)
	remember.text = "Remember login on this Windows account"
	remember.button_pressed = true
	account_controls.add_child(remember)
	var saved := memory.load_login()
	username.text = saved.get("username",OS.get_environment("UO_DEV_USER"))
	password.text = saved.get("password",OS.get_environment("UO_DEV_PASSWORD"))
	remember.toggled.connect(func(enabled: bool):
		if not enabled: memory.forget())
	button(account_controls,"Forget saved login",func():
		memory.forget()
		username.clear()
		password.clear())
	controller.text = "Enable gamepad (optional)"
	content.add_child(controller)
	controller.toggled.connect(func(enabled: bool): controller_toggled.emit(enabled))
	button(account_controls,"Connect / create local account",func():
		message.text = "Connecting to ModernUO…"
		store_login()
		session.connect_account(username.text,password.text)
		password.release_focus())
	if OS.get_environment("UO_DEV_USER") != "":
		button(account_controls,"Use local development account",func():
			message.text = "Connecting to ModernUO…"
			username.text = OS.get_environment("UO_DEV_USER")
			password.text = OS.get_environment("UO_DEV_PASSWORD")
			store_login()
			session.connect_account(username.text,password.text))
	content.add_child(character_controls)
	character_controls.hide()
	character_controls.add_child(choices)
	button(character_controls,"Enter with selected character",func():
		if choices.item_count == 0: return
		var character: Dictionary = choices.get_item_metadata(choices.selected)
		message.text = "Entering Britain…"
		session.select_character(character.slot,character.name))
	new_name.placeholder_text = "New character name"
	character_controls.add_child(new_name)
	new_sex.add_item("Male human")
	new_sex.add_item("Female human")
	character_controls.add_child(new_sex)
	button(character_controls,"Create character in Britain",func():
		var slot := -1
		var city := -1
		for character in session.characters:
			if character.name.is_empty():
				slot = character.slot
				break
		for place in session.cities:
			if place.name == "Britain": city = place.index
		if slot == -1 or city == -1:
			message.text = "No free character slot or Britain starting city."
			return
		message.text = "Creating character on ModernUO…"
		session.create_character(new_name.text,slot,city,new_sex.selected==1)
		new_name.release_focus())
	content.add_child(world_controls)
	world_controls.hide()
	button(world_controls,"Open backpack (B)",func(): session.open_backpack())
	button(world_controls,"Return to Britain (F6)",func(): session.return_to_britain())
	sky_button = button(world_controls,"Sky: server time (F7)",func(): sky_requested.emit())
	var command_toggle := CheckButton.new()
	command_toggle.text = "Server commands"
	world_controls.add_child(command_toggle)
	var command_panel := VBoxContainer.new()
	world_controls.add_child(command_panel)
	command_panel.hide()
	command_toggle.toggled.connect(func(enabled: bool):
		command_panel.visible = enabled
		reset_size.call_deferred())
	command_input.placeholder_text = "[PreviewCommands"
	command_panel.add_child(command_input)
	var submit := func(_text: String = ""):
		var command := command_input.text.strip_edges()
		if session.send_command(command):
			command_log.append_text("> "+command+"\n")
			command_input.clear()
			command_input.release_focus()
		else: message.text = "Use a command beginning with [, up to 128 characters."
	command_input.text_submitted.connect(submit)
	button(command_panel,"Run command",submit)
	button(command_panel,"Commands / permissions",func(): session.send_command("[PreviewCommands"))
	button(command_panel,"Server position",func(): session.send_command("[PreviewWhere"))
	command_log.custom_minimum_size = Vector2(210,140)
	command_log.bbcode_enabled = false
	command_log.scroll_following = true
	command_panel.add_child(command_log)
	session.message_received.connect(func(text: String):
		command_log.append_text(text+"\n")
		if command_log.get_line_count() > 120: command_log.clear()
		message.text = text)
	content.add_child(message)
	message.text = "Local ModernUO • 127.0.0.1:2593\nStart the server, then connect."
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(content,"Disconnect",func():
		session.close()
		message.text = "Disconnected")
	session.characters_received.connect(func(characters: Array,_cities: Array):
		choices.clear()
		for character in characters:
			if not character.name.is_empty():
				choices.add_item(character.name)
				choices.set_item_metadata(choices.item_count-1,character)
		account_controls.hide()
		character_controls.show()
		message.text = "Choose an existing character, or create one in Britain.")
	session.entered.connect(func(position: Dictionary):
		character_controls.hide()
		controller.hide()
		custom_minimum_size.x = 240
		self.position = Vector2(1015,24)
		world_controls.show()
		reset_size.call_deferred()
		message.text = "Online / Trammel")
	session.entity_changed.connect(func(serial: int,position: Dictionary):
		if serial == session.player.serial:
			message.text = "Online / Trammel")
	var item_browser := preload("res://Network/ItemBrowser.gd").new()
	add_child(item_browser)
	item_browser.configure(session)
	var shop_panel := preload("res://Network/ShopPanel.gd").new()
	add_child(shop_panel)
	shop_panel.configure(session)
	button(world_controls,"Equipment",func(): item_browser.show_equipment())
	button(world_controls,"Server help",func(): session.request_help())
	var server_windows := CanvasLayer.new()
	add_child(server_windows)
	session.gump_received.connect(func(value: Dictionary):
		for old in server_windows.get_children():
			if int(old.data.type) == int(value.type): old.free()
		var window := preload("res://Network/GumpView.gd").new()
		server_windows.add_child(window)
		window.position = Vector2(clampi(int(value.x),0,600),clampi(int(value.y),0,100))
		window.configure(session,value))
	session.gump_closed.connect(func(type: int):
		for window in server_windows.get_children():
			if int(window.data.type) == type: window.queue_free())
	session.ended.connect(func():
		for window in server_windows.get_children(): window.queue_free())
	var target_controls := VBoxContainer.new()
	world_controls.add_child(target_controls)
	target_controls.hide()
	var target_help := Label.new()
	target_help.text = "Choose an object, or:"
	target_controls.add_child(target_help)
	button(target_controls,"Use on yourself",func(): session.target_item(int(session.player.serial)))
	button(target_controls,"Cancel action",func(): session.target_item())
	session.target_changed.connect(func(active: bool): target_controls.visible = active)
	session.ended.connect(func(): target_controls.hide())
	var interaction_help := Label.new()
	interaction_help.text = "Click objects / E: use nearest"
	interaction_help.add_theme_font_size_override("font_size",13)
	world_controls.add_child(interaction_help)

	session.movement_result.connect(func(accepted: bool,_position: Dictionary):
		if not accepted: message.text = "Movement blocked by server. Position corrected.")
	session.failed.connect(func(reason: String): message.text = reason)
	session.ended.connect(func():
		custom_minimum_size.x = 380
		self.position = Vector2(875,24)
		reset_size.call_deferred()
		account_controls.show()
		controller.show()
		character_controls.hide()
		world_controls.hide())

func store_login() -> void:
	if remember.button_pressed and not memory.save_login(username.text,password.text):
		message.text = "Could not save this login securely on Windows."
