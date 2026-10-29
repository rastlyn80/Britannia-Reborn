extends Control
# A server window (gump, 0xB0/0xDD) built from its layout commands, in the
# modern style: the server's positions and sizes are kept, background frames
# become glass panels, text uses our fonts with readable versions of the
# server's hues, inputs follow the HUD theme, and items appear as their 3D
# icons. Every command ModernUO writes is handled (GumpLayoutBuilder), plus
# ClassicUO's extras (hued pictures, tile-as-gump, virtue items).
const Protocol = preload("res://Network/GumpProtocol.gd")
const Look = preload("res://Network/ModernSkin.gd")
const Studio = preload("res://Presentation/ItemStudio.gd")
var session: Node
var data := {}
var page := 1
var elements := []
var switches := {}
var entries := {}
var unsupported := []
var art := {}
const Artwork = preload("res://Network/Artwork.gd")
var movable := true
var closable := true
var content_bounds := Rect2()
var reply_buttons: Array[BaseButton] = []
# Item pictures waiting for their 3D icon: [TextureRect, graphic, hue].
var pending_icons: Array = []
# Classic button art the HUD draws as its own buttons: normal art id ->
# [label, primary]. Arrows stay pictures as small modern chevrons.
const MODERN_BUTTONS := {247:["Okay",true],248:["Okay",true],249:["Okay",true],241:["Cancel",false],242:["Cancel",false],243:["Cancel",false],2072:["Cancel",false],2073:["Cancel",false],
	4005:["›",false],4006:["›",false],4007:["›",false],4008:["»",false],4011:["≡",false],4014:["‹",false],4015:["‹",false],4017:["×",false],4020:["×",false],
	4023:["✓",true],4026:["?",false],4029:["+",false],2117:["•",false],2118:["•",false],2151:["›",false],2152:["›",false],
	5601:["›",false],5603:["‹",false],2223:["‹",false],2224:["›",false],5540:["›",false],5537:["‹",false],1209:["•",false],1210:["•",false],2103:["•",false]}

func configure(connection: Node, value: Dictionary) -> void:
 session = connection
 data = value
 theme = Look.theme()
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
  if name == "nomove": movable = false; continue
  if name == "noclose": closable = false; continue
  if name in ["nodispose","noresize","endgroup","mastergump","echandleinput","reset","system","togglelimitgumpscale"]: continue
  # Tooltips (a cliloc, optional @args@) and item properties describe the
  # element just before them.
  if name in ["tooltip","itemproperty"]:
   if not elements.is_empty() and command.size() >= 2:
    var target: Control = elements.back().control
    if name == "tooltip": target.tooltip_text = session.labels.resolve(int(command[1]),str(command[2]).trim_prefix("@").trim_suffix("@") if command.size() > 2 else "")
    elif session.has_method("module"):
     var tooltips: RefCounted = session.module("tooltips")
     var item_serial := int(command[1])
     tooltips.request(item_serial,true)
     target.tooltip_text = "\n".join(tooltips.lines_of(item_serial))
     target.set_meta("item_property",item_serial)
   continue
  var control: Control
  match name:
   "resizepic":
    if command.size() < 6: unsupported.append(name); continue
    control = background(int(command[3]),Vector2(int(command[4]),int(command[5])))
   "tilepic","tilepichue","tilepicasgumppic":
    if command.size() < (5 if name=="tilepichue" else 4): unsupported.append(name); continue
    var tile := TextureRect.new()
    var item_hue := int(command[4]) if name=="tilepichue" else 0
    var classic: Texture2D = Artwork.item(int(command[3]),item_hue)
    # The item's 3D icon in the classic art's footprint (classic art meanwhile).
    var rendered := Studio.lookup(int(command[3]),item_hue)
    tile.texture = rendered if rendered else (classic if classic else Look.icon("rune",Look.DIM,40))
    tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    tile.size = classic.get_size().max(Vector2(44,44)) if classic else Vector2(44,44)
    if not rendered: pending_icons.append([tile,int(command[3]),item_hue])
    control = tile
   "gumppic","gumppictiled","gumppichued","gumppicphued","virtuegumpitem":
    if command.size() < (6 if name == "gumppictiled" else 4): unsupported.append(name); continue
    var id := int(command[5] if name == "gumppictiled" else command[3])
    control = picture(id)
    if name == "gumppictiled": control.size = Vector2(int(command[3]),int(command[4]))
    # hue=N (ModernUO) or the hued variants' fourth value tint the picture.
    var picture_hue := 0
    for token in command.slice(4):
     if str(token).begins_with("hue="): picture_hue = int(str(token).substr(4))
    if name in ["gumppichued","gumppicphued","virtuegumpitem"] and command.size() > 4: picture_hue = int(command[4])
    if picture_hue > 0: control.modulate = Artwork.color(picture_hue,Color.WHITE).lightened(0.15)
   "text","croppedtext","htmlgump","xmfhtmlgump","xmfhtmlgumpcolor","xmfhtmltok":
    if command.size() < 5: unsupported.append(name); continue
    var label := RichTextLabel.new()
    label.bbcode_enabled = true
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
    label.text = html_text(value_text)
    label.add_theme_font_override("normal_font",Look.ui_font(500))
    label.add_theme_font_override("bold_font",Look.ui_font(700))
    label.add_theme_font_size_override("normal_font_size",14)
    label.add_theme_font_size_override("bold_font_size",14)
    if name in ["text","croppedtext"]: label.add_theme_color_override("default_color",readable(Artwork.color(int(command[3] if name=="text" else command[5]),Look.IVORY)))
    elif name in ["xmfhtmlgumpcolor","xmfhtmltok"] and command.size() > 8 and int(command[8]) != 0: label.add_theme_color_override("default_color",readable(rgb15(int(command[8]))))
    else: label.add_theme_color_override("default_color",Look.IVORY)
    # The html background flag: a dark inset behind the text.
    if name not in ["text","croppedtext"] and command.size() > 6 and int(command[6 if name != "xmfhtmltok" else 5]) != 0:
     label.add_theme_stylebox_override("normal",Look.box(Color(0,0,0,0.3),Color(0.84,0.7,0.43,0.18),6,1,4))
    control = label
   "button","buttontileart":
    if command.size() < 8: unsupported.append(name); continue
    var button: BaseButton
    var art_id := int(command[3])
    var wrapper: Control = null
    if MODERN_BUTTONS.has(art_id):
     # Centred on the classic art's footprint, so rows of text still line up.
     var footprint: Vector2 = art[art_id].get_size() if art.has(art_id) else Vector2(30,22)
     var modern := modern_button(MODERN_BUTTONS[art_id])
     wrapper = Control.new()
     wrapper.size = footprint
     wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
     modern.position = ((footprint-modern.custom_minimum_size)/2.0).round()
     wrapper.add_child(modern)
     button = modern
    elif art.has(art_id):
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
    control = wrapper if wrapper else button
    # buttontileart: an item drawn on the button (id, hue, offset).
    if name == "buttontileart" and command.size() >= 12:
     var on_button := TextureRect.new()
     var tile_hue := int(command[9])
     var shown := Studio.lookup(int(command[8]),tile_hue)
     on_button.texture = shown if shown else Artwork.item(int(command[8]),tile_hue)
     on_button.position = Vector2(int(command[10]),int(command[11]))
     on_button.size = Vector2(44,44)
     on_button.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
     on_button.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
     on_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
     button.add_child(on_button)
   "picinpic","picinpichued","picinpicphued":
    if command.size()<8: unsupported.append(name); continue
    control = picture(int(command[3]))
    if control is TextureRect and control.texture:
     var atlas := AtlasTexture.new()
     atlas.atlas = control.texture
     atlas.region = Rect2(int(command[4]),int(command[5]),int(command[6]),int(command[7]))
     control.texture = atlas
     control.size = atlas.region.size
   "checkbox","radio":
    if command.size() < 7: unsupported.append(name); continue
    var toggle := CheckBox.new()
    toggle.button_pressed = int(command[5]) != 0
    # The server's own on/off art when present; the HUD's check otherwise.
    if art.has(int(command[3])) and art.has(int(command[4])):
     for state in ["unchecked","radio_unchecked"]: toggle.add_theme_icon_override(state,art[int(command[3])])
     for state in ["checked","radio_checked"]: toggle.add_theme_icon_override(state,art[int(command[4])])
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
    # An alpha region: dark glass over what is behind it.
    if command.size() < 5: continue
    var glass := ColorRect.new()
    glass.color = Color(0.02,0.025,0.035,0.55)
    glass.size = Vector2(int(command[3]),int(command[4]))
    control = glass
   _:
    unsupported.append(name)
    continue
  control.position = Vector2(clampi(int(command[1]),-2048,4096),clampi(int(command[2]),-2048,4096))
  if control is Panel:
   control.mouse_filter = Control.MOUSE_FILTER_STOP
   control.gui_input.connect(func(event: InputEvent):
    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and closable: reply(0))
  elif control is not BaseButton and control is not LineEdit and control is not TextEdit: control.mouse_filter = Control.MOUSE_FILTER_IGNORE if not control is RichTextLabel or not control.scroll_active else Control.MOUSE_FILTER_STOP
  add_child(control)
  var area := Rect2(control.position,control.size.max(control.get_combined_minimum_size()))
  content_bounds = content_bounds.merge(area) if content_bounds.has_area() else area
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
 footer.visible = (not native_close and closable) or not unsupported.is_empty()
 if movable:
  var drag := preload("res://Network/WindowDrag.gd").new()
  drag.target = self
  drag.position = content_bounds.position
  drag.size = Vector2(maxf(100,content_bounds.size.x),22)
  drag.tooltip_text = "Drag this window"
  drag.mouse_default_cursor_shape = Control.CURSOR_DRAG
  add_child(drag)
 show_page(1)
 _place.call_deferred()
 if Studio.instance and not pending_icons.is_empty(): Studio.instance.icon_ready.connect(_icon_ready)

func _icon_ready(graphic: int, hue: int, texture: Texture2D) -> void:
 for entry in pending_icons:
  if is_instance_valid(entry[0]) and int(entry[1]) == graphic and int(entry[2]) == hue: entry[0].texture = texture

# Server windows draw above the HUD; one the server puts in the far top-left
# corner (most send 0..100) is centred instead of covering the vitals card.
func _place() -> void:
 var layer := get_parent() as CanvasLayer
 if layer and layer.layer < 6: layer.layer = 6
 var screen := get_viewport().get_visible_rect().size
 if int(data.get("x",0)) <= 120 and int(data.get("y",0)) <= 120:
  position = ((screen-content_bounds.size)/2.0-content_bounds.position).round()
 position = position.clamp(-content_bounds.position,screen-content_bounds.end.min(screen))

func _unhandled_key_input(event: InputEvent) -> void:
 if event.pressed and event.keycode == KEY_ESCAPE and closable and is_visible_in_tree() and get_parent().get_child(get_parent().get_child_count()-1) == self:
  reply(0)
  get_viewport().set_input_as_handled()

func text_at(index: int) -> String:
 return str(data.texts[index]) if index >= 0 and index < data.texts.size() else ""
static func html_text(value: String) -> String:
 value = value.replace("[","[lb]")
 var tags := RegEx.new()
 tags.compile("(?i)<(/?)(b|i|u|center)>")
 for hit in tags.search_all(value):
  var tag := "center" if hit.get_string(2).to_lower()=="center" else hit.get_string(2).to_lower()
  value = value.replace(hit.get_string(),"["+hit.get_string(1)+tag+"]")
 var color_tag := RegEx.new()
 color_tag.compile("(?i)<basefont color=[\"']?(#[0-9a-f]{6})[\"']?>")
 value = color_tag.sub(value,"[color=$1]",true).replace("</basefont>","[/color]")
 return plain_html(value)
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
# Server background frames as the HUD's glass panel (classic_frames keeps the
# server's own nine-piece art).
static var classic_frames := false
func background(id: int, dimensions: Vector2) -> Control:
 var result := Panel.new()
 result.clip_contents = true
 result.size = dimensions.clamp(Vector2(10,10),Vector2(2048,2048))
 result.add_theme_stylebox_override("panel",Look.box(Color(0.055,0.063,0.078,0.94),Color(0.84,0.7,0.43,0.4),10,1,0))
 if classic_frames and art.has(id) and art.has(id+8):
  var left: float = art[id].get_width()
  var top: float = art[id].get_height()
  var right: float = art[id+2].get_width()
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
    tile.set_deferred("size",Vector2(widths[col],heights[row]))
 return result
# The HUD's own button for a classic one: a round icon button for glyphs
# (arrows, close, check, dots), a pill for words (Okay, Cancel).
const GLYPHS := {"›":"chevron_right","‹":"chevron_left","»":"chevrons_right","×":"close","✓":"check","•":"dot","≡":"list","?":"question","+":"plus"}
static func modern_button(spec: Array) -> Button:
 var b := Button.new()
 b.focus_mode = Control.FOCUS_NONE
 var primary: bool = spec[1]
 var ink: Color = Color("14110b") if primary else Look.IVORY
 var fill := Look.BRASS if primary else Color(1,1,1,0.05)
 var edge := Look.BRASS if primary else Color(0.84,0.7,0.43,0.5)
 if GLYPHS.has(str(spec[0])):
  b.custom_minimum_size = Vector2(26,26)
  b.icon = Look.icon(GLYPHS[str(spec[0])],ink,16)
  b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
  b.tooltip_text = {"›":"Next","‹":"Back","»":"Forward","×":"Close","✓":"Confirm","?":"Help","+":"Add"}.get(str(spec[0]),"")
  for state in ["normal","hover","pressed"]:
   var tint := fill if state == "normal" else (Color("e6c588") if primary else Color(0.84,0.7,0.43,0.22 if state == "hover" else 0.34))
   b.add_theme_stylebox_override(state,Look.box(tint,edge if state == "normal" else Look.BRASS,13,1,0))
 else:
  b.text = str(spec[0])
  b.custom_minimum_size = Vector2(96,30)
  b.add_theme_font_override("font",Look.ui_font(600))
  b.add_theme_font_size_override("font_size",13)
  for state in ["normal","hover","pressed"]:
   var tint := fill if state == "normal" else (Color("e6c588") if primary else Color(0.84,0.7,0.43,0.2 if state == "hover" else 0.3))
   b.add_theme_stylebox_override(state,Look.box(tint,edge if state == "normal" else Look.BRASS,15,1,6))
  for state in ["font_color","font_hover_color","font_pressed_color"]: b.add_theme_color_override(state,ink if primary or state == "font_color" else Color.WHITE)
 return b

# Classic hues are tuned for parchment; on dark glass, lift dark ones.
static func readable(colour: Color) -> Color:
 return colour.lightened(clampf(0.55-colour.get_luminance(),0.0,0.55)) if colour.get_luminance() < 0.55 else colour
static func rgb15(value: int) -> Color:
 if value > 0x7fff: return Color.hex((value << 8) | 0xff)
 return Color(float((value>>10)&31)/31,float((value>>5)&31)/31,float(value&31)/31)

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
