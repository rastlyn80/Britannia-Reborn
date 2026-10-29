extends Control
# Quest and tracking arrows (0xBA): a gold marker over the target when it is
# on screen, an arrow at the screen's edge pointing to it when it is not,
# with the distance in tiles. Left-click acknowledges, right-click cancels
# (0xBF 0x07). The minimap shows the same target.
const Look = preload("res://Network/ModernSkin.gd")
const Social = preload("res://Network/Packets/Social.gd")
var scene: Node3D
var social: RefCounted
var hit := Rect2()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(world_scene: Node3D) -> void:
	scene = world_scene
	social = scene.game.module("social")

func _target() -> Vector3:
	var arrow: Dictionary = social.arrow
	return scene.entity_point(int(arrow.x),int(arrow.y),int(scene.game.player.get("z",0)))+Vector3.UP*1.5

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	hit = Rect2()
	if social == null or not social.arrow.get("active",false) or scene.game.phase != "world": return
	var camera: Camera3D = scene.camera
	var at := _target()
	var screen := get_viewport_rect().size
	var tiles := maxi(absi(int(social.arrow.x)-int(scene.game.player.x)),absi(int(social.arrow.y)-int(scene.game.player.y)))
	var font := Look.ui_font(700)
	# The open view, clear of the vitals above and the quickbar below.
	var band := Rect2(Vector2(70,130),screen-Vector2(140,130+260))
	if not camera.is_position_behind(at):
		var point := camera.unproject_position(at)
		if band.has_point(point):
			# On screen: a diamond over the target.
			draw_colored_polygon(PackedVector2Array([point+Vector2(0,-14),point+Vector2(10,0),point+Vector2(0,14),point+Vector2(-10,0)]),Color(Look.GOLD,0.92))
			draw_string(font,point+Vector2(-40,32),"%d tiles" % tiles,HORIZONTAL_ALIGNMENT_CENTER,80,12,Look.IVORY)
			hit = Rect2(point-Vector2(16,16),Vector2(32,32))
			return
	# Off screen: an arrow on the edge of the open view, pointing the way.
	var center := band.get_center()
	var toward := camera.unproject_position(at)-center
	if camera.is_position_behind(at): toward = -toward
	if toward.length() < 1.0: toward = Vector2.UP
	toward = toward.normalized()
	var reach := minf(band.size.x/2.0/maxf(absf(toward.x),0.001),band.size.y/2.0/maxf(absf(toward.y),0.001))
	var point := center+toward*reach
	var side := toward.orthogonal()
	draw_circle(point,22,Color(0.055,0.063,0.078,0.85))
	draw_colored_polygon(PackedVector2Array([point+toward*16,point-toward*8+side*10,point-toward*2,point-toward*8-side*10]),Look.GOLD)
	draw_string(font,point+Vector2(-40,38),"%d tiles" % tiles,HORIZONTAL_ALIGNMENT_CENTER,80,12,Look.IVORY)
	hit = Rect2(point-Vector2(22,22),Vector2(44,44))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and hit.has_point(event.position) and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		scene.game.send(Social.arrow_click(event.button_index == MOUSE_BUTTON_RIGHT))
		get_viewport().set_input_as_handled()
