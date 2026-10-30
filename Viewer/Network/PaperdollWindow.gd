extends "res://Network/ModernWindow.gd"
# Paperdoll (C, or the server's 0x88 for anyone): the character's real 3D
# model with its worn equipment, lit and turning slowly (drag to turn), and
# the equipment slots around it with the items' 3D icons. Drag an item from
# the backpack onto the paperdoll (the model or any slot) to wear it: while
# you drag, the slot it will go to lights up (layers from your install's
# tiledata, scripts/prepare-wearables.py) and a slot flashes when the server
# equips it. Drag a worn item back to the backpack to take it off;
# double-click a worn item to use it. Your own paperdoll also shows your
# title, attributes and resistances.
const Studio = preload("res://Presentation/ItemStudio.gd")
const Artwork = preload("res://Network/Artwork.gd")
# Layer, name: the left column, then the right column.
const LEFT := [[6,"Head"],[10,"Neck"],[18,"Earrings"],[5,"Shirt"],[13,"Chest"],[17,"Tunic"],[19,"Arms"],[7,"Gloves"],[8,"Ring"],[24,"Leg armour"]]
const RIGHT := [[1,"One hand"],[2,"Two hands"],[14,"Bracelet"],[9,"Talisman"],[20,"Cloak"],[22,"Robe"],[12,"Waist"],[4,"Legs"],[23,"Skirt"],[3,"Feet"]]
static var wearables := {}
var session: Node
var serial := 0
var view := SubViewport.new()
var avatar: Node3D
var spin := 0.35
var turning := false
var slots := {}
var heading: Label
var details: Label
var frame: PanelContainer
var catcher: Control
var hint: Label
# Worn serial per layer at the last refresh, to flash newly equipped slots.
var last_worn := {}

func _ready() -> void:
	setup("paperdoll","Paperdoll",Vector2(660,690),Vector2(500,60))
	heading = Look.label("",14,Look.ASH,500)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	row.add_child(_column(LEFT))
	frame = PanelContainer.new()
	_frame_style(false)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(frame)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_turn)
	frame.add_child(container)
	# The model is the biggest drop target: items dropped on it are worn. The
	# 3D view keeps drops for its own viewport, so while an item is dragged a
	# catcher over it takes the drop (and lets clicks through otherwise).
	catcher = Control.new()
	catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catcher.set_drag_forwarding(Callable(),_can_drop_data,_drop_data)
	frame.add_child(catcher)
	hint = Look.label("",13,Look.GOLD,600)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(hint)
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	container.add_child(view)
	Studio.studio_lights(view)
	var camera := Camera3D.new()
	camera.fov = 30
	view.add_child(camera)
	camera.transform = Transform3D(Basis.looking_at(Vector3(0,0.92,0)-Vector3(0,1.05,4.3)),Vector3(0,1.05,4.3))
	camera.current = true
	row.add_child(_column(RIGHT))
	details = Look.label("",13,Look.IVORY,500)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(details)

func _column(entries: Array) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	for entry in entries:
		var tile := preload("res://Network/ItemTile.gd").new()
		tile.title = entry[1]
		tile.tooltip_text = "%s · empty" % entry[1]
		tile.used.connect(func(): if not tile.item.is_empty(): session.use_item(int(tile.item.serial)))
		column.add_child(tile)
		# After _ready, which gives tiles their backpack size.
		tile.custom_minimum_size = Vector2(62,52)
		slots[int(entry[0])] = tile
	return column

func configure(game: Node) -> void:
	session = game
	session.module("player").paperdoll.connect(func(info: Dictionary): open_for(int(info.serial)))
	session.appearance_changed.connect(func(changed: int): if visible and changed == serial: refresh())
	session.items_changed.connect(func(): if visible: refresh.call_deferred())
	session.status_changed.connect(func(_s: Dictionary): if visible and serial == int(session.player.serial): _details())
	session.module("tooltips").changed.connect(func(_c: int): if visible: _slots())
	session.ended.connect(hide)
	# A refused item says why on the paperdoll itself.
	session.transfer_result.connect(func(success: bool, description: String):
		if visible and hint.text.begins_with("Putting on"): hint.text = "" if success else description)
	if Studio.instance: Studio.instance.icon_ready.connect(func(_g: int,_h: int,_t: Texture2D): if visible: _slots())

# Your own paperdoll (C): the server is asked too, for your title.
func toggle() -> void:
	if visible and serial == int(session.player.serial):
		hide()
		return
	open_for(int(session.player.serial))
	session.send(preload("res://Network/Packets/Player.gd").open_paperdoll(serial))

func open_for(who: int) -> void:
	serial = who
	if avatar: avatar.queue_free()
	var entity: Dictionary = session.player if who == int(session.player.serial) else session.entities.get(who,{})
	avatar = preload("res://Presentation/Avatar.gd").new()
	avatar.initial_body = int(entity.get("body",400))
	view.add_child(avatar)
	refresh()
	show()
	move_to_front()

func worn() -> Dictionary:
	return session.mobile_equipment.get(serial,{})

func refresh() -> void:
	if session == null or avatar == null: return
	var entity: Dictionary = session.player if serial == int(session.player.serial) else session.entities.get(serial,{"serial":serial})
	# The portrait shows the character on foot: the mount (layer 25) is left out.
	avatar.apply_server_appearance(entity,worn().values().filter(func(item: Dictionary): return int(item.get("layer",0)) != 25),session.appearance_for(serial))
	var info: Dictionary = session.module("player").paperdolls.get(serial,{})
	title_label.text = str(session.entity_names.get(serial,"Paperdoll"))
	heading.text = str(info.get("title",""))
	_slots()
	_details()

func _slots() -> void:
	var equipped := worn()
	for layer in slots:
		var tile: Control = slots[layer]
		var item: Dictionary = equipped.get(layer,{})
		# A slot whose item just arrived flashes once.
		var now_serial := int(item.get("serial",0))
		if now_serial != 0 and last_worn.has(layer) and int(last_worn[layer]) != now_serial: _flash(tile)
		last_worn[layer] = now_serial
		tile.item = item
		tile.picture = null
		tile.payload = {}
		if not item.is_empty():
			var rendered := Studio.lookup(int(item.id),int(item.get("hue",0)))
			tile.picture = rendered if rendered else Artwork.item(int(item.id),int(item.get("hue",0)))
			var name: String = session.module("tooltips").name_of(int(item.serial))
			if name == "": session.module("tooltips").request(int(item.serial))
			tile.tooltip_text = "%s\n%s" % [name.capitalize() if name != "" else str(session.labels.item_name(int(item.id))).capitalize(),"\n".join(session.module("tooltips").lines_of(int(item.serial)).slice(1))]
			if serial == int(session.player.serial): tile.payload = {"item_serial":int(item.serial)}
		else: tile.tooltip_text = "%s · empty" % tile.title
		tile.queue_redraw()

func _details() -> void:
	if serial != int(session.player.serial):
		details.text = ""
		return
	var s: Dictionary = session.player_status
	if not s.has("str"):
		details.text = ""
		return
	details.text = "Str %d · Dex %d · Int %d   ·   Armour %d   ·   Fire %d · Cold %d · Poison %d · Energy %d   ·   Luck %d" % [int(s.get("str",0)),int(s.get("dex",0)),int(s.get("int",0)),int(s.get("armor",s.get("physical",0))),int(s.get("fire",0)),int(s.get("cold",0)),int(s.get("poison",0)),int(s.get("energy",0)),int(s.get("luck",0))]

# Wearable layer of a graphic from the install's tiledata, 0 if unknown.
static func layer_of(graphic: int) -> int:
	if wearables.is_empty() and FileAccess.file_exists("res://local-items/wearables.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://local-items/wearables.json"))
		if parsed is Dictionary: wearables = parsed
	return int(wearables.get(str(graphic),0))

# Dropping a backpack item on your paperdoll wears it. Without the local
# layer table any item is offered to the server, which decides.
func accepts_item(value: Variant) -> bool:
	if not (serial == int(session.player.serial) and value is Dictionary and value.has("item_serial")): return false
	var item: Dictionary = session.known_items.get(int(value.item_serial),{})
	if int(item.get("container",0)) == serial: return false
	var layer := layer_of(int(item.get("id",0)))
	if wearables.is_empty(): return true
	# Hair, beard, backpack and mount are not worn from the paperdoll.
	return layer != 0 and layer not in [11,16,21,25]
func take_item(value: Variant) -> void:
	if session.move_item(int(value.item_serial),serial,true):
		var layer := layer_of(int(session.known_items.get(int(value.item_serial),{}).get("id",0)))
		hint.text = "Putting on…" if layer == 0 else "Putting on: %s" % _slot_name(layer)

func _slot_name(layer: int) -> String:
	for entry in LEFT+RIGHT:
		if int(entry[0]) == layer: return str(entry[1]).to_lower()
	return "worn"

func _frame_style(lit: bool) -> void:
	frame.add_theme_stylebox_override("panel",Look.box(Color(0.02,0.025,0.035,0.9),Look.GOLD if lit else Color(0.84,0.7,0.43,0.2),10,2 if lit else 1,0))

# While an item is dragged anywhere, your paperdoll shows where it would go.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN and visible and session != null and frame != null:
		var value: Variant = get_viewport().gui_get_drag_data()
		if not accepts_item(value): return
		var layer := layer_of(int(session.known_items.get(int(value.item_serial),{}).get("id",0)))
		_frame_style(true)
		catcher.mouse_filter = Control.MOUSE_FILTER_STOP
		hint.text = "Drop to wear" if layer == 0 else "Drop to wear · %s" % _slot_name(layer)
		if slots.has(layer):
			slots[layer].chosen = true
			slots[layer].queue_redraw()
	elif what == NOTIFICATION_DRAG_END and frame != null:
		_frame_style(false)
		catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if hint.text.begins_with("Drop"): hint.text = ""
		for tile in slots.values():
			tile.chosen = false
			tile.queue_redraw()

func _flash(tile: Control) -> void:
	hint.text = ""
	tile.modulate = Color(1.8,1.6,1.1)
	tile.create_tween().tween_property(tile,"modulate",Color.WHITE,0.6)
func _can_drop_data(_at: Vector2, value: Variant) -> bool: return accepts_item(value)
func _drop_data(_at: Vector2, value: Variant) -> void: take_item(value)

func _turn(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: turning = event.pressed
	if event is InputEventMouseMotion and turning: spin += event.relative.x*0.012

func _process(delta: float) -> void:
	if not visible or avatar == null: return
	if not turning: spin += delta*0.25
	avatar.animate(false,spin,delta)
