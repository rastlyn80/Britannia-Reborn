extends SceneTree
var session := preload("res://Network/GameSession.gd").new()
var started := 0
var home_confirmed := false
var position_reply := false
var latest_saved := false

func _initialize() -> void:
	started = Time.get_ticks_msec()
	root.add_child(session)
	session.failed.connect(func(reason: String):
		push_error(reason)
		quit(1))
	session.characters_received.connect(func(characters: Array,_cities: Array):
		for character in characters:
			if not character.name.is_empty():
				session.select_character(character.slot,character.name)
				return
		push_error("No existing character to recover")
		quit(1))
	session.entered.connect(func(_position: Dictionary): session.return_to_britain())
	session.position_reset.connect(func(position: Dictionary):
		if position.x == 1602 and position.y == 1591 and position.z == 20 and position.facet == 1:
			home_confirmed = true
			session.send_command("[PreviewWhere"))
	session.message_received.connect(func(message: String):
		if message.begins_with("Position: 1602, 1591, 20 / Trammel"): position_reply = true)
	var credentials := preload("res://Network/LoginMemory.gd").new().load_login()
	if "--development-account" in OS.get_cmdline_user_args(): credentials = {}
	latest_saved = credentials.has("username") and credentials.has("password")
	var user: String = credentials.get("username",OS.get_environment("UO_DEV_USER"))
	var secret: String = credentials.get("password",OS.get_environment("UO_DEV_PASSWORD"))
	credentials.clear()
	if user.is_empty() or secret.is_empty():
		push_error("No saved login available for recovery")
		quit(1)
		return
	session.connect_account(user,secret)

func _process(_delta: float) -> bool:
	if home_confirmed and position_reply:
		print("RECOVERY LIVE PASS: ","latest saved account" if latest_saved else "development account", " moved by server to Trammel (1602,1591,20); server position command confirmed")
		session.close()
		quit()
	elif Time.get_ticks_msec()-started > 20000:
		push_error("Server recovery or command reply was not confirmed")
		session.close()
		quit(1)
	return false
