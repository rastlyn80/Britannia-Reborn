extends PanelContainer
# Shared frame for the modern windows: a brass-edged glass panel with a title
# bar to drag, a close button, and its position remembered between sessions,
# per character (Network/Profile.gd). Subclasses put their content in `body`.
const Look = preload("res://Network/ModernSkin.gd")
const PLACES := "user://ui/windows.json"
const Profile = preload("res://Network/Profile.gd")
var window_id := ""
var body := VBoxContainer.new()
var title_label := Label.new()
var title_bar := HBoxContainer.new()
var dragging := false
var drag_from := Vector2.ZERO

func setup(id: String, title: String, minimum: Vector2, default_position: Vector2) -> void:
	window_id = id
	theme = Look.theme()
	custom_minimum_size = minimum
	add_theme_stylebox_override("panel",Look.box(Color(0.055,0.063,0.078,0.95),Color(0.84,0.7,0.43,0.45),14,1,0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",0)
	add_child(column)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel",_bar_style())
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.gui_input.connect(_drag)
	column.add_child(bar)
	title_bar.add_theme_constant_override("separation",6)
	bar.add_child(title_bar)
	title_label.text = title
	title_label.add_theme_font_override("font",Look.title_font())
	title_label.add_theme_font_size_override("font_size",18)
	title_label.add_theme_color_override("font_color",Color("f3ebd9"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(title_label)
	var close := Button.new()
	close.icon = Look.icon("close",Look.ASH,16)
	close.flat = true
	close.tooltip_text = "Close (%s)" % id.capitalize()
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide)
	title_bar.add_child(close)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16 if side != "top" else 12)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(margin)
	body.add_theme_constant_override("separation",10)
	margin.add_child(body)
	position = _remembered(default_position)
	set_meta("default_position",default_position)
	add_to_group("modern_windows")
	hide()

static func _bar_style() -> StyleBoxFlat:
	var style := Look.box(Color(0.84,0.7,0.43,0.07),Color(0.84,0.7,0.43,0.25),14,0,0)
	style.border_width_bottom = 1
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 16
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

# Clicking a window raises it. Right-clicking anywhere over a window closes it, as gumps do in the native
# client; the frontmost window under the mouse wins, and child controls that
# swallow mouse events (item tiles, buttons) cannot block it. Windows opt
# out (the developer console, the house designer) or keep right-click for
# a control of theirs whose right-click is a feature (a map's walk-here).
var right_click_closes := true
var right_click_keep: Array = []

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventMouseButton and event.pressed): return
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null or not (hovered == self or is_ancestor_of(hovered)): return
	# Any press over a window brings it to the top of the stack.
	if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: move_to_front()
	if not right_click_closes or event.button_index != MOUSE_BUTTON_RIGHT: return
	for keep in right_click_keep:
		if is_instance_valid(keep) and (keep == hovered or keep.is_ancestor_of(hovered)): return
	hide()
	get_viewport().set_input_as_handled()

func toggle() -> void:
	visible = not visible
	if visible:
		move_to_front()
		_keep_on_screen()

func _drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		drag_from = event.global_position-global_position
		if event.pressed: move_to_front()
		else: _remember()
	elif event is InputEventMouseMotion and dragging:
		global_position = event.global_position-drag_from
		_keep_on_screen()

func _keep_on_screen() -> void:
	var screen := get_viewport_rect().size
	position = position.clamp(Vector2.ZERO,(screen-size).max(Vector2.ZERO))

# Places: the character's own over the last used anywhere (Profile.gd).
static func _places() -> Dictionary:
	var places := _read(PLACES)
	if Profile.active(): places.merge(_read(Profile.windows_path()),true)
	return places

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

static func _write_place(id: String, at: Vector2) -> void:
	var paths: Array = [PLACES]
	if Profile.active(): paths.append(Profile.windows_path())
	for path in paths:
		var places := _read(path)
		places[id] = [at.x,at.y]
		DirAccess.make_dir_recursive_absolute(str(path).get_base_dir())
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(places))
			file.close()

func _remembered(fallback: Vector2) -> Vector2:
	var at: Variant = _places().get(window_id,null)
	return Vector2(float(at[0]),float(at[1])) if at is Array and at.size() == 2 else fallback

func _remember() -> void:
	_write_place(window_id,position)

# A character entered: its own places (the world calls this for every window).
func restore_place() -> void:
	position = _remembered(get_meta("default_position",position))
	_keep_on_screen()

# Small shared builders.
static func chip(text: String, pressed := false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = pressed
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal",Look.box(Color(0,0,0,0),Color(0.84,0.7,0.43,0.22),999,1,6))
	b.add_theme_stylebox_override("hover",Look.box(Color(0.84,0.7,0.43,0.1),Look.BRASS,999,1,6))
	b.add_theme_stylebox_override("pressed",Look.box(Color(0.84,0.7,0.43,0.22),Look.BRASS,999,1,6))
	b.add_theme_color_override("font_color",Look.ASH)
	b.add_theme_color_override("font_pressed_color",Look.IVORY)
	b.add_theme_font_override("font",Look.ui_font(600))
	b.add_theme_font_size_override("font_size",13)
	return b

static func meter(color: Color, height := 10) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0,height)
	bar.add_theme_stylebox_override("background",Look.box(Color(1,1,1,0.08),Color(0,0,0,0),height/2,0,0))
	bar.add_theme_stylebox_override("fill",Look.box(color,Color(0,0,0,0),height/2,0,0))
	return bar

# Empty a container now (queue_free alone leaves the children counted until
# the end of the frame).
static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
