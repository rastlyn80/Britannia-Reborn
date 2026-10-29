extends Control
# One item in a modern container grid: its art, its count, a brass edge when
# chosen. Click picks it, double-click uses it, dragging carries `payload`
# (a quickbar slot) onto the quickbar.
signal picked
signal used
const Look = preload("res://Network/ModernSkin.gd")
var item := {}
var picture: Texture2D
var chosen := false
var payload := {}
var title := ""

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO: custom_minimum_size = Vector2(84,84)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	draw_style_box(Look.box(Color(0.84,0.7,0.43,0.14) if chosen else Color(1,1,1,0.03),Look.BRASS if chosen else Color(0.84,0.7,0.43,0.18),10,1),Rect2(Vector2.ZERO,size))
	if picture:
		# Classic item art is small: show it up to twice its size, never cropped.
		var drawn := picture.get_size()*minf(2.0,minf((size.x-16)/picture.get_width(),(size.y-16)/picture.get_height()))
		draw_texture_rect(picture,Rect2((size-drawn)/2.0,drawn),false)
	elif title != "":
		# Art not fetched yet: the name stands in.
		draw_multiline_string(Look.ui_font(500),Vector2(6,size.y/2.0),title,HORIZONTAL_ALIGNMENT_CENTER,size.x-12,11,2,Look.ASH)
	var amount := int(item.get("amount",1))
	if amount > 1: draw_string(Look.ui_font(700),Vector2(0,15),str(amount) if amount < 100000 else "%dk" % (amount/1000),HORIZONTAL_ALIGNMENT_RIGHT,size.x-6,12,Look.IVORY)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click: used.emit()
		else: picked.emit()
		accept_event()

func _get_drag_data(_at: Vector2) -> Variant:
	if payload.is_empty(): return null
	var preview := TextureRect.new()
	preview.texture = picture
	preview.custom_minimum_size = Vector2(44,44)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return payload

# Dropping an item on a tile drops it into the window the tile is in.
func _host() -> Node:
	var node := get_parent()
	while node and not node.has_method("accepts_item"): node = node.get_parent()
	return node
func _can_drop_data(_at: Vector2, value: Variant) -> bool:
	var host := _host()
	return host != null and host.accepts_item(value)
func _drop_data(_at: Vector2, value: Variant) -> void:
	_host().take_item(value)
