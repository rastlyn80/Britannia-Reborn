extends PanelContainer

const Protocol = preload("res://Network/LoginProtocol.gd")
var protocol: Node
var username := LineEdit.new()
var password := LineEdit.new()
var message := Label.new()
var servers := OptionButton.new()
var server_data := []

func _ready() -> void:
	position = Vector2(855,24)
	custom_minimum_size = Vector2(400,0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04,0.065,0.09,0.96)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: style.set_content_margin(side,14)
	add_theme_stylebox_override("panel",style)
	var content := VBoxContainer.new()
	add_child(content)
	var title := Label.new()
	title.text = "MODERNUO / LOCAL CONNECTION"
	content.add_child(title)
	username.placeholder_text = "Account name"
	password.placeholder_text = "Password"
	password.secret = true
	content.add_child(username)
	content.add_child(password)
	var connect_button := Button.new()
	connect_button.text = "Connect to local server"
	content.add_child(connect_button)
	content.add_child(servers)
	servers.hide()
	content.add_child(message)
	message.text = "127.0.0.1:2593 • Login handshake only"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	protocol = Protocol.new()
	add_child(protocol)
	connect_button.pressed.connect(func():
		message.text = "Connecting…"
		servers.hide()
		protocol.start(username.text,password.text)
		password.clear())
	protocol.servers_received.connect(func(list: Array):
		server_data = list
		servers.clear()
		for server in list: servers.add_item(server.name)
		servers.show()
		message.text = "Authenticated. Select a server for the game handoff.")
	servers.item_selected.connect(func(index: int): protocol.select_server(server_data[index].index))
	# OptionButton selects the first entry automatically; this button also permits a single-server handoff.
	var select_button := Button.new()
	select_button.text = "Request game handoff"
	content.add_child(select_button)
	select_button.pressed.connect(func():
		if not server_data.is_empty(): protocol.select_server(server_data[maxi(0,servers.selected)].index))
	protocol.failed.connect(func(reason: String): message.text = reason)
	protocol.relay_received.connect(func(address: String,port: int,_token: int):
		message.text = "Game handoff received: %s:%d\nCharacter entry is the next milestone." % [address,port])
