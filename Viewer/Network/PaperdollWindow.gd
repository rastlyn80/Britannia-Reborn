extends "res://Network/ModernWindow.gd"
# Paperdoll (C, or the server's 0x88 for anyone): the character's real 3D
# model with its worn equipment, lit and turning slowly (drag to turn), and
# the equipment slots around it with the items' 3D icons. Drag an item from
# the backpack onto the paperdoll to wear it, drag a worn item back to the
# backpack to take it off; double-click a worn item to use it. Your own
# paperdoll also shows your title, attributes and resistances.
const Studio = preload("res://Presentation/ItemStudio.gd")
const Artwork = preload("res://Network/Artwork.gd")
# Layer, name: the left column, then the right column.
const LEFT := [[6,"Head"],[10,"Neck"],[18,"Earrings"],[5,"Shirt"],[13,"Chest"],[19,"Arms"],[7,"Gloves"],[8,"Ring"]]
const RIGHT := [[1,"One hand"],[2,"Two hands"],[14,"Bracelet"],[20,"Cloak"],[22,"Robe"],[12,"Waist"],[4,"Legs"],[3,"Feet"]]
var session: Node
var serial := 0
var view := SubViewport.new()
var avatar: Node3D
var spin := 0.35
var turning := false
var slots := {}
var heading: Label
var details: Label

func _ready() -> void:
	setup("paperdoll","Paperdoll",Vector2(640,600),Vector2(500,80))
	heading = Look.label("",14,Look.ASH,500)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	row.add_child(_column(LEFT))
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel",Look.box(Color(0.02,0.025,0.035,0.9),Color(0.84,0.7,0.43,0.2),10,1,0))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(frame)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_turn)
	frame.add_child(container)
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
		tile.custom_minimum_size = Vector2(62,56)
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
	avatar.apply_server_appearance(entity,worn().values(),session.appearance_for(serial))
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

# Dropping a backpack item on your paperdoll wears it.
func accepts_item(value: Variant) -> bool:
	return serial == int(session.player.serial) and value is Dictionary and value.has("item_serial") and int(session.known_items.get(int(value.item_serial),{}).get("container",0)) != serial
func take_item(value: Variant) -> void:
	session.move_item(int(value.item_serial),serial,true)
func _can_drop_data(_at: Vector2, value: Variant) -> bool: return accepts_item(value)
func _drop_data(_at: Vector2, value: Variant) -> void: take_item(value)

func _turn(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: turning = event.pressed
	if event is InputEventMouseMotion and turning: spin += event.relative.x*0.012

func _process(delta: float) -> void:
	if not visible or avatar == null: return
	if not turning: spin += delta*0.25
	avatar.animate(false,spin,delta)
