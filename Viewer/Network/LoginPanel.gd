extends PanelContainer

var session: Node
var username := LineEdit.new()
var password := LineEdit.new()
var message := Label.new()
var choices := OptionButton.new()
var new_name := LineEdit.new()
var inventory := Label.new()
var account_controls := VBoxContainer.new()
var character_controls := VBoxContainer.new()
var world_controls := VBoxContainer.new()

func button(parent: Node, title: String, action: Callable) -> Button:
	var control := Button.new()
	control.text = title
	control.pressed.connect(action)
	parent.add_child(control)
	return control

func _ready() -> void:
	position = Vector2(875,24)
	custom_minimum_size = Vector2(380,0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04,0.065,0.09,0.96)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: style.set_content_margin(side,14)
	add_theme_stylebox_override("panel",style)
	var content := VBoxContainer.new()
	add_child(content)
	var title := Label.new()
	title.text = "BRITAIN / PLAYABLE PROOF OF CONCEPT"
	content.add_child(title)
	content.add_child(account_controls)
	username.placeholder_text = "Account name (new accounts created locally)"
	password.placeholder_text = "Password"
	password.secret = true
	account_controls.add_child(username)
	account_controls.add_child(password)
	button(account_controls,"Connect / create local account",func():
		message.text = "Connecting to ModernUO…"
		session.connect_account(username.text,password.text)
		password.clear()
		password.release_focus())
	if OS.get_environment("UO_DEV_USER") != "":
		button(account_controls,"Use local development account",func():
			message.text = "Connecting to ModernUO…"
			session.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD")))
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
		session.create_character(new_name.text,slot,city)
		new_name.release_focus())
	content.add_child(world_controls)
	world_controls.hide()
	button(world_controls,"Open backpack (B)",func(): session.open_backpack())
	world_controls.add_child(inventory)
	inventory.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		world_controls.show()
		message.text = "Online • Trammel (%d, %d, %d)\nWASD: move • Shift: run • Space: hop\nDrag: orbit • Wheel: zoom" % [position.x,position.y,position.z])
	session.entity_changed.connect(func(serial: int,position: Dictionary):
		if serial == session.player.serial:
			message.text = "Online • Trammel (%d, %d, %d)\nWASD: move • Shift: run • Space: hop\nDrag: orbit • Wheel: zoom" % [position.x,position.y,position.z])
	session.interaction_confirmed.connect(func(_description: String): inventory.text = "Backpack opened — server confirmed.")
	session.inventory_received.connect(func(items: Array):
		inventory.text = "BACKPACK • %d items\n" % items.size()
		for item in items.slice(0,12): inventory.text += "Tile 0x%04X × %d\n" % [item.id,item.amount])
	session.movement_result.connect(func(accepted: bool,_position: Dictionary):
		if not accepted: message.text = "Movement blocked by server. Position corrected.")
	session.failed.connect(func(reason: String): message.text = reason)
	session.ended.connect(func():
		account_controls.show()
		character_controls.hide()
		world_controls.hide())
