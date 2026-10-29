extends "res://Network/ModernWindow.gd"
# Backpack (B): what you carry as a grid of the items' own art with their
# counts (drawn from the world's 3D models where one exists, classic art
# otherwise), search and sort, your weight against your limit, and the chosen
# item's details with Use, Drop and Add to quickbar. Drag any item onto the
# quickbar: the slot uses an item of that kind ("a bandage"), whichever stack.
signal add_requested(slot: Dictionary)
signal inspect_requested(item: Dictionary)
const Studio = preload("res://Presentation/ItemStudio.gd")
const Artwork = preload("res://Network/Artwork.gd")
var session: Node
var search := LineEdit.new()
var sort := "Kind"
var sort_chips := {}
var grid := GridContainer.new()
var detail := VBoxContainer.new()
var weight_label: Label
var weight_bar: ProgressBar
var chosen := 0
var labels := {}

func _ready() -> void:
	setup("backpack","Backpack",Vector2(900,560),Vector2(860,120))
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation",6)
	body.add_child(tools)
	search.placeholder_text = "Search"
	search.custom_minimum_size = Vector2(200,34)
	search.text_changed.connect(func(_t: String): refresh())
	tools.add_child(search)
	tools.add_child(Look.label("Sort",12,Look.ASH,600))
	for name in ["Kind","Name","Amount"]:
		var c := chip(name,name == sort)
		c.pressed.connect(func():
			sort = name
			refresh())
		tools.add_child(c)
		sort_chips[name] = c
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(spacer)
	var weight := VBoxContainer.new()
	weight.custom_minimum_size = Vector2(200,0)
	tools.add_child(weight)
	weight_label = Look.label("",12,Look.IVORY,600)
	weight.add_child(weight_label)
	weight_bar = meter(Look.AMBER,6)
	weight.add_child(weight_bar)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation",16)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(split)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	grid.columns = 6
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	scroll.add_child(grid)
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel",Look.box(Color(1,1,1,0.03),Color(0.84,0.7,0.43,0.2),10,1,14))
	side.custom_minimum_size = Vector2(270,0)
	split.add_child(side)
	detail.add_theme_constant_override("separation",10)
	side.add_child(detail)

func configure(game: Node) -> void:
	session = game
	session.items_changed.connect(func(): if visible: refresh())
	session.status_changed.connect(func(_s: Dictionary): if visible: _weight())
	session.item_label_received.connect(func(serial: int, label: String): labels[serial] = label)
	session.ended.connect(hide)
	var tooltips := _tooltips()
	if tooltips: tooltips.changed.connect(func(changed: int): if visible and changed == chosen: _show_chosen())
	if Studio.instance:
		Studio.instance.icon_ready.connect(func(graphic: int, hue: int, texture: Texture2D):
			if not visible: return
			for tile in grid.get_children():
				if "item" in tile and int(tile.item.id) == graphic and int(tile.item.get("hue",0)) == hue:
					tile.picture = texture
					tile.queue_redraw()
			if session.known_items.has(chosen) and int(session.known_items[chosen].id) == graphic: _show_chosen())

# The server tooltips (protocol module), when the session has them.
func _tooltips() -> RefCounted:
	return session.module("tooltips") if session and session.has_method("module") else null

# The item's 3D icon when ready, its classic art meanwhile or otherwise.
static func picture_for(item: Dictionary) -> Texture2D:
	var rendered := Studio.lookup(int(item.id),int(item.get("hue",0)))
	return rendered if rendered else Artwork.item(int(item.id),int(item.get("hue",0)))

func toggle() -> void:
	super.toggle()
	if visible:
		# The server sends the contents when the pack is opened.
		if session and session.contents_of(int(session.backpack)).is_empty(): session.open_backpack()
		refresh()

func name_of(item: Dictionary) -> String:
	var named: String = _tooltips().name_of(int(item.serial)) if _tooltips() else ""
	var text := named if named != "" else str(labels.get(int(item.serial),session.labels.item_name(int(item.id))))
	return text.capitalize() if text != "" else "Item"

# Items dragged from a container window come into the pack.
func accepts_item(value: Variant) -> bool:
	return value is Dictionary and value.has("item_serial") and int(session.known_items.get(int(value.item_serial),{}).get("container",0)) != int(session.backpack)
func take_item(value: Variant) -> void:
	session.move_item(int(value.item_serial),int(session.backpack))
func _can_drop_data(_at: Vector2, value: Variant) -> bool: return accepts_item(value)
func _drop_data(_at: Vector2, value: Variant) -> void: take_item(value)

func _weight() -> void:
	var s: Dictionary = session.player_status
	var limit := int(s.get("weight_max",0))
	weight_label.text = "Weight %d / %d stones" % [int(s.get("weight",0)),limit] if limit > 0 else "Weight %d stones" % int(s.get("weight",0))
	weight_bar.max_value = maxf(1.0,float(limit))
	weight_bar.value = float(s.get("weight",0))

func items() -> Array:
	var query := search.text.strip_edges().to_lower()
	var list: Array = session.contents_of(int(session.backpack)).filter(func(item): return query == "" or query in name_of(item).to_lower())
	match sort:
		"Name": list.sort_custom(func(a,b): return name_of(a) < name_of(b))
		"Amount": list.sort_custom(func(a,b): return int(a.get("amount",1)) > int(b.get("amount",1)))
		_: list.sort_custom(func(a,b): return int(a.id) < int(b.id) or (int(a.id) == int(b.id) and int(a.serial) < int(b.serial)))
	return list

func refresh() -> void:
	if session == null: return
	for name in sort_chips: sort_chips[name].set_pressed_no_signal(name == sort)
	clear(grid)
	_weight()
	var list := items()
	if not session.known_items.has(chosen) and not list.is_empty(): chosen = int(list[0].serial)
	for item in list: grid.add_child(_tile(item))
	if list.is_empty(): grid.add_child(Look.label("Nothing here yet." if search.text == "" else "Nothing matches.",14,Look.ASH))
	_show_chosen()

# Picking an item only updates the highlight and details (the grid stays, so
# a double-click lands on the same tile).
func _show_chosen() -> void:
	for tile in grid.get_children():
		if "item" in tile:
			tile.chosen = int(tile.item.serial) == chosen
			tile.queue_redraw()
	clear(detail)
	if session.known_items.has(chosen): _detail(session.known_items[chosen])

func _slot_for(item: Dictionary) -> Dictionary:
	return {"steps":[{"action":"Use Item Type","graphic":int(item.id),"hue":int(item.get("hue",0)),"name":name_of(item)}],"aim":"cursor"}

func _tile(item: Dictionary) -> Control:
	var tile := preload("res://Network/ItemTile.gd").new()
	tile.item = item
	tile.picture = picture_for(item)
	tile.chosen = int(item.serial) == chosen
	tile.title = name_of(item)
	tile.tooltip_text = "%s\nClick: details · Double-click: use · Drag: onto the quickbar" % name_of(item)
	tile.payload = {"quickbar_slot":_slot_for(item),"item_serial":int(item.serial)}
	tile.picked.connect(func():
		chosen = int(item.serial)
		_show_chosen())
	tile.used.connect(func(): session.use_item(int(item.serial)))
	return tile

func _detail(item: Dictionary) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation",10)
	detail.add_child(head)
	var art := TextureRect.new()
	art.texture = picture_for(item)
	art.custom_minimum_size = Vector2(72,72)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(art)
	var title := Label.new()
	title.text = name_of(item)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font",Look.title_font())
	title.add_theme_font_size_override("font_size",18)
	title.add_theme_color_override("font_color",Color("f3ebd9"))
	head.add_child(title)
	var amount := int(item.get("amount",1))
	if amount > 1: detail.add_child(Look.label("%s in this stack" % str(amount),14,Look.IVORY,500))
	var same := 0
	for other in session.contents_of(int(session.backpack)):
		if int(other.id) == int(item.id): same += maxi(1,int(other.get("amount",1)))
	if same > amount: detail.add_child(Look.label("%d of this kind in the pack" % same,13,Look.ASH,500))
	# The server's tooltip: every property line under the name.
	var properties: Array = _tooltips().lines_of(int(item.serial)).slice(1) if _tooltips() else []
	if properties.is_empty() and _tooltips(): _tooltips().request(int(item.serial),true)
	for line in properties:
		var property := Look.label(str(line),13,Look.IVORY,500)
		property.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(property)
	if properties.is_empty() and str(labels.get(int(item.serial),"")) != "" and str(labels[int(item.serial)]).to_lower() != session.labels.item_name(int(item.id)).to_lower():
		var label := Look.label(str(labels[int(item.serial)]),13,Look.ASH,500)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(spacer)
	var use := Button.new()
	use.text = "Use"
	use.custom_minimum_size = Vector2(0,42)
	use.add_theme_stylebox_override("normal",Look.box(Look.BRASS,Look.BRASS,8,1,8))
	use.add_theme_color_override("font_color",Color("14110b"))
	use.pressed.connect(func(): session.use_item(int(item.serial)))
	detail.add_child(use)
	var inspect := Button.new()
	inspect.text = "Inspect in 3D"
	inspect.custom_minimum_size = Vector2(0,38)
	inspect.pressed.connect(func(): inspect_requested.emit(item))
	detail.add_child(inspect)
	var add := Button.new()
	add.text = "Add to quickbar"
	add.custom_minimum_size = Vector2(0,38)
	add.pressed.connect(func(): add_requested.emit(_slot_for(item)))
	detail.add_child(add)
	var drop := Button.new()
	drop.text = "Drop at your feet"
	drop.custom_minimum_size = Vector2(0,38)
	drop.pressed.connect(func():
		if drop.text == "Drop at your feet":
			drop.text = "Click again to drop %s" % name_of(item)
			return
		session.move_item(int(item.serial),0))
	detail.add_child(drop)
