extends PanelContainer
# The card over an item on the ground you can pick up: its picture and name,
# Take (into your backpack) and Open or Use. It follows the item on screen and
# stays while the mouse is over the item or the card. A plain click on a loose
# item takes it too, and dragging it carries it like a backpack item.
const Look = preload("res://Network/ModernSkin.gd")
signal take(serial: int)
signal use(serial: int)
var serial := 0
var anchor := Vector3.ZERO
var camera: Camera3D
var picture: TextureRect
var title: Label
var hint: Label
var use_button: Button
var linger := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",Look.box(Color(0.045,0.05,0.065,0.94),Look.BRASS,10,1,8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	add_child(row)
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2(40,40)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(picture)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",4)
	row.add_child(column)
	title = Look.label("",14,Look.IVORY,600)
	column.add_child(title)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",6)
	column.add_child(buttons)
	var take_button := Button.new()
	take_button.text = "Take"
	take_button.focus_mode = Control.FOCUS_NONE
	take_button.pressed.connect(func(): take.emit(serial))
	buttons.add_child(take_button)
	use_button = Button.new()
	use_button.focus_mode = Control.FOCUS_NONE
	use_button.pressed.connect(func(): use.emit(serial))
	buttons.add_child(use_button)
	hint = Look.label("",11,Look.ASH,500)
	column.add_child(hint)
	hide()

# Shows (or keeps) the card for an item; container items offer Open, others Use.
func present(item_serial: int, name: String, texture: Texture2D, container: bool, at: Vector3, view: Camera3D, reachable: bool) -> void:
	serial = item_serial
	anchor = at
	camera = view
	title.text = name
	picture.texture = texture
	use_button.text = "Open" if container else "Use"
	hint.text = ("Click to open · drag to move" if container else "Click to take · drag to move") if reachable else "Walk closer to take it"
	linger = 0.6
	show()
	_place()

func dismiss() -> void:
	serial = 0
	hide()

func _place() -> void:
	if camera == null or camera.is_position_behind(anchor):
		hide()
		return
	var point := camera.unproject_position(anchor)
	var screen := get_viewport_rect().size
	position = (point+Vector2(-size.x*0.5,-size.y-14)).clamp(Vector2(8,8),screen-size-Vector2(8,8))

func _process(delta: float) -> void:
	if not visible: return
	_place()
	# The mouse may travel from the item to the card without it closing.
	if get_global_rect().grow(6).has_point(get_viewport().get_mouse_position()): linger = 0.6
	linger -= delta
	if linger <= 0.0: dismiss()
