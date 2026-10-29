extends "res://Network/ModernWindow.gd"
# Inspect (from the backpack or any item window): the item's 3D model, lit,
# turning slowly until you drag it; drag to rotate, wheel to zoom. Beside it
# the server's tooltip lines (name and properties), asked for at once.
const Studio = preload("res://Presentation/ItemStudio.gd")
var session: Node
var world_items: Node3D
var viewport := SubViewport.new()
var stage := Node3D.new()
var camera := Camera3D.new()
var model: Node3D
var box := AABB()
var yaw := 0.6
var pitch := -0.35
var zoom := 1.0
var spinning := true
var turning := false
var serial := 0
var title: Label
var lines: VBoxContainer
var classic: TextureRect

func _ready() -> void:
	setup("inspect","Inspect",Vector2(760,470),Vector2(420,140))
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation",16)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(split)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel",Look.box(Color(0.02,0.025,0.035,0.9),Color(0.84,0.7,0.43,0.2),10,1,0))
	frame.custom_minimum_size = Vector2(420,380)
	split.add_child(frame)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_turn)
	frame.add_child(container)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)
	Studio.studio_lights(viewport)
	viewport.add_child(stage)
	camera.fov = 30
	viewport.add_child(camera)
	camera.current = true
	classic = TextureRect.new()
	classic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	classic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	classic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	classic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	classic.hide()
	frame.add_child(classic)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation",8)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(side)
	title = Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font",Look.title_font())
	title.add_theme_font_size_override("font_size",20)
	title.add_theme_color_override("font_color",Color("f3dca2"))
	side.add_child(title)
	lines = VBoxContainer.new()
	lines.add_theme_constant_override("separation",4)
	side.add_child(lines)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	side.add_child(Look.label("Drag to turn · wheel to zoom",12,Look.DIM,500))

func configure(game: Node, items: Node3D) -> void:
	session = game
	world_items = items
	var tooltips: RefCounted = session.module("tooltips")
	tooltips.changed.connect(func(changed: int): if visible and changed == serial: _describe())
	session.ended.connect(hide)

func inspect(item: Dictionary) -> void:
	serial = int(item.get("serial",0))
	if model: model.queue_free()
	model = world_items.studio_model(int(item.id),int(item.get("hue",0)),int(item.get("amount",1))) if world_items else null
	var real := model != null and str(model.get_meta("studio_quality","")) == "model"
	classic.visible = not real
	if model and not real:
		model.free()
		model = null
	if model:
		stage.add_child(model)
		box = Studio.bounds(model)
	else: classic.texture = preload("res://Network/Artwork.gd").item(int(item.id),int(item.get("hue",0)))
	yaw = 0.6
	pitch = -0.35
	zoom = 1.0
	spinning = true
	session.module("tooltips").request(serial,true)
	_describe()
	show()
	move_to_front()

func _describe() -> void:
	var tooltips: RefCounted = session.module("tooltips")
	var name: String = tooltips.name_of(serial)
	title.text = name.capitalize() if name != "" else str(session.labels.item_name(int(session.known_items.get(serial,{}).get("id",0)))).capitalize()
	clear(lines)
	var rest: Array = tooltips.lines_of(serial).slice(1)
	for line in rest:
		var label := Look.label(str(line),14,Look.IVORY,500)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lines.add_child(label)
	if rest.is_empty(): lines.add_child(Look.label("No further properties.",13,Look.ASH,500))

func _turn(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			turning = event.pressed
			spinning = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom = maxf(0.45,zoom*0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom = minf(2.2,zoom*1.1)
	if event is InputEventMouseMotion and turning:
		yaw -= event.relative.x*0.01
		pitch = clampf(pitch-event.relative.y*0.01,-1.4,1.2)

func _process(delta: float) -> void:
	if not visible or model == null: return
	if spinning: yaw += delta*0.5
	Studio.frame(camera,box,yaw,pitch,1.05,float(viewport.size.x)/maxf(1.0,float(viewport.size.y)))
	var center := box.get_center()
	camera.position = center+(camera.position-center)*zoom
	camera.near = maxf(0.005,box.size.length()*0.01)
