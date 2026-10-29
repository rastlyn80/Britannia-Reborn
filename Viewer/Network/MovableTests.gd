extends SceneTree
# Movable panels (Network/Movable.gd): dragging by the background moves the
# panel, keeps it on screen and remembers it; the place comes back. Uses a
# throwaway id and removes it, so real window places are untouched.
const Movable = preload("res://Network/Movable.gd")
const ID := "movable-test-panel"
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS ",label)
	else:
		failures += 1
		push_error("FAIL "+label)

func _initialize() -> void: call_deferred("run")

func press(panel: Control, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.global_position = at
	event.position = at
	Movable._drag(panel,event)

func move(panel: Control, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.global_position = at
	event.position = at
	Movable._drag(panel,event)

func run() -> void:
	# A known screen, as headless windows are tiny.
	root.size = Vector2i(1600,900)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200,100)
	root.add_child(panel)
	await process_frame
	panel.position = Vector2(100,100)
	Movable.attach(panel,ID)
	press(panel,Vector2(110,110),true)
	move(panel,Vector2(310,210))
	press(panel,Vector2(310,210),false)
	check(panel.position == Vector2(300,200),"Dragging the background moves the panel (%s)" % panel.position)
	check(Movable.has_place(ID) and Movable.place(ID,Vector2.ZERO) == Vector2(300,200),"Its place is remembered")
	press(panel,Vector2(310,210),true)
	move(panel,Vector2(-5000,-5000))
	press(panel,Vector2(-5000,-5000),false)
	check(panel.position.x+panel.size.x > 0 and panel.position.y+panel.size.y > 0,"A panel cannot be dragged off screen")
	check(Movable.place("never-placed",Vector2(7,8)) == Vector2(7,8),"An unplaced panel keeps its default")
	# Clean up the throwaway place.
	var places: Dictionary = preload("res://Network/ModernWindow.gd")._places()
	places.erase(ID)
	var file := FileAccess.open(preload("res://Network/ModernWindow.gd").PLACES,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(places))
		file.close()
	check(not Movable.has_place(ID),"The test leaves no place behind")
	print("MOVABLE TESTS: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
