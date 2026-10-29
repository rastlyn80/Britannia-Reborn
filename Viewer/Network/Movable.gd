extends RefCounted
# Makes any panel movable like the modern windows: drag it by any empty part
# (buttons, fields and lists keep their clicks), it stays on screen, and its
# place is remembered under `id` with the windows' places, per character.
# Used by the panels that are not ModernWindows: the game menu, server
# dialog cards, the slot editor, the target prompt, server gumps and the
# character sheet. The HUD stays where it is.
const Windows = preload("res://Network/ModernWindow.gd")

static func attach(panel: Control, id: String) -> void:
	panel.set_meta("movable_id",id)
	panel.add_to_group("movable_panels")
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent): _drag(panel,event))

# Where the panel was left last time, or `fallback`.
static func place(id: String, fallback: Vector2) -> Vector2:
	var at: Variant = Windows._places().get(id,null)
	return Vector2(float(at[0]),float(at[1])) if at is Array and at.size() == 2 else fallback

static func has_place(id: String) -> bool:
	return Windows._places().has(id)

static func remember(panel: Control) -> void:
	if not panel.has_meta("movable_id"): return
	Windows._write_place(str(panel.get_meta("movable_id")),panel.position)

# A character entered: panels that are already built take its places.
static func restore(panel: Control) -> void:
	if panel.has_meta("movable_id") and has_place(str(panel.get_meta("movable_id"))):
		panel.position = place(str(panel.get_meta("movable_id")),panel.position)
		keep_on_screen(panel)

# Keeps at least a grip's worth of the panel on screen.
static func keep_on_screen(panel: Control) -> void:
	var screen := panel.get_viewport_rect().size
	var grip := Vector2(minf(panel.size.x,120),minf(panel.size.y,40))
	panel.global_position = panel.global_position.clamp(grip-panel.size,screen-grip)

static func _drag(panel: Control, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			panel.set_meta("drag_from",event.global_position-panel.global_position)
			panel.set_meta("dragging",true)
		elif panel.get_meta("dragging",false):
			panel.set_meta("dragging",false)
			remember(panel)
		panel.accept_event()
	elif event is InputEventMouseMotion and panel.get_meta("dragging",false):
		panel.global_position = event.global_position-Vector2(panel.get_meta("drag_from"))
		keep_on_screen(panel)
		panel.accept_event()
