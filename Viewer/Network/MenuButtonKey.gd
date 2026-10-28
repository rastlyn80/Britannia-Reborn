extends Button
# A menu button that prints its keyboard shortcut in the corner.
const Look = preload("res://Network/ModernSkin.gd")
var key_text := ""

func _draw() -> void:
	if key_text != "": draw_string(Look.ui_font(700),Vector2(0,size.y-4),key_text,HORIZONTAL_ALIGNMENT_RIGHT,size.x-4,10,Look.ASH)
