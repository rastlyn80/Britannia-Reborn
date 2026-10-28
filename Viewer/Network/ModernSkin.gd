extends RefCounted
# The modern interface look: dark glass panels with brass edges, Cinzel for
# titles and Inter for everything read at a glance (Art/Fonts, OFL), and a
# small set of line icons drawn here as SVG paths (original to this project).
const NIGHT := Color(0.055,0.063,0.078,0.9)
const SLATE := Color("181c22")
const BRASS := Color("d6b26e")
const EDGE := Color(0.84,0.7,0.43,0.35)
const IVORY := Color("eee7d7")
const ASH := Color("a9a293")
const DIM := Color("7d776b")
const GOLD := Color("e2c27a")
const BLOOD := Color("d9584a")
const AMBER := Color("e3a93b")
const SKY := Color("4c8df0")
const HERB := Color("9bd88a")
const ICONS := {
	"sword":"M20 4 L9 15 M20 4 L20 8 M20 4 L16 4 M6 13 L11 18 M8.5 15.5 L4 20",
	"shield":"M12 3 L19 6 V11 C19 16 15.5 19.5 12 21 C8.5 19.5 5 16 5 11 V6 Z",
	"heal":"M10 4 H14 V10 H20 V14 H14 V20 H10 V14 H4 V10 H10 Z",
	"bandage":"M5 14 L14 5 A3.5 3.5 0 0 1 19 10 L10 19 A3.5 3.5 0 0 1 5 14 Z M9.5 9.5 L14.5 14.5",
	"potion":"M10 3 H14 M11 3 V8 L6 17 A2.5 2.5 0 0 0 8.2 21 H15.8 A2.5 2.5 0 0 0 18 17 L13 8 V3 M8 14 H16",
	"flame":"M12 3 C14 7 18 9 18 14 A6 6 0 0 1 6 14 C6 11 8 9 9 7 C10 10 11 10 12 9 C12 7 11 5 12 3 Z",
	"bolt":"M13 2 L4 14 H11 L10 22 L20 9 H13 Z",
	"eye":"M2 12 C5 6 19 6 22 12 C19 18 5 18 2 12 Z M12 15 A3 3 0 1 0 12 9 A3 3 0 1 0 12 15",
	"hide":"M12 3 C8 3 6 6 6 9 L4 21 H20 L18 9 C18 6 16 3 12 3 Z M9 10 H15",
	"rune":"M12 2 L20 9 L12 22 L4 9 Z M4 9 H20",
	"moon":"M20 14 A8 8 0 1 1 10 4 A6 6 0 0 0 20 14 Z",
	"bag":"M5 8 H19 L18 21 H6 Z M9 8 V6 A3 3 0 0 1 15 6 V8",
	"book":"M4 5 C7 4 10 4 12 6 C14 4 17 4 20 5 V19 C17 18 14 18 12 20 C10 18 7 18 4 19 Z M12 6 V20",
	"chat":"M4 5 H20 V16 H10 L5 20 V16 H4 Z",
	"skills":"M5 20 V14 M10 20 V9 M15 20 V12 M20 20 V5",
	"target":"M12 20 A8 8 0 1 0 12 4 A8 8 0 1 0 12 20 M12 1 V7 M12 17 V23 M1 12 H7 M17 12 H23",
	"war":"M4 4 L20 20 M20 4 L4 20 M4 4 V8 M4 4 H8 M20 4 H16 M20 4 V8",
	"user":"M12 12 A4 4 0 1 0 12 4 A4 4 0 1 0 12 12 Z M4 21 C5 16 19 16 20 21",
	"walk":"M13 4 A1.5 1.5 0 1 0 13 7 M12 8 L9 13 L12 15 L11 21 M12 8 L16 12 L19 11 M9 13 L6 15",
	"door":"M6 3 H18 V21 H6 Z M14 12 H15",
	"wing":"M3 18 C8 6 16 4 21 5 C17 8 15 12 14 18 C11 15 7 15 3 18 Z",
	"star":"M12 3 L14.5 9 L21 9.5 L16 13.5 L17.5 20 L12 16.5 L6.5 20 L8 13.5 L3 9.5 L9.5 9 Z",
	"window":"M3 5 H21 V19 H3 Z M3 9 H21",
	"close":"M6 6 L18 18 M18 6 L6 18",
	"clock":"M12 21 A9 9 0 1 0 12 3 A9 9 0 1 0 12 21 M12 7 V12 L15 14",
	"plus":"M12 5 V19 M5 12 H19",
	"up":"M12 19 V5 M6 11 L12 5 L18 11",
	"down":"M12 5 V19 M6 13 L12 19 L18 13",
	"map":"M3 6 L9 4 L15 6 L21 4 V18 L15 20 L9 18 L3 20 Z M9 4 V18 M15 6 V20",
	"coin":"M12 20 A8 8 0 1 0 12 4 A8 8 0 1 0 12 20 M14.5 9.5 C14 8.5 10 8 10 10.5 C10 12.5 14 11.5 14 13.8 C14 16 10 15.6 9.5 14.5 M12 7 V17",
	"search":"M10 17 A7 7 0 1 0 10 3 A7 7 0 1 0 10 17 M15 15 L21 21",
	"grip":"M9 6 H9.01 M15 6 H15.01 M9 12 H9.01 M15 12 H15.01 M9 18 H9.01 M15 18 H15.01",
	"lock":"M6 11 H18 V21 H6 Z M8 11 V7 A4 4 0 0 1 16 7 V11",
	"gear":"M12 15 A3 3 0 1 0 12 9 A3 3 0 1 0 12 15 M12 2 V5 M12 19 V22 M2 12 H5 M19 12 H22 M5 5 L7 7 M17 17 L19 19 M5 19 L7 17 M17 7 L19 5",
}
static var fonts := {}
static var icons := {}
static var cached_theme: Theme

static func _font(file: String, weight: int) -> Font:
	var key := "%s/%d" % [file,weight]
	if not fonts.has(key):
		var base: FontFile = load("res://Art/Fonts/"+file) if ResourceLoader.exists("res://Art/Fonts/"+file) else null
		if base == null:
			var system := SystemFont.new()
			system.font_names = PackedStringArray(["Segoe UI","Arial","sans-serif"])
			fonts[key] = system
		else:
			var variation := FontVariation.new()
			variation.base_font = base
			variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):weight}
			fonts[key] = variation
	return fonts[key]

static func title_font() -> Font: return _font("Cinzel.ttf",700)
static func ui_font(weight := 500) -> Font: return _font("Inter.ttf",weight)

# A line icon in one colour, rendered from its SVG path.
static func icon(name: String, color := IVORY, size := 28) -> Texture2D:
	var key := "%s/%s/%d" % [name,color.to_html(false),size]
	if not icons.has(key):
		var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='#%s' stroke-width='1.7' stroke-linecap='round' stroke-linejoin='round'><path d='%s'/></svg>" % [color.to_html(false),ICONS.get(name,ICONS.star)]
		var image := Image.new()
		if image.load_svg_from_string(svg,float(size)/24.0) != OK: return null
		icons[key] = ImageTexture.create_from_image(image)
	return icons[key]

static func box(fill: Color, border := EDGE, radius := 10, width := 1, margin := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.anti_aliasing = true
	return style

static func panel() -> StyleBoxFlat: return box(NIGHT,EDGE,12,1,8)

static func label(text: String, size := 14, color := IVORY, weight := 500) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font",ui_font(weight))
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",color)
	return result

# Theme for modern windows and popups (slot editor, menus).
static func theme() -> Theme:
	if cached_theme: return cached_theme
	var t := Theme.new()
	t.default_font = ui_font(500)
	t.default_font_size = 14
	for type in ["Label","CheckBox","CheckButton","LinkButton"]: t.set_color("font_color",type,IVORY)
	for type in ["Button","OptionButton","MenuButton"]:
		t.set_stylebox("normal",type,box(Color(1,1,1,0.05),EDGE,8,1,8))
		t.set_stylebox("hover",type,box(Color(0.84,0.7,0.43,0.16),BRASS,8,1,8))
		t.set_stylebox("pressed",type,box(Color(0.84,0.7,0.43,0.26),BRASS,8,1,8))
		t.set_stylebox("focus",type,box(Color(0,0,0,0),BRASS,8,2,8))
		t.set_stylebox("disabled",type,box(Color(1,1,1,0.02),Color(1,1,1,0.08),8,1,8))
		t.set_color("font_color",type,IVORY)
		t.set_color("font_hover_color",type,Color.WHITE)
		t.set_color("font_disabled_color",type,DIM)
	for type in ["LineEdit","SpinBox","TextEdit"]:
		t.set_stylebox("normal",type,box(Color(0,0,0,0.35),EDGE,8,1,8))
		t.set_stylebox("focus",type,box(Color(0,0,0,0.35),BRASS,8,1,8))
		t.set_color("font_color",type,IVORY)
		t.set_color("font_placeholder_color",type,DIM)
	t.set_stylebox("panel","PanelContainer",panel())
	t.set_stylebox("panel","PopupMenu",box(NIGHT,EDGE,10,1,6))
	t.set_color("font_color","PopupMenu",IVORY)
	t.set_color("font_hover_color","PopupMenu",Color.WHITE)
	t.set_stylebox("hover","PopupMenu",box(Color(0.84,0.7,0.43,0.2),Color(0,0,0,0),6,0,4))
	t.set_stylebox("panel","ItemList",box(Color(0,0,0,0.3),EDGE,8,1,4))
	t.set_stylebox("selected","ItemList",box(Color(0.84,0.7,0.43,0.22),BRASS,6,1,2))
	t.set_stylebox("selected_focus","ItemList",box(Color(0.84,0.7,0.43,0.22),BRASS,6,1,2))
	t.set_color("font_color","ItemList",IVORY)
	cached_theme = t
	return t
