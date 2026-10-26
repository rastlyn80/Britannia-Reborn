extends CanvasLayer
var session: Node
var panel := PanelContainer.new()
var title := Label.new()
var rows := VBoxContainer.new()
var showing_stock := false
const Artwork = preload("res://Network/Artwork.gd")
func configure(connection: Node) -> void:
 session = connection
 add_child(panel)
 panel.position = Vector2(480,70)
 panel.custom_minimum_size = Vector2(430,200)
 var style := StyleBoxFlat.new()
 style.bg_color = Color("172229fa")
 for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: style.set_content_margin(side,14)
 panel.add_theme_stylebox_override("panel",style)
 var column := VBoxContainer.new()
 panel.add_child(column)
 column.add_child(title)
 var scroll := ScrollContainer.new()
 scroll.custom_minimum_size = Vector2(420,420)
 column.add_child(scroll)
 scroll.add_child(rows)
 var close := Button.new()
 close.text = "Close"
 close.pressed.connect(func(): panel.hide())
 column.add_child(close)
 panel.hide()
 session.entity_name_received.connect(func(serial: int,name_text: String):
  if panel.visible and not showing_stock and int(session.context_menu.get("serial",0))==serial: title.text = name_text)
 session.context_received.connect(context)
 session.vendor_received.connect(shop)
 session.vendor_closed.connect(func(_vendor: int): panel.hide(); session.open_backpack())
 session.ended.connect(func(): panel.hide())
func clear() -> void:
 for child in rows.get_children(): child.free()
func context(menu: Dictionary) -> void:
 showing_stock = false
 clear()
 title.text = session.entity_names.get(int(menu.serial),"Actions")
 for option in menu.options:
  var button := Button.new()
  button.text = session.labels.resolve(int(option.label))
  button.disabled = (int(option.flags)&1)!=0
  button.pressed.connect(func(): session.choose_context(int(option.index)))
  rows.add_child(button)
 panel.show()
func shop(vendor: int, stock: Array) -> void:
 showing_stock = true
 clear()
 title.text = session.entity_names.get(vendor,"Shop")+" · native stock and prices"
 for item in stock:
  var row := HBoxContainer.new()
  rows.add_child(row)
  var name_text := str(item.description)
  if name_text.is_valid_int(): name_text = session.labels.resolve(int(name_text))
  var name_label := Label.new()
  name_label.text = "%s · %d gold" % [name_text,int(item.price)]
  name_label.custom_minimum_size.x = 290
  name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  var icon := TextureRect.new()
  icon.texture = Artwork.item(int(item.id),int(item.get("hue",0)))
  icon.custom_minimum_size = Vector2(32,32)
  icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  row.add_child(icon)
  row.add_child(name_label)
  var buy := Button.new()
  buy.text = "Buy 1"
  buy.disabled = int(item.amount)<1
  buy.pressed.connect(func():
   if session.buy_item(int(item.serial)):
    for child in rows.get_children():
     for control in child.get_children():
      if control is Button: control.disabled = true)
  row.add_child(buy)
 panel.show()
