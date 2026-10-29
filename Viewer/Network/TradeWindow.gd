extends "res://Network/ModernWindow.gd"
# Secure trade (0x6F): your offer and theirs side by side as 3D-icon grids,
# each with its accept state; drag items from your backpack onto your side,
# set gold to offer, Accept or Cancel. Either side changing the offer clears
# both acceptances (the server decides); the trade completes when both accept.
const Studio = preload("res://Presentation/ItemStudio.gd")
const Artwork = preload("res://Network/Artwork.gd")
const Social = preload("res://Network/Packets/Social.gd")
var session: Node
var trade := {}
var mine := GridContainer.new()
var theirs := GridContainer.new()
var mine_state: Label
var theirs_state: Label
var their_title: Label
var accept: Button
var gold := SpinBox.new()

func _ready() -> void:
	setup("trade","Trade",Vector2(700,400),Vector2(440,150))
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation",14)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(split)
	var left := _side("Your offer",mine)
	mine_state = left[1]
	split.add_child(left[0])
	var right := _side("Their offer",theirs)
	theirs_state = right[1]
	their_title = right[2]
	split.add_child(right[0])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	body.add_child(row)
	row.add_child(Look.label("Gold to offer",13,Look.ASH,600))
	gold.max_value = 1000000
	gold.custom_minimum_size = Vector2(140,36)
	gold.value_changed.connect(func(value: float): if not trade.is_empty(): session.send(Social.trade_gold(int(trade.mine),int(value))))
	row.add_child(gold)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var cancel := Button.new()
	cancel.text = "Cancel trade"
	cancel.custom_minimum_size = Vector2(130,40)
	cancel.pressed.connect(func(): if not trade.is_empty(): session.send(Social.trade_cancel(int(trade.mine))))
	row.add_child(cancel)
	accept = Button.new()
	accept.toggle_mode = true
	accept.text = "Accept"
	accept.custom_minimum_size = Vector2(130,40)
	accept.add_theme_stylebox_override("pressed",Look.box(Look.BRASS,Look.BRASS,8,1,6))
	accept.add_theme_color_override("font_pressed_color",Color("14110b"))
	accept.toggled.connect(func(on: bool): if not trade.is_empty(): session.send(Social.trade_accept(int(trade.mine),on)))
	row.add_child(accept)

func _side(heading: String, grid: GridContainer) -> Array:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",Look.box(Color(1,1,1,0.03),Color(0.84,0.7,0.43,0.2),10,1,10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	var title := Look.label(heading,15,Look.GOLD,700)
	column.add_child(title)
	var state := Look.label("",12,Look.ASH,600)
	column.add_child(state)
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	column.add_child(grid)
	return [panel,state,title]

func configure(game: Node) -> void:
	session = game
	var social: RefCounted = session.module("social")
	social.trade_changed.connect(func(value: Dictionary):
		trade = value
		refresh()
		show()
		move_to_front())
	social.trade_closed.connect(func(container: int): if not trade.is_empty() and (container == int(trade.mine) or container == int(trade.theirs)): _end())
	session.items_changed.connect(func(): if visible: refresh.call_deferred())
	session.ended.connect(_end)
	if Studio.instance: Studio.instance.icon_ready.connect(func(_g: int,_h: int,_t: Texture2D): if visible: refresh())

func _end() -> void:
	trade = {}
	hide()

func refresh() -> void:
	if trade.is_empty(): return
	their_title.text = "%s's offer" % (str(trade.name) if str(trade.name) != "" else str(session.entity_names.get(int(trade.them),"Their")))
	mine_state.text = "Accepted" if trade.mine_accepted else "Not accepted"
	theirs_state.text = "Accepted" if trade.theirs_accepted else "Not accepted"
	theirs_state.add_theme_color_override("font_color",Look.HERB if trade.theirs_accepted else Look.ASH)
	accept.set_pressed_no_signal(trade.mine_accepted)
	_fill(mine,int(trade.mine))
	_fill(theirs,int(trade.theirs))

func _fill(grid: GridContainer, container: int) -> void:
	clear(grid)
	for item in session.contents_of(container):
		var tile := preload("res://Network/ItemTile.gd").new()
		tile.item = item
		var rendered := Studio.lookup(int(item.id),int(item.get("hue",0)))
		tile.picture = rendered if rendered else Artwork.item(int(item.id),int(item.get("hue",0)))
		var name: String = session.module("tooltips").name_of(int(item.serial))
		tile.tooltip_text = name.capitalize() if name != "" else str(session.labels.item_name(int(item.id))).capitalize()
		if container == int(trade.mine): tile.payload = {"item_serial":int(item.serial)}
		grid.add_child(tile)

# Backpack items dropped here go onto your side of the trade.
func accepts_item(value: Variant) -> bool:
	return not trade.is_empty() and value is Dictionary and value.has("item_serial") and int(session.known_items.get(int(value.item_serial),{}).get("container",0)) != int(trade.mine)
func take_item(value: Variant) -> void:
	session.move_item(int(value.item_serial),int(trade.mine))
func _can_drop_data(_at: Vector2, value: Variant) -> bool: return accepts_item(value)
func _drop_data(_at: Vector2, value: Variant) -> void: take_item(value)
