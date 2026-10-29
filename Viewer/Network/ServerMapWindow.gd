extends "res://Network/ModernWindow.gd"
# Server maps (0x90/0xF5 details, 0x56 pins): treasure maps, cartography maps
# and sea charts, drawn on parchment from the world radar map over the area
# the server gives. Pins are numbered and joined into a course. With
# "Plot course" on, click adds a pin, drag moves one, right-click removes one
# (each a 0x56 request; the server decides, ModernUO keeps the map's own rules).
const Canvas = preload("res://Network/MapCanvas.gd")
const WorldSystems = preload("res://Network/Packets/WorldSystems.gd")
const PARCHMENT := Color("e8d9b5")
var session: Node
var map := {}
var pins: Array = []
var editing := false
var canvas: Control
var plot: CheckButton
var caption: Label
var held := -1

func _ready() -> void:
	setup("servermap","Map",Vector2(520,560),Vector2(480,90))
	caption = Look.label("",13,Look.ASH,500)
	body.add_child(caption)
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel",Look.box(PARCHMENT,Color("8a6a3c"),6,2,10))
	body.add_child(frame)
	canvas = Canvas.new()
	canvas.parchment()
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.gui_input.connect(_canvas_input)
	frame.add_child(canvas)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	body.add_child(row)
	plot = CheckButton.new()
	plot.text = "Plot course"
	plot.toggled.connect(func(_on: bool): if not map.is_empty(): session.send(WorldSystems.map_pin(int(map.serial),6)))
	row.add_child(plot)
	var clear_pins := Button.new()
	clear_pins.text = "Clear course"
	clear_pins.pressed.connect(func(): if not map.is_empty() and editing: session.send(WorldSystems.map_pin(int(map.serial),5)))
	row.add_child(clear_pins)

func configure(game: Node) -> void:
	session = game
	var systems: RefCounted = session.module("world")
	systems.map_opened.connect(_open)
	systems.map_command.connect(_command)
	session.ended.connect(hide)

func _open(value: Dictionary) -> void:
	map = value
	pins.clear()
	editing = false
	plot.set_pressed_no_signal(false)
	var area := Rect2(Vector2(value.from),Vector2(value.to-value.from))
	canvas.view = area
	var pixels: Vector2 = Vector2(value.size)
	var fit := minf(440.0/maxf(pixels.x,1.0),440.0/maxf(pixels.y,1.0))
	canvas.custom_minimum_size = pixels*fit
	var name: String = session.module("tooltips").name_of(int(value.serial))
	title_label.text = name.capitalize() if name != "" else "Map"
	caption.text = "%d, %d to %d, %d" % [value.from.x,value.from.y,value.to.x,value.to.y]
	reset_size()
	_refresh()
	show()
	move_to_front()

func _command(serial: int, command: int, point: Vector2i, number: int) -> void:
	if map.is_empty() or serial != int(map.serial): return
	match command:
		1: pins.append(point)
		2: pins.insert(clampi(number,0,pins.size()),point)
		3: if number >= 0 and number < pins.size(): pins[number] = point
		4: if number >= 0 and number < pins.size(): pins.remove_at(number)
		5: pins.clear()
		7: editing = number != 0
	_refresh()

func to_world(point: Vector2) -> Vector2:
	return Vector2(map.from)+point/Vector2(map.size)*Vector2(map.to-map.from)

func to_pixels(world: Vector2) -> Vector2i:
	var share := (world-Vector2(map.from))/Vector2(map.to-map.from)
	return Vector2i((share*Vector2(map.size)).round())

func _refresh() -> void:
	if map.is_empty(): return
	var marks: Array = []
	var course: Array = []
	var treasure := "treasure" in title_label.text.to_lower()
	for i in pins.size():
		var at := to_world(Vector2(pins[i]))
		course.append(at)
		# Treasure maps mark the chest "by the red pin".
		marks.append({"at":at,"shape":"pin","color":Color("b8372b") if treasure else Look.GOLD,"label":str(i+1),"size":7.0})
	var me := Vector2(float(session.player.x)+0.5,float(session.player.y)+0.5)
	if Rect2(Vector2(map.from),Vector2(map.to-map.from)).has_point(me):
		marks.append({"at":me,"shape":"player","color":Color("3a2a18"),"size":6.0,"facing":(int(session.player.get("direction",0))&7)*PI/4})
	canvas.markers = marks
	canvas.course = course
	canvas.queue_redraw()

func _pin_at(local: Vector2) -> int:
	for i in pins.size():
		if canvas.to_local_point(to_world(Vector2(pins[i]))).distance_to(local) < 10.0: return i
	return -1

func _canvas_input(event: InputEvent) -> void:
	if map.is_empty() or not plot.button_pressed: return
	var serial := int(map.serial)
	if event is InputEventMouseButton and event.pressed:
		var hit := _pin_at(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT and hit >= 0:
			session.send(WorldSystems.map_pin(serial,4,Vector2i.ZERO,hit))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if hit >= 0: held = hit
			else: session.send(WorldSystems.map_pin(serial,1,to_pixels(canvas.to_world(event.position))))
		canvas.accept_event()
	elif event is InputEventMouseButton and not event.pressed and held >= 0:
		session.send(WorldSystems.map_pin(serial,3,to_pixels(canvas.to_world(event.position)),held))
		held = -1
		canvas.accept_event()
