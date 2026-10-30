extends "res://Network/ModernWindow.gd"
# Any container the server opens other than your backpack (0x24, contents
# 0x3C/0x25): corpses, chests, bags inside your pack, the bank box. A grid of
# the items' 3D icons; double-click uses (opens nested bags), drag an item to
# the backpack or another container window to move it, and Take all moves
# everything into your backpack, one item at a time as the server allows.
# Loot (anything not inside your own backpack: corpses, chests, the ground's
# containers): a single click takes the item into your pack, and T takes all
# in the loot window you used last (shown on the button).
# Closes itself when the container goes away or you walk out of reach.
signal closed(serial: int)
const Studio = preload("res://Presentation/ItemStudio.gd")
const Artwork = preload("res://Network/Artwork.gd")
var session: Node
var serial := 0
var grid := GridContainer.new()
var status: Label
var taking: Array = []
var take: Button
# The loot window T acts on: the one opened or clicked last.
static var active: Node

func open(game: Node, container: int, place: Vector2) -> void:
	session = game
	serial = container
	setup("container","Container",Vector2(520,380),place)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation",8)
	body.add_child(tools)
	status = Look.label("",12,Look.ASH,500)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(status)
	take = Button.new()
	take.text = "Take all  [T]" if lootable() else "Take all"
	take.tooltip_text = "Move everything into your backpack (T)" if lootable() else "Move everything into your backpack"
	take.custom_minimum_size = Vector2(110,34)
	take.add_theme_stylebox_override("normal",Look.box(Look.BRASS,Look.BRASS,8,1,6))
	take.add_theme_color_override("font_color",Color("14110b"))
	take.pressed.connect(take_all)
	tools.add_child(take)
	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	grid.columns = 5
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	scroll.add_child(grid)
	visibility_changed.connect(func():
		if not visible:
			closed.emit(serial)
			queue_free())
	session.items_changed.connect(_changed)
	session.transfer_result.connect(_transferred)
	session.module("tooltips").changed.connect(func(changed: int): if changed == serial: _title())
	if Studio.instance: Studio.instance.icon_ready.connect(func(_g: int,_h: int,_t: Texture2D): refresh())
	session.module("tooltips").request(serial,true)
	_title()
	refresh()
	show()
	if lootable(): active = self
	gui_input.connect(func(event: InputEvent): if event is InputEventMouseButton and event.pressed and lootable(): active = self)

func _title() -> void:
	var name: String = session.module("tooltips").name_of(serial)
	if name == "": name = session.labels.item_name(int(session.world_items.get(serial,session.known_items.get(serial,{"id":0})).get("id",0)))
	title_label.text = name.capitalize() if name != "" else "Container"

func items() -> Array:
	var list: Array = session.contents_of(serial)
	list.sort_custom(func(a,b): return int(a.id) < int(b.id))
	return list

func _changed() -> void:
	if visible: refresh.call_deferred()

func refresh() -> void:
	clear(grid)
	var list := items()
	for item in list:
		var tile := preload("res://Network/ItemTile.gd").new()
		tile.item = item
		var rendered := Studio.lookup(int(item.id),int(item.get("hue",0)))
		tile.picture = rendered if rendered else Artwork.item(int(item.id),int(item.get("hue",0)))
		var name: String = session.module("tooltips").name_of(int(item.serial))
		tile.title = name.capitalize() if name != "" else str(session.labels.item_name(int(item.id))).capitalize()
		tile.tooltip_text = "%s\n%s\n%s" % [tile.title,"\n".join(session.module("tooltips").lines_of(int(item.serial)).slice(1)),"Click: take into your backpack · Double-click: use · T: take all" if lootable() else "Double-click: use · Drag: to your backpack or another container"]
		tile.payload = {"item_serial":int(item.serial),"quickbar_slot":{"steps":[{"action":"Use Item Type","graphic":int(item.id),"hue":int(item.get("hue",0)),"name":tile.title}],"aim":"cursor"}}
		tile.used.connect(func():
			tile.set_meta("used_at",Time.get_ticks_msec())
			session.use_item(int(item.serial)))
		if lootable(): tile.clicked.connect(_loot.bind(tile,int(item.serial)))
		grid.add_child(tile)
	status.text = ("%d item%s" % [list.size(),"" if list.size() == 1 else "s"] if not list.is_empty() else "Empty")+("   ·   Click an item to loot it · T: take all" if lootable() and not list.is_empty() else "")
	if taking.is_empty(): return
	status.text = "Taking %d…" % taking.size()

# Drops onto the window (or its tiles) move the dragged item into this container.
func accepts_item(value: Variant) -> bool:
	return value is Dictionary and value.has("item_serial") and int(value.item_serial) != serial and int(session.known_items.get(int(value.item_serial),{}).get("container",0)) != serial
func take_item(value: Variant) -> void:
	session.move_item(int(value.item_serial),serial)
func _can_drop_data(_at: Vector2, value: Variant) -> bool: return accepts_item(value)
func _drop_data(_at: Vector2, value: Variant) -> void: take_item(value)

# Not inside your own backpack (followed up the container chain).
func lootable() -> bool:
	if session == null: return false
	var at := serial
	for depth in 12:
		if at == int(session.backpack) or at == int(session.player.get("serial",0)): return false
		var holder: Dictionary = session.known_items.get(at,{})
		if holder.is_empty(): return true
		at = int(holder.get("container",0))
		if at == 0: return true
	return true

# A single click loots, unless it was the first half of a double-click
# (which uses the item, e.g. opens a bag inside the corpse).
func _loot(tile: Control, item: int) -> void:
	await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(tile) or not session.known_items.has(item): return
	if Time.get_ticks_msec()-int(tile.get_meta("used_at",-100000)) < 600: return
	session.move_item(item,int(session.backpack))

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T): return
	if not visible or active != self or not lootable(): return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	take_all()
	get_viewport().set_input_as_handled()

func take_all() -> void:
	taking = items().map(func(item): return int(item.serial))
	_next()

func _next() -> void:
	while not taking.is_empty() and not session.known_items.has(int(taking[0])): taking.pop_front()
	if taking.is_empty():
		refresh()
		return
	if not session.move_item(int(taking[0]),int(session.backpack)):
		get_tree().create_timer(0.3).timeout.connect(_next)
	refresh()

func _transferred(_success: bool, _text: String) -> void:
	if taking.is_empty(): return
	taking.pop_front()
	get_tree().create_timer(0.15).timeout.connect(_next)

func _process(_delta: float) -> void:
	if not visible or session == null: return
	# Gone (the corpse decayed) or out of reach: close.
	var owner: Dictionary = session.world_items.get(serial,{})
	var held: bool = session.known_items.has(serial)
	var far: bool = not owner.is_empty() and (maxi(absi(int(owner.x)-int(session.player.x)),absi(int(owner.y)-int(session.player.y))) > 3)
	if (owner.is_empty() and not held) or far or session.phase != "world": hide()
