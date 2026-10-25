extends Control
const Protocol = preload("res://Network/GumpProtocol.gd")
var session: Node
var data := {}
var page := 1
var elements := []
var switches := {}
var entries := {}
var unsupported := []
var art := {}
var reply_buttons: Array[BaseButton] = []

func configure(connection: Node, value: Dictionary) -> void:
 session = connection
 data = value
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 if FileAccess.file_exists("res://gump-art.local.json"):
  var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://gump-art.local.json"))
  if raw is Array:
   for record in raw:
    var image := Image.create_from_data(int(record.width),int(record.height),false,Image.FORMAT_RGBA8,Marshalls.base64_to_raw(record.rgba))
    art[int(record.id)] = ImageTexture.create_from_image(image)
 var current_page := 0
 var group := ButtonGroup.new()
 for command in data.commands:
  var name := str(command[0]).to_lower()
  if name == "page" and command.size() >= 2:
   current_page = int(command[1])
   continue
  if name == "group":
   group = ButtonGroup.new()
   continue
  if name in ["nomove","noclose","nodispose","noresize","endgroup"]: continue
  var control: Control
  match name:
   "resizepic":
    if command.size() < 6: unsupported.append(name); continue
    control = background(int(command[3]),Vector2(int(command[4]),int(command[5])))
   "gumppic","gumppictiled":
    if command.size() < (6 if name == "gumppictiled" else 4): unsupported.append(name); continue
    var id := int(command[5] if name == "gumppictiled" else command[3])
    control = picture(id)
    if name == "gumppictiled": control.size = Vector2(int(command[3]),int(command[4]))
   "text","croppedtext","htmlgump","xmfhtmlgump","xmfhtmlgumpcolor","xmfhtmltok":
    if command.size() < 5: unsupported.append(name); continue
    var label := RichTextLabel.new()
    label.bbcode_enabled = false
    label.scroll_active = false
    var value_text := ""
    if name == "text":
     value_text = text_at(int(command[4]))
     label.size = Vector2(500,30)
    elif name == "croppedtext":
     if command.size() < 7: unsupported.append(name); continue
     value_text = text_at(int(command[6]))
     label.size = Vector2(int(command[3]),int(command[4]))
    else:
     if command.size() < 8: unsupported.append(name); continue
     label.size = Vector2(int(command[3]),int(command[4]))
     if name == "htmlgump": value_text = text_at(int(command[5]))
     else:
      var label_index := 7 if name == "xmfhtmltok" else 5
      if command.size() <= label_index: unsupported.append(name); continue
      value_text = session.labels.resolve(int(command[label_index]),str(command[9]).trim_prefix("@").trim_suffix("@") if name == "xmfhtmltok" and command.size()>9 else "")
     label.scroll_active = int(command[7 if name != "xmfhtmltok" else 6]) != 0
    label.text = plain_html(value_text)
    label.add_theme_color_override("default_color",Color("ece2c6"))
    control = label
   "button","buttontileart":
    if command.size() < 8: unsupported.append(name); continue
    var button: BaseButton
    var art_id := int(command[3])
    if art.has(art_id):
     var textured := TextureButton.new()
     textured.texture_normal = art[art_id]
     textured.texture_pressed = art.get(int(command[4]),art[art_id])
     button = textured
    else:
     var fallback := Button.new()
     fallback.text = "Select"
     fallback.custom_minimum_size = Vector2(24,22)
     button = fallback
    button.set_meta("native_button",int(command[7]))
    if int(command[5]) == 0:
     button.pressed.connect(func(): show_page(int(command[6])))
    else:
     reply_buttons.append(button)
     button.pressed.connect(func(): reply(int(command[7])))
    control = button
   "checkbox","radio":
    if command.size() < 7: unsupported.append(name); continue
    var toggle := CheckBox.new()
    toggle.button_pressed = int(command[5]) != 0
    if name == "radio": toggle.button_group = group
    switches[int(command[6])] = toggle
    control = toggle
   "textentry","textentrylimited":
    if command.size() < 8: unsupported.append(name); continue
    var entry: Control
    var limit := mini(239,int(command[8])) if name == "textentrylimited" and command.size()>8 else 239
    if int(command[4]) > 45:
     var multiline := TextEdit.new()
     multiline.text = text_at(int(command[7]))
     multiline.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
     multiline.text_changed.connect(func():
      if multiline.text.length()>limit: multiline.text = multiline.text.left(limit))
     multiline.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
     multiline.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
     entry = multiline
    else:
     var single := LineEdit.new()
     single.text = text_at(int(command[7]))
     single.max_length = limit
     entry = single
    entry.size = Vector2(int(command[3]),int(command[4]))
    entries[int(command[6])] = entry
    control = entry
   "checkertrans":
    continue # Transparency hint; no response semantics.
   _:
    unsupported.append(name)
    continue
  control.position = Vector2(clampi(int(command[1]),-2048,4096),clampi(int(command[2]),-2048,4096))
  if control is not BaseButton and control is not LineEdit and control is not TextEdit: control.mouse_filter = Control.MOUSE_FILTER_IGNORE if not control is RichTextLabel or not control.scroll_active else Control.MOUSE_FILTER_STOP
  add_child(control)
  elements.append({"control":control,"page":current_page})
 var footer := HBoxContainer.new()
 footer.position = Vector2(0,550)
 add_child(footer)
 var close := Button.new()
 close.text = "Close server window"
 close.pressed.connect(func(): reply(0))
 footer.add_child(close)
 if not unsupported.is_empty():
  var warning := Label.new()
  warning.text = "Read-only: unsupported controls: "+", ".join(unsupported)
  warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  warning.custom_minimum_size.x = 470
  footer.add_child(warning)
  for button in reply_buttons: button.disabled = true
 var native_close := false
 for command in data.commands:
  if command[0] in ["button","buttontileart"] and command.size() >= 8 and int(command[5]) == 1 and int(command[7]) == 0: native_close = true
 footer.visible = not native_close or not unsupported.is_empty()
 show_page(1)

func text_at(index: int) -> String:
 return str(data.texts[index]) if index >= 0 and index < data.texts.size() else ""
static func plain_html(value: String) -> String:
 var breaks := RegEx.new()
 breaks.compile("(?i)<br\\s*/?>|</p>")
 value = breaks.sub(value,"\n",true)
 var tags := RegEx.new()
 tags.compile("<[^>]*>")
 return tags.sub(value,"",true).replace("&nbsp;"," ").replace("&lt;","<").replace("&gt;",">").replace("&amp;","&")
func picture(id: int) -> Control:
 var result := TextureRect.new()
 if art.has(id):
  result.texture = art[id]
  result.size = art[id].get_size()
 result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 result.stretch_mode = TextureRect.STRETCH_SCALE
 return result
func background(id: int, dimensions: Vector2) -> Control:
 var result := Panel.new()
 result.size = dimensions.clamp(Vector2(10,10),Vector2(2048,2048))
 var style := StyleBoxFlat.new()
 style.bg_color = Color("242b2af5")
 style.border_color = Color("ac9462")
 style.set_border_width_all(2)
 result.add_theme_stylebox_override("panel",style)
 if art.has(id) and art.has(id+8):
  var left: float = art[id].get_width()
  var top: float = art[id].get_height()
  var right: float = art[id+8].get_width()
  var bottom: float = art[id+8].get_height()
  var xs := [0.0,left,maxf(left,dimensions.x-right)]
  var ys := [0.0,top,maxf(top,dimensions.y-bottom)]
  var widths := [left,maxf(0,dimensions.x-left-right),right]
  var heights := [top,maxf(0,dimensions.y-top-bottom),bottom]
  for row in 3:
   for col in 3:
    var tile := picture(id+row*3+col)
    tile.position = Vector2(xs[col],ys[row])
    tile.size = Vector2(widths[col],heights[row])
    tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
    result.add_child(tile)
 return result
func show_page(number: int) -> void:
 page = number
 for element in elements: element.control.visible = element.page == 0 or element.page == page
func reply(button: int) -> void:
 if button != 0 and not unsupported.is_empty(): return
 var values := []
 for key in switches:
  if switches[key].button_pressed: values.append(key)
 var texts := {}
 for key in entries: texts[key] = entries[key].text
 if session.respond_gump(data,button,values,texts): queue_free()
