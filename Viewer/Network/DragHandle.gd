extends Control
# A grip that drags something onto the quickbar: `payload` is the drop data
# ({"quickbar_slot": {...}}), `picture` the preview shown while dragging.
const Look = preload("res://Network/ModernSkin.gd")
var payload := {}
var picture: Texture2D

func _ready() -> void:
	custom_minimum_size = Vector2(22,32)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG

func _draw() -> void:
	var grip := Look.icon("grip",Look.DIM,20)
	if grip: draw_texture(grip,(size-grip.get_size())/2.0)

func _get_drag_data(_at: Vector2) -> Variant:
	if payload.is_empty(): return null
	var preview := TextureRect.new()
	preview.texture = picture if picture else Look.icon(str(payload.get("quickbar_slot",{}).get("icon","star")),Look.IVORY,32)
	preview.custom_minimum_size = Vector2(40,40)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	set_drag_preview(preview)
	return payload
