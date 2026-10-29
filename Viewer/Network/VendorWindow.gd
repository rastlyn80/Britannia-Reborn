extends "res://Network/ModernWindow.gd"
# A vendor's shop: what they sell (0x74 prices over the 0x24/0x3C stock) and
# what they will buy from you (0x9E), as cards with the items' 3D icons. Click
# a card to add it to your order, adjust amounts, and Buy (0x3B, all lines at
# once) or Sell (0x9F); your gold is shown against the total. Replaces the
# old panel's one-at-a-time "Buy 1" list.
const Studio = preload("res://Presentation/ItemStudio.gd")
const Artwork = preload("res://Network/Artwork.gd")
const Commerce = preload("res://Network/CommerceProtocol.gd")
const Social = preload("res://Network/Packets/Social.gd")
var session: Node
var vendor := 0
var mode := "buy"
var stock: Array = []
var offers: Array = []
var order := {}
var tabs := {}
var goods := GridContainer.new()
var lines := VBoxContainer.new()
var total_label: Label
var gold_label: Label
var confirm: Button
# A tab asked for before its list arrived: the vendor's menu is requested
# and the matching entry (Buy 3006103, Sell 3006104) chosen automatically.
var wanted_tab := ""
const ENTRIES := {"buy":3006103,"sell":3006104}

func _ready() -> void:
	setup("vendor","Shop",Vector2(920,580),Vector2(380,110))
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation",6)
	body.add_child(tools)
	for name in ["Buy","Sell"]:
		var tab := chip(name,name.to_lower() == mode)
		tab.pressed.connect(func(): _ask(name.to_lower()))
		tools.add_child(tab)
		tabs[name.to_lower()] = tab
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation",16)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(split)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	goods.columns = 4
	goods.add_theme_constant_override("h_separation",8)
	goods.add_theme_constant_override("v_separation",8)
	scroll.add_child(goods)
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel",Look.box(Color(1,1,1,0.03),Color(0.84,0.7,0.43,0.2),10,1,14))
	side.custom_minimum_size = Vector2(300,0)
	split.add_child(side)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	side.add_child(column)
	column.add_child(Look.label("Your order",15,Look.GOLD,700))
	var lines_scroll := ScrollContainer.new()
	lines_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lines_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(lines_scroll)
	lines.add_theme_constant_override("separation",6)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines_scroll.add_child(lines)
	total_label = Look.label("",16,Look.IVORY,700)
	column.add_child(total_label)
	gold_label = Look.label("",13,Look.ASH,500)
	column.add_child(gold_label)
	confirm = Button.new()
	confirm.custom_minimum_size = Vector2(0,46)
	confirm.add_theme_stylebox_override("normal",Look.box(Look.BRASS,Look.BRASS,8,1,8))
	confirm.add_theme_stylebox_override("disabled",Look.box(Color(1,1,1,0.05),Color(1,1,1,0.08),8,1,8))
	confirm.add_theme_color_override("font_color",Color("14110b"))
	confirm.pressed.connect(_confirm)
	column.add_child(confirm)
	var clear_button := Button.new()
	clear_button.text = "Clear order"
	clear_button.custom_minimum_size = Vector2(0,36)
	clear_button.pressed.connect(func():
		order.clear()
		_refresh_order())
	column.add_child(clear_button)

func configure(game: Node) -> void:
	session = game
	session.vendor_received.connect(func(serial: int, items: Array): _open(serial,"buy",items))
	session.module("social").sell_list.connect(func(serial: int, items: Array): _open(serial,"sell",items))
	session.vendor_closed.connect(func(_serial: int): hide())
	session.context_received.connect(func(menu: Dictionary):
		if wanted_tab == "" or int(menu.serial) != vendor: return
		for option in menu.options:
			if int(option.label) == ENTRIES[wanted_tab]: session.choose_context(int(option.index))
		wanted_tab = "")
	session.status_changed.connect(func(_s: Dictionary): if visible: _refresh_order())
	session.ended.connect(hide)
	if Studio.instance:
		Studio.instance.icon_ready.connect(func(_g: int, _h: int, _t: Texture2D): if visible: _refresh_goods())

func _open(serial: int, kind: String, items: Array) -> void:
	vendor = serial
	if kind == "buy": stock = items
	else: offers = items
	title_label.text = str(session.entity_names.get(serial,"Shop"))
	order.clear()
	_switch(kind)
	show()
	move_to_front()

func _ask(kind: String) -> void:
	if (kind == "buy" and not stock.is_empty()) or (kind == "sell" and not offers.is_empty()):
		_switch(kind)
		return
	wanted_tab = kind
	# The menu comes back for us, not for the context popup.
	session.set_meta("quiet_context",vendor)
	session.request_context(vendor)

func _switch(kind: String) -> void:
	mode = kind
	for name in tabs: tabs[name].set_pressed_no_signal(name == mode)
	order.clear()
	_refresh_goods()
	_refresh_order()

# Sell offers of one kind (graphic, hue, price, name) share a card; buying
# keeps the vendor's own lines.
func _entries() -> Array:
	if mode == "buy": return stock
	var groups := {}
	var ordered: Array = []
	for item in offers:
		var key := "%d|%d|%d|%s" % [_graphic(item),int(item.get("hue",0)),int(item.price),str(item.get("name",""))]
		if not groups.has(key):
			groups[key] = item.duplicate()
			groups[key].members = []
			groups[key].amount = 0
			ordered.append(groups[key])
		groups[key].members.append(item)
		groups[key].amount = int(groups[key].amount)+int(item.amount)
	return ordered

func _name(item: Dictionary) -> String:
	var text := str(item.get("name",item.get("description","")))
	if text.is_valid_int(): text = session.labels.resolve(int(text))
	if text == "": text = session.labels.item_name(int(item.get("id",item.get("graphic",0))))
	return text.capitalize()

func _graphic(item: Dictionary) -> int: return int(item.get("id",item.get("graphic",0)))

func _picture(item: Dictionary) -> Texture2D:
	var rendered := Studio.lookup(_graphic(item),int(item.get("hue",0)))
	return rendered if rendered else Artwork.item(_graphic(item),int(item.get("hue",0)))

func _refresh_goods() -> void:
	clear(goods)
	for item in _entries():
		var card := Button.new()
		card.custom_minimum_size = Vector2(130,150)
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_stylebox_override("normal",Look.box(Color(1,1,1,0.03),Color(0.84,0.7,0.43,0.18),10,1,8))
		card.add_theme_stylebox_override("hover",Look.box(Color(0.84,0.7,0.43,0.12),Look.BRASS,10,1,8))
		card.tooltip_text = "%s\n%d gold each · click to add" % [_name(item),int(item.price)]
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.offset_left = 8
		column.offset_right = -8
		column.offset_top = 6
		card.add_child(column)
		var art := TextureRect.new()
		art.texture = _picture(item)
		art.custom_minimum_size = Vector2(0,76)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(art)
		var name := Look.label(_name(item),12,Look.IVORY,600)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(name)
		var price := Look.label("%d gold · %d %s" % [int(item.price),int(item.amount),"left" if mode == "buy" else "owned"],11,Look.GOLD,600)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(price)
		card.pressed.connect(func(): _add(item,1))
		goods.add_child(card)
	if _entries().is_empty(): goods.add_child(Look.label("Nothing to show.",14,Look.ASH))

func _add(item: Dictionary, amount: int) -> void:
	var serial := int(item.serial) if not item.has("members") else int(item.members[0].serial)
	var now := int(order.get(serial,{}).get("amount",0))+amount
	if now <= 0: order.erase(serial)
	else: order[serial] = {"item":item,"amount":mini(now,int(item.amount))}
	_refresh_order()

func total() -> int:
	var sum := 0
	for line in order.values(): sum += int(line.amount)*int(line.item.price)
	return sum

func gold() -> int:
	return int(session.player_status.get("gold",session.gold)) if session else 0

func _refresh_order() -> void:
	clear(lines)
	for serial in order:
		var line: Dictionary = order[serial]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",6)
		var art := TextureRect.new()
		art.texture = _picture(line.item)
		art.custom_minimum_size = Vector2(34,34)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(art)
		var name := Look.label(_name(line.item),13,Look.IVORY,500)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(name)
		for step in [-1,1]:
			var b := Button.new()
			b.text = "−" if step < 0 else "+"
			b.custom_minimum_size = Vector2(28,28)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func(): _add(line.item,step))
			row.add_child(b)
			if step < 0:
				var count := Look.label(str(line.amount),13,Look.IVORY,700)
				count.custom_minimum_size = Vector2(28,0)
				count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				row.add_child(count)
		lines.add_child(row)
	if order.is_empty(): lines.add_child(Look.label("Click items to add them.",13,Look.ASH,500))
	var sum := total()
	total_label.text = "Total: %s gold" % str(sum)
	gold_label.text = "You carry %s gold" % str(gold())
	confirm.text = "Buy" if mode == "buy" else "Sell"
	confirm.disabled = order.is_empty() or (mode == "buy" and sum > gold())

func _confirm() -> void:
	var picked: Array = []
	for line in order.values():
		if not line.item.has("members"):
			picked.append({"serial":int(line.item.serial),"amount":int(line.amount)})
			continue
		# A grouped sell line spreads its amount over the stacks it stands for.
		var left := int(line.amount)
		for member in line.item.members:
			if left <= 0: break
			var take := mini(left,int(member.amount))
			picked.append({"serial":int(member.serial),"amount":take})
			left -= take
	if picked.is_empty(): return
	session.send(Commerce.buy_many(vendor,picked) if mode == "buy" else Social.sell(vendor,picked))
	order.clear()
	_refresh_order()
