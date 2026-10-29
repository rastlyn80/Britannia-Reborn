extends RefCounted
# The interface keeps its proportions on any monitor: the whole 2D layer (HUD,
# windows, gumps, the front end) is laid out for a 1600x900 reference screen
# and scaled uniformly to the window (Godot's canvas_items stretch, so text is
# drawn crisp at the real resolution). Wider or taller screens get more room
# at the edges ("expand") instead of distortion. The 3D world is untouched.
# Settings › Interface size multiplies it (saved per character, Profile.gd).
const REFERENCE := Vector2i(1600,900)
const SETTINGS := "user://interface.cfg"
const SMALLEST := 0.75
const LARGEST := 1.4

# Per character (Network/Profile.gd); the older computer-wide file is the default.
static func size() -> float:
	var config := ConfigFile.new()
	var older := float(config.get_value("interface","size",1.0)) if config.load(SETTINGS) == OK else 1.0
	return clampf(float(preload("res://Network/Profile.gd").value("interface","size",older)),SMALLEST,LARGEST)

static func apply(window: Window) -> void:
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = REFERENCE
	window.content_scale_factor = size()

static func set_size(window: Window, value: float) -> void:
	preload("res://Network/Profile.gd").store("interface","size",clampf(value,SMALLEST,LARGEST))
	window.content_scale_factor = size()
