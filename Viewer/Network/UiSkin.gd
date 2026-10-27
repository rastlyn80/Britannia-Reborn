extends RefCounted
# Shared look for in-game windows: a parchment sheet under a dark metal title
# bar. Uses the owner's converted Necromancer GUI art (scripts/import-unity-
# gui.py, ignored res://local-art/gui) when present; otherwise draws an
# equivalent parchment style so the window works without purchased art.
const BASE := "res://local-art/gui"
const INK := Color("3a2716")
const FADED_INK := Color("6e5233")
const TITLE := Color("efe2c0")
const PARCHMENT := Color("e7cf9c")
# Window art regions (pixels in window.png): title bar, parchment margins.
const BAR_TOP := 30.0
const BAR_HEIGHT := 42.0
const CONTENT_MARGINS := Vector4(40,100,40,52) # left, top, right, bottom
static var cached_theme: Theme
static var textures := {}
static var fonts := {}

static func local() -> bool:
	return FileAccess.file_exists(BASE+"/window.png.import")

static func texture(name: String) -> Texture2D:
	if not textures.has(name):
		var path: String = BASE+"/"+name+".png"
		textures[name] = load(path) if FileAccess.file_exists(path+".import") else null
	return textures[name]

# Calligraphic display face from the pack, or the engine font as fallback.
static func heading_font() -> Font:
	if not fonts.has("heading"):
		var path := BASE+"/Kingthings_Calligraphica.ttf"
		var font: Font = null
		if FileAccess.file_exists(path):
			var file := FontFile.new()
			if file.load_dynamic_font(path) == OK: font = file
		if font == null:
			var system := SystemFont.new()
			system.font_names = PackedStringArray(["Georgia","Palatino Linotype","Book Antiqua","Times New Roman","serif"])
			font = system
		fonts.heading = font
	return fonts.heading

static func body_font() -> Font:
	if not fonts.has("body"):
		var system := SystemFont.new()
		system.font_names = PackedStringArray(["Georgia","Palatino Linotype","Book Antiqua","Times New Roman","serif"])
		fonts.body = system
	return fonts.body

static func theme() -> Theme:
	if cached_theme: return cached_theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 15
	for type in ["Label","CheckBox","CheckButton","LinkButton"]:
		t.set_color("font_color",type,INK)
	var normal := _button_style(false)
	var hover := _button_style(true)
	for type in ["Button","OptionButton"]:
		t.set_stylebox("normal",type,normal)
		t.set_stylebox("hover",type,hover)
		t.set_stylebox("pressed",type,hover)
		t.set_stylebox("focus",type,StyleBoxEmpty.new())
		t.set_stylebox("disabled",type,normal)
		# The pack's buttons are pale metal plates; the drawn ones are dark.
		var label := INK if texture("button") else TITLE
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			t.set_color(state,type,label)
		t.set_color("font_disabled_color",type,Color(label,0.45))
	var field := StyleBoxFlat.new()
	field.bg_color = Color(1,0.97,0.88,0.55)
	field.border_color = Color(FADED_INK,0.6)
	field.set_border_width_all(1)
	field.set_corner_radius_all(3)
	field.set_content_margin_all(6)
	t.set_stylebox("normal","LineEdit",field)
	t.set_stylebox("focus","LineEdit",field)
	t.set_color("font_color","LineEdit",INK)
	t.set_color("font_placeholder_color","LineEdit",Color(FADED_INK,0.7))
	t.set_stylebox("panel","ScrollContainer",StyleBoxEmpty.new())
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(FADED_INK,0.7)
	grabber.set_corner_radius_all(4)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(FADED_INK,0.15)
	track.set_corner_radius_all(4)
	track.content_margin_left = 4
	track.content_margin_right = 4
	t.set_stylebox("grabber","VScrollBar",grabber)
	t.set_stylebox("grabber_highlight","VScrollBar",grabber)
	t.set_stylebox("grabber_pressed","VScrollBar",grabber)
	t.set_stylebox("scroll","VScrollBar",track)
	var rule := StyleBoxLine.new()
	rule.color = Color(FADED_INK,0.45)
	rule.thickness = 1
	t.set_stylebox("separator","HSeparator",rule)
	t.set_constant("separation","HSeparator",10)
	cached_theme = t
	return t

static func _button_style(hover: bool) -> StyleBox:
	var art := texture("buttonOver" if hover else "button")
	if art:
		var box := StyleBoxTexture.new()
		box.texture = art
		box.texture_margin_left = 12
		box.texture_margin_right = 12
		box.texture_margin_top = 8
		box.texture_margin_bottom = 8
		box.content_margin_left = 14
		box.content_margin_right = 14
		box.content_margin_top = 4
		box.content_margin_bottom = 5
		return box
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color("5b4a3a") if hover else Color("3f342b")
	flat.border_color = Color("9c8150")
	flat.set_border_width_all(1)
	flat.set_corner_radius_all(3)
	flat.content_margin_left = 12
	flat.content_margin_right = 12
	flat.content_margin_top = 4
	flat.content_margin_bottom = 5
	return flat

# Window background: the pack's nine-sliced parchment, or a drawn equivalent.
static func background() -> Control:
	var art := texture("window")
	if art:
		var patch := NinePatchRect.new()
		patch.texture = art
		patch.patch_margin_left = 40
		patch.patch_margin_right = 40
		patch.patch_margin_top = 96
		patch.patch_margin_bottom = 60
		patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return patch
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sheet := Panel.new()
	var paper := StyleBoxFlat.new()
	paper.bg_color = PARCHMENT
	paper.border_color = Color("8a5a20")
	paper.set_border_width_all(4)
	paper.set_corner_radius_all(4)
	paper.shadow_color = Color(0,0,0,0.45)
	paper.shadow_size = 10
	sheet.add_theme_stylebox_override("panel",paper)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.offset_left = 18
	sheet.offset_right = -18
	sheet.offset_top = 64
	sheet.offset_bottom = -26
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sheet)
	var bar := Panel.new()
	var metal := StyleBoxFlat.new()
	metal.bg_color = Color("3a3f3c")
	metal.border_color = Color("7f9a8e")
	metal.set_border_width_all(2)
	metal.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("panel",metal)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = BAR_TOP
	bar.offset_bottom = BAR_TOP+BAR_HEIGHT
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	return root

# A horizontal meter (hits, stamina, mana, weight) drawn on parchment.
static func meter(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0,14)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.16,0.11,0.07,0.55)
	back.set_corner_radius_all(3)
	back.border_color = Color(0.1,0.07,0.04,0.8)
	back.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background",back)
	bar.add_theme_stylebox_override("fill",fill)
	return bar
