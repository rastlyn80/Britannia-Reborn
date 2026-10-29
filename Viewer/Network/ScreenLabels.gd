extends Control
# Billboard captions (nameplates, building names) drawn as screen text. A
# Label3D is rasterised into the 3D scene and resampled with it, which reads
# soft; tracked labels stay in the scene as the source of text, colour and
# visibility but are culled from every camera, and a 2D label at their
# projected position draws them at native pixel sharpness.
const Look = preload("res://Network/ModernSkin.gd")
const GROUP := "screen_label"
const RANGE := 32.0
var camera: Camera3D
var drawn: Dictionary = {}

static func track(label: Label3D) -> void:
	label.add_to_group(GROUP)
	label.layers = 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _caption() -> Label:
	var caption := Label.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_override("font",Look.ui_font(600))
	caption.add_theme_color_override("font_outline_color",Color(0.03,0.035,0.045,0.92))
	caption.add_theme_constant_override("outline_size",5)
	caption.add_theme_color_override("font_shadow_color",Color(0,0,0,0.45))
	caption.add_theme_constant_override("shadow_offset_y",1)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(caption)
	return caption

func _process(_delta: float) -> void:
	var seen: Dictionary = {}
	if camera and camera.is_inside_tree():
		var eye := camera.global_position
		for source in get_tree().get_nodes_in_group(GROUP):
			var label := source as Label3D
			if label == null or not label.is_visible_in_tree() or label.text.is_empty(): continue
			var at := label.global_position
			var distance := eye.distance_to(at)
			if distance > RANGE or camera.is_position_behind(at): continue
			var key := label.get_instance_id()
			seen[key] = true
			var caption: Label = drawn.get(key)
			if caption == null:
				caption = _caption()
				drawn[key] = caption
			caption.text = label.text
			caption.add_theme_color_override("font_color",label.modulate)
			# Slightly smaller with distance, in whole pixels to keep glyphs cached.
			var size := clampi(roundi(17.0-distance*0.2),11,17)
			if caption.get_theme_font_size("font_size") != size: caption.add_theme_font_size_override("font_size",size)
			caption.reset_size()
			var point := camera.unproject_position(at)
			caption.position = (point-Vector2(caption.size.x/2,caption.size.y)).round()
			caption.show()
	for key in drawn.keys():
		if not seen.has(key):
			if is_instance_valid(instance_from_id(key)): drawn[key].hide()
			else:
				drawn[key].queue_free()
				drawn.erase(key)
