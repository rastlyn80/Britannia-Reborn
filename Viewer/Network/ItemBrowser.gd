extends CanvasLayer
const Appearance = preload("res://Presentation/ItemAppearance.gd")
var session: Node
var panel := PanelContainer.new()
var title := Label.new()
var rows := VBoxContainer.new()
var reader := RichTextLabel.new()
var preview: SubViewport
var model := Node3D.new()
var definitions := {}
var selected := 0
var mode := ""
var last_container := 0
var refresh_pending := false
var status := Label.new()
const Artwork = preload("res://Network/Artwork.gd")

func configure(connection: Node) -> void:
 session = connection
 if FileAccess.file_exists("res://item-definitions.local.json"):
  var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://item-definitions.local.json"))
  if value is Dictionary: definitions = value
 add_child(panel)
 panel.position = Vector2(24,92)
 panel.custom_minimum_size = Vector2(440,200)
 var style := StyleBoxFlat.new()
 style.bg_color = Color("172229f5")
 for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: style.set_content_margin(side,16)
 panel.add_theme_stylebox_override("panel",style)
 var column := VBoxContainer.new()
 panel.add_child(column)
 column.add_child(title)
 var viewport_container := SubViewportContainer.new()
 viewport_container.name = "ObjectPreview"
 viewport_container.custom_minimum_size = Vector2(408,90)
 column.add_child(viewport_container)
 preview = SubViewport.new()
 preview.size = Vector2i(408,90)
 preview.own_world_3d = true
 preview.transparent_bg = true
 preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
 viewport_container.add_child(preview)
 preview.add_child(model)
 var camera := Camera3D.new()
 camera.position = Vector3(0.9,0.65,1.2)
 camera.look_at_from_position(camera.position,Vector3(0,0.1,0))
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 0.65
 preview.add_child(camera)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-45,-30,0)
 light.light_energy = 1.5
 preview.add_child(light)
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color = Color.WHITE
 environment.environment.ambient_light_energy = 0.65
 preview.add_child(environment)
 var scroll := ScrollContainer.new()
 scroll.custom_minimum_size = Vector2(408,150)
 column.add_child(scroll)
 rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(rows)
 reader.custom_minimum_size = Vector2(408,220)
 reader.bbcode_enabled = false
 reader.hide()
 column.add_child(reader)
 var navigation := HBoxContainer.new()
 column.add_child(navigation)
 action(navigation,"Backpack",func(): session.open_backpack())
 action(navigation,"Equipment",show_equipment)
 action(navigation,"Last container",func():
  if last_container: session.use_item(last_container))
 var actions := GridContainer.new()
 actions.columns = 2
 column.add_child(actions)
 action(actions,"Use selected",func():
  if selected: session.use_item(selected))
 action(actions,"Take / to backpack",func(): move_selected(session.backpack))
 action(actions,"Put in last container",func():
  if last_container: move_selected(last_container))
 action(actions,"Place in world",func():
  if selected and session.begin_place(selected): panel.hide())
 action(actions,"Equip selected",func(): move_selected(int(session.player.serial),true))
 status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 status.custom_minimum_size.x = 408
 column.add_child(status)
 var close := Button.new()
 close.text = "Close"
 close.pressed.connect(func(): panel.hide())
 column.add_child(close)
 panel.hide()
 session.container_opened.connect(func(serial: int):
  mode = "container"
  selected = 0
  if serial != session.backpack: last_container = serial
  title.text = "Backpack" if serial == session.backpack else session.labels.item_name(int(session.world_items.get(serial,{"id":0}).id))
  reset_rows("Waiting for server contents…")
  panel.show())
 session.inventory_received.connect(contents)
 session.items_changed.connect(func():
  if not refresh_pending:
   refresh_pending = true
   refresh.call_deferred())
 session.transfer_result.connect(func(_success: bool,text: String): status.text = text)
 session.book_received.connect(book)
 session.board_received.connect(func(board: Dictionary):
  mode = "board"
  title.text = board.title
  reset_rows("Waiting for board messages…")
  panel.show())
 session.board_post_received.connect(post)
 session.gump_received.connect(func(_value: Dictionary): panel.hide())
 session.ended.connect(func(): panel.hide())
 session.world_item_removed.connect(func(serial: int):
  if serial == session.container_serial: panel.hide())
 session.entity_changed.connect(func(serial: int, position: Dictionary):
  if serial != session.player.serial or session.container_serial == session.backpack: return
  var owner: Dictionary = session.world_items.get(session.container_serial,{})
  if not owner.is_empty() and (maxi(absi(int(owner.x)-int(position.x)),absi(int(owner.y)-int(position.y))) > 2 or absi(int(owner.z)-int(position.z)) > 16): panel.hide())

func reset_rows(status: String = "") -> void:
 rows.get_parent().show()
 for child in rows.get_children(): child.free()
 reader.hide()
 preview.get_parent().hide()
 if not status.is_empty():
  var label := Label.new()
  label.text = status
  rows.add_child(label)

func contents(items: Array) -> void:
 if mode not in ["container","board"]: return
 reset_rows("No messages on this board." if mode == "board" and items.is_empty() else ("Empty." if items.is_empty() else ""))
 for item in items:
  var button := Button.new()
  button.text = "%s × %d" % [session.labels.item_name(int(item.id)),int(item.amount)]
  button.icon = Artwork.item(int(item.id),int(item.get("hue",0)))
  button.expand_icon = true
  button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
  button.custom_minimum_size.y = 38
  button.alignment = HORIZONTAL_ALIGNMENT_LEFT
  button.set_meta("server_serial",int(item.serial))
  button.pressed.connect(func():
   if mode == "board": session.request_board_post(int(item.serial))
   else:
    selected = int(item.serial)
    status.text = "Selected: "+session.labels.item_name(int(item.id))
    show_preview(item)
    if not session.target_request.is_empty(): session.target_item(int(item.serial)))
  rows.add_child(button)

func show_preview(item: Dictionary) -> void:
 for child in model.get_children(): child.free()
 var rule: Dictionary = definitions.get(str(int(item.id)),{})
 var kind := Appearance.variant(int(item.id),rule)
 var g := preload("res://Presentation/GeometryLibrary.gd").new()
 var size := Appearance.small(model,g,kind,int(item.id))
 if size == Vector3.ZERO:
  var icon := Artwork.item(int(item.id),int(item.get("hue",0)))
  if icon:
   var sprite := Sprite3D.new()
   sprite.texture = icon
   sprite.pixel_size = 0.004
   sprite.position.y = 0.1
   sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
   model.add_child(sprite)
  else: Appearance.small(model,g,"unknown",int(item.id))
 preview.get_parent().show()
 preview.render_target_update_mode = SubViewport.UPDATE_ONCE

func book(value: Dictionary) -> void:
 mode = "book"
 title.text = str(value.get("title","Book"))
 reset_rows()
 rows.get_parent().hide()
 reader.show()
 reader.text = "By %s\n\n" % str(value.get("author",""))
 var pages: Dictionary = value.get("pages",{})
 var numbers := pages.keys()
 numbers.sort()
 for number in numbers: reader.text += "— Page %d —\n%s\n\n" % [number,pages[number]]
 if pages.is_empty(): reader.text += "Waiting for server pages…"
 if session.container_items.has(int(value.serial)): show_preview(session.container_items[int(value.serial)])
 panel.show()

func post(value: Dictionary) -> void:
 if mode != "board": return
 for child in rows.get_children():
  if int(child.get_meta("server_serial",0)) == int(value.post): child.text = "%s — %s" % [value.title,value.author]
 if not value.lines.is_empty():
  reader.text = "%s\n%s · %s\n\n%s" % [value.title,value.author,value.date,"\n".join(value.lines)]
  reader.show()

func action(parent: Node, text: String, callback: Callable) -> Button:
 var button := Button.new()
 button.text = text
 button.pressed.connect(callback)
 parent.add_child(button)
 return button
func move_selected(destination: int, equip_item: bool = false) -> void:
 if not selected:
  status.text = "Select an item first."
  return
 if session.move_item(selected,destination,equip_item): status.text = "Waiting for server confirmation…"
 else: status.text = "Cannot start this move. Finish the current move or select another item."
func refresh() -> void:
 refresh_pending = false
 if mode == "equipment": show_equipment()
 elif mode == "container": contents(session.contents_of(session.container_serial))
func show_equipment() -> void:
 mode = "equipment"
 title.text = "Equipment · server confirmed"
 reset_rows()
 for layer in session.equipment:
  if int(layer) in [11,16,21,26,27,28,29]: continue
  var item: Dictionary = session.equipment[layer]
  if not session.known_items.has(int(item.serial)): continue
  var row := Button.new()
  row.text = "Layer %d · %s" % [layer,session.labels.item_name(int(item.id))]
  row.icon = Artwork.item(int(item.id),int(item.get("hue",0)))
  row.expand_icon = true
  row.custom_minimum_size = Vector2(390,38)
  row.pressed.connect(func():
   selected = int(item.serial)
   show_preview(item)
   status.text = "Select Take / to backpack to unequip this item.")
  rows.add_child(row)
 panel.show()
