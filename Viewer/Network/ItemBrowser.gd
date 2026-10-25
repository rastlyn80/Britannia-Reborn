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
 viewport_container.custom_minimum_size = Vector2(408,130)
 column.add_child(viewport_container)
 preview = SubViewport.new()
 preview.size = Vector2i(408,130)
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
 scroll.custom_minimum_size = Vector2(408,220)
 column.add_child(scroll)
 rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(rows)
 reader.custom_minimum_size = Vector2(408,300)
 reader.bbcode_enabled = false
 reader.hide()
 column.add_child(reader)
 var close := Button.new()
 close.text = "Close"
 close.pressed.connect(func(): panel.hide())
 column.add_child(close)
 panel.hide()
 session.container_opened.connect(func(serial: int):
  mode = "container"
  title.text = "Backpack" if serial == session.backpack else session.labels.item_name(int(session.world_items.get(serial,{"id":0}).id))
  reset_rows("Waiting for server contents…")
  panel.show())
 session.inventory_received.connect(contents)
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
  button.alignment = HORIZONTAL_ALIGNMENT_LEFT
  button.set_meta("server_serial",int(item.serial))
  button.pressed.connect(func():
   if mode == "board": session.request_board_post(int(item.serial))
   else:
    show_preview(item)
    if not session.target_request.is_empty(): session.target_item(int(item.serial))
    else: session.use_item(int(item.serial)))
  rows.add_child(button)

func show_preview(item: Dictionary) -> void:
 for child in model.get_children(): child.free()
 var rule: Dictionary = definitions.get(str(int(item.id)),{})
 var kind := Appearance.variant(int(item.id),rule)
 var g := preload("res://Presentation/GeometryLibrary.gd").new()
 var size := Appearance.small(model,g,kind,int(item.id))
 if size == Vector3.ZERO: Appearance.small(model,g,"unknown",int(item.id))
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
