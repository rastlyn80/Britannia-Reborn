extends SceneTree
# Front end and in-world menu checks with a stand-in session (no server): the
# four screens, remembered looks, creation choices and cities inside the
# region, the hand-over to the world, logging out, the game menu and the
# target prompt.
const Looks = preload("res://Network/CharacterLooks.gd")
const ACCOUNT := "frontend-test"
var failures := 0
var checks := 0

class FakeSession extends Node:
	signal failed(reason: String)
	signal characters_received(characters: Array, cities: Array)
	signal entered(position: Dictionary)
	signal ended
	signal target_changed(active: bool)
	signal message_received(text: String)
	var phase := "idle"
	var characters := [{"slot":0,"name":"Britain Explorer"},{"slot":1,"name":"Gwenllian"},{"slot":2,"name":""}]
	var cities := [{"index":0,"name":"Britain","x":1496,"y":1628},{"index":1,"name":"Trinsic","x":1867,"y":2780},{"index":2,"name":"Moonglow","x":4442,"y":1172}]
	var player := {"serial":7,"x":1602,"y":1591,"body":401,"hue":1021}
	var mobile_equipment := {7:{11:{"id":0x203c,"hue":1147,"layer":11,"serial":70}}}
	var entity_names := {}
	var connected := []
	var created := []
	var selected := []
	var targeted := []
	var closed := 0
	func connect_account(user: String, secret: String) -> void: connected = [user,secret]
	func select_character(slot: int, name: String) -> void: selected = [slot,name]
	func create_character(name: String, slot: int, city: int, female := false, look := {}) -> void: created = [name,slot,city,female,look]
	func target_item(serial := 0) -> bool:
		targeted.append(serial)
		return true
	func close() -> void:
		closed += 1
		phase = "idle"
		ended.emit()

class FakeScene extends Node3D:
	var shown := []
	var progress := Vector2i.ZERO
	func front_end_shown(value: bool) -> void: shown.append(value)
	func region_contains(x: int, y: int) -> bool: return Rect2i(1024,1280,1024,1792).has_point(Vector2i(x,y))
	func district_progress() -> Vector2i: return progress
	func open_settings() -> void: pass

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS ",label)
	else:
		failures += 1
		push_error("FAIL "+label)

func _initialize() -> void: call_deferred("run")

func frames(count := 3) -> void:
	for i in count: await process_frame

func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Looks._path(ACCOUNT)))
	check(Looks.place(1602,1591) == "Britain" and Looks.place(1867,2780) == "Trinsic" and Looks.place(1700,2200) == "The road to Trinsic","Places read as towns or the road between them")
	Looks.remember(ACCOUNT,"Gwenllian",{"body":401,"hue":1021,"worn":[],"place":"Trinsic"})
	check(Looks.load_all(ACCOUNT).get("Gwenllian",{}).get("place","") == "Trinsic","A character's look is remembered per account")
	var session := FakeSession.new()
	root.add_child(session)
	var scene := FakeScene.new()
	root.add_child(scene)
	var panel: Control = preload("res://Network/LoginPanel.gd").new()
	panel.session = session
	var front: Control = preload("res://Network/FrontEnd.gd").new()
	root.add_child(front)
	front.configure(session,scene,panel)
	await frames()
	check(front.screens.signin.visible and not front.screens.characters.visible,"The front end opens on the sign-in screen")
	check(front.size.x > 0 and front.size.y > 0,"The front end fills the window")
	front.username.text = ACCOUNT
	front.password.text = "secret"
	front._enter()
	check(session.connected == [ACCOUNT,"secret"],"Enter connects with the typed account")
	session.phase = "characters"
	session.characters_received.emit(session.characters,session.cities)
	await frames()
	check(front.screens.characters.visible,"The character list follows the server's list")
	var named: Array = front.roster.get_children().filter(func(b): return b is Button and b.toggle_mode)
	check(named.size() == 2,"Every named character has an entry; empty slots do not")
	check(front.roster.get_children().any(func(b): return b is Button and "Create" in b.text),"A free slot offers Create a new character")
	check(front.chosen.get("name","") == "Britain Explorer","The first character is chosen")
	front._choose(session.characters[1])
	check("Trinsic" in front.shown_detail.text,"A remembered character shows where it was last seen")
	front.go("create")
	await frames()
	check(front.cities_box.get_children().map(func(b): return b.text) == ["Britain","Trinsic"],"Only starting cities inside the prepared region are offered")
	check(front.creation.city == 0,"Britain is preselected")
	front.creation.female = true
	front._preview_creation()
	check(front.beard_rows.all(func(row): return not row.visible),"Beard choices hide for female characters")
	front.new_name.text = "Elowen Vale"
	front.creation.city = 1
	front._create_character()
	check(session.created.size() == 5 and session.created[0] == "Elowen Vale" and session.created[1] == 2 and session.created[2] == 1 and session.created[3] == true,"Create sends the name, the free slot, the city and the body")
	check(int(session.created[4].hair_id) == 0x203c and int(session.created[4].skin_hue) == 1021,"Create sends the chosen hair and skin")
	session.phase = "world"
	session.entered.emit(session.player)
	await frames()
	check(front.screens.loading.visible and front.loading_title.text == "Britain","Entering shows the loading screen for the real position")
	scene.progress = Vector2i(4,9)
	front.loading_started = Time.get_ticks_msec()-1000
	await frames()
	check(front.visible,"The front end waits for every near district")
	var done := [false]
	front.finished.connect(func(): done[0] = true)
	scene.progress = Vector2i(9,9)
	await frames()
	check(done[0] and not front.visible and scene.shown.back() == false,"The world takes over once the near districts are installed")
	check(front.stage == null and front.viewport == null,"The front-end stage is freed in the world")
	check(Looks.load_all(ACCOUNT).has("Elowen Vale"),"The look is remembered on entering")
	session.close()
	await frames()
	check(front.visible and front.screens.signin.visible and scene.shown.back() == true,"Logging out returns to the sign-in screen")
	var menu: Control = preload("res://Network/GameMenu.gd").new()
	root.add_child(menu)
	menu.open()
	await frames()
	var labels: Array = menu.body.find_children("*","Button",true,false).map(func(b): return b.text)
	check(labels.any(func(t): return t.begins_with("Resume")) and labels.any(func(t): return t.begins_with("Log out")) and labels.any(func(t): return t.begins_with("Quit")),"The game menu offers Resume, Log out and Quit")
	menu._keys()
	check(menu.body.find_children("*","GridContainer",true,false).size() == 1,"Keys and help lists the key bindings")
	menu.close()
	var prompt: Control = preload("res://Network/TargetPrompt.gd").new()
	root.add_child(prompt)
	prompt.configure(session)
	session.target_changed.emit(true)
	check(prompt.visible,"The target prompt appears when the server asks for a target")
	prompt.find_children("*","Button",true,false)[0].pressed.emit()
	check(session.targeted == [7],"Self answers the cursor with the player")
	session.target_changed.emit(false)
	check(not prompt.visible,"The prompt hides when the cursor is answered")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Looks._path(ACCOUNT)))
	print("FRONT END TESTS: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
