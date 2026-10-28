extends Control
# One quickbar slot: icon (native item art for items, line icons otherwise),
# its key in the corner, what is left in your pack, and a red frame with the
# reason on hover when it cannot be used. Click to use, right-click to edit,
# drag to move; items, skills and spells dropped on it fill it.
const Look = preload("res://Network/ModernSkin.gd")
const Catalog = preload("res://Network/ActionCatalog.gd")
const Artwork = preload("res://Network/Artwork.gd")
const AIMS := {"cursor":"","self":"on yourself","last":"on your last target","hover":"on what is under the mouse"}
var bar: Node
var row := 0
var index := 0
var data := {}
var key := ""
var layer := ""
var picture: Texture2D
var count := -1
var usable := true
var reason := ""
var active := false
const SHORT_KEYS := {"Minus":"−","Equal":"=","BracketLeft":"[","BracketRight":"]","Semicolon":";","Apostrophe":"'","Comma":",","Period":".","Slash":"/","Backslash":"\\","QuoteLeft":"`","Space":"Spc","Escape":"Esc"}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func steps() -> Array:
	return data.get("steps",[])

func show_slot(value: Dictionary, bound_key: String, shown_layer: String) -> void:
	data = value
	key = bound_key
	layer = shown_layer
	picture = null
	count = -1
	usable = true
	reason = ""
	active = false
	if not steps().is_empty():
		var first: Dictionary = steps()[0]
		if str(first.get("action","")) in ["Use Item Type","Use Item"] and Artwork.item(int(first.get("graphic",0)),int(first.get("hue",0))):
			picture = Artwork.item(int(first.get("graphic",0)),int(first.get("hue",0)))
		else:
			picture = Look.icon(str(data.get("icon",Catalog.icon_for(first))),_ink(first),30)
		if bar and bar.runner:
			var state: Dictionary = bar.runner.availability(steps())
			count = int(state.count)
			usable = bool(state.ok)
			reason = str(state.reason)
			active = bool(state.get("active",false))
	tooltip_text = _describe()
	queue_redraw()

func _ink(first: Dictionary) -> Color:
	match Catalog.icon_for(first):
		"heal": return Look.HERB
		"flame": return Color("f0a35e")
		"bolt", "book": return Color("8fb8ff")
		"rune": return Color("c9a8f0")
		"potion": return Look.GOLD
	return Look.IVORY

func _describe() -> String:
	var where := "%s set, key %s" % [bar.LAYER_NAMES.get(layer,"Base") if bar else "Base",("%s+%s" % [layer.capitalize(),key]) if layer != "" and key != "" else (key if key != "" else "none")]
	if steps().is_empty(): return "Empty slot (%s).\nRight-click to choose an action, or drag one here." % where
	var lines := []
	if str(data.get("label","")) != "": lines.append(str(data.label))
	lines.append(" → ".join(steps().map(func(s): return Catalog.describe(s))))
	if str(AIMS.get(str(data.get("aim","cursor")),"")) != "": lines.append("Targets %s" % AIMS[str(data.aim)])
	if not usable and reason != "": lines.append(reason)
	lines.append("(%s) · Right-click to edit · Drag to move" % where)
	return "\n".join(lines)

func _draw() -> void:
	var empty := steps().is_empty()
	var fill := Color(1,1,1,0.02) if empty else (Color(0.85,0.35,0.29,0.14) if not usable else Color(1,1,1,0.05))
	var edge := Color(0.84,0.7,0.43,0.22) if empty else (Look.BLOOD if not usable else Look.EDGE)
	if active:
		fill = Color(0.3,0.55,0.94,0.2)
		edge = Look.SKY
	if bar and bar.flashing(row,layer,index):
		fill = Color(0.84,0.7,0.43,0.35)
		edge = Look.BRASS
	draw_style_box(Look.box(fill,edge,8,1),Rect2(Vector2.ZERO,size))
	if picture:
		var side := minf(size.x,size.y)-22.0
		var art := Rect2((size-Vector2(side,side))/2.0,Vector2(side,side))
		var tint := Color(1,1,1,0.4) if not usable else Color.WHITE
		draw_texture_rect(picture,art,false,tint)
	elif empty:
		var plus := Look.icon("plus",Color("5e594f"),20)
		if plus: draw_texture(plus,(size-plus.get_size())/2.0)
	var font := Look.ui_font(700)
	if key != "": draw_string(font,Vector2(4,12),str(SHORT_KEYS.get(key,key)).left(3),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Look.ASH)
	if count >= 0:
		var text := str(count) if count < 10000 else "%dk" % (count/1000)
		draw_string(font,Vector2(0,size.y-4),text,HORIZONTAL_ALIGNMENT_RIGHT,size.x-4,11,Look.BLOOD if count == 0 else Look.IVORY)
	if str(data.get("aim","cursor")) != "cursor" and not empty:
		draw_circle(Vector2(size.x-7,7),4.0,Look.HERB if data.aim == "self" else (Look.BLOOD if data.aim == "last" else Color("8fc1ff")))

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton: return
	# Right-click edits; a left click released on the slot (not a drag) uses it.
	if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		bar.edit_requested.emit(row,layer,index)
		accept_event()
	elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Rect2(Vector2.ZERO,size).has_point(event.position):
		bar.use(row,layer,index)
		accept_event()

func _get_drag_data(_at: Vector2) -> Variant:
	if steps().is_empty(): return null
	var preview := TextureRect.new()
	preview.texture = picture
	preview.custom_minimum_size = Vector2(40,40)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	set_drag_preview(preview)
	return {"quickbar":[row,layer,index]}

func _can_drop_data(_at: Vector2, value: Variant) -> bool:
	return value is Dictionary and (value.has("quickbar") or value.has("quickbar_slot"))

func _drop_data(_at: Vector2, value: Variant) -> void:
	if value.has("quickbar"): bar.move_slot(value.quickbar,[row,layer,index])
	else: bar.set_slot(row,layer,index,value.quickbar_slot)
