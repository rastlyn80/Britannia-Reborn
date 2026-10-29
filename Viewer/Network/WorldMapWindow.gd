extends "res://Network/ModernWindow.gd"
# World map (M): your facet's radar map with you, your party, the quest
# target, houses and boats the server has shown you; any other facet can be
# looked at from the picker.
# Wheel zooms around the mouse, drag pans, double-click centres, right-click
# walks there; Follow keeps you in the middle.
const Canvas = preload("res://Network/MapCanvas.gd")
var scene: Node3D
var canvas: Control
var follow: CheckButton
var note: Label
var facet_pick: OptionButton
var dragging_map := false
var last := Vector2.ZERO

func _ready() -> void:
	setup("worldmap","World map",Vector2(860,620),Vector2(320,80))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation",8)
	body.add_child(bar)
	follow = CheckButton.new()
	follow.text = "Follow me"
	follow.button_pressed = true
	bar.add_child(follow)
	for zoom in [["−",2.0],["+",0.5]]:
		var button := Button.new()
		button.text = zoom[0]
		button.custom_minimum_size = Vector2(36,30)
		button.pressed.connect(func(): _zoom(float(zoom[1]),canvas.size/2))
		bar.add_child(button)
	var whole := Button.new()
	whole.text = "Whole map"
	whole.pressed.connect(func():
		follow.button_pressed = false
		var info: Dictionary = canvas.index()
		# Felucca and Trammel: the mainland without the dungeons' strip.
		var width := 5120.0 if canvas.facet in [0,1] else float(info.get("width",5120))
		canvas.view = Rect2(0,0,width,float(info.get("height",4096))))
	bar.add_child(whole)
	# Any facet's map; following you returns to yours.
	facet_pick = OptionButton.new()
	for facet in Canvas.facets(): facet_pick.add_item(str(Canvas.index_of(int(facet)).get("name","Facet %d" % facet)),int(facet))
	facet_pick.item_selected.connect(func(index: int):
		var chosen := facet_pick.get_item_id(index)
		if chosen == canvas.facet: return
		follow.button_pressed = chosen == _player_facet()
		canvas.facet = chosen
		var info: Dictionary = canvas.index()
		canvas.view = Rect2(0,0,float(info.get("width",4096)),float(info.get("height",4096))))
	bar.add_child(facet_pick)
	note = Look.label("",12,Look.ASH,500)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(note)
	canvas = Canvas.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.custom_minimum_size = Vector2(400,300)
	canvas.view = Rect2(1300,1400,600,420)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.gui_input.connect(_canvas_input)
	body.add_child(canvas)

func configure(world_scene: Node3D) -> void:
	scene = world_scene
	scene.game.ended.connect(hide)

func toggle() -> void:
	visible = not visible
	if visible: move_to_front()

func _zoom(factor: float, around: Vector2) -> void:
	var pivot: Vector2 = canvas.to_world(around)
	var size: Vector2 = (canvas.view.size*factor).clamp(Vector2(60,42),Vector2(7168,5734))
	var share := around/canvas.size
	canvas.view = Rect2(pivot-size*share,size)
	canvas.queue_redraw()

func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: _zoom(0.8,event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: _zoom(1.25,event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and scene.autowalk:
			# Walk here: one server-checked step at a time.
			var spot: Vector2 = canvas.to_world(event.position)
			scene.autowalk.walk_to(Vector2i(floori(spot.x),floori(spot.y)))
			note.text = "Walking to %d, %d" % [floori(spot.x),floori(spot.y)]
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging_map = event.pressed
			last = event.position
			if event.double_click:
				canvas.view.position = canvas.to_world(event.position)-canvas.view.size/2
				follow.button_pressed = false
		canvas.accept_event()
	elif event is InputEventMouseMotion and dragging_map:
		follow.button_pressed = false
		canvas.view.position -= (event.position-last)/canvas.size*canvas.view.size
		last = event.position
		canvas.queue_redraw()
		canvas.accept_event()

func _process(_delta: float) -> void:
	if not visible or scene == null or scene.game.phase != "world": return
	var game: Node = scene.game
	var me := Vector2(float(game.player.x)+0.5,float(game.player.y)+0.5)
	if follow.button_pressed:
		if canvas.facet != _player_facet():
			canvas.facet = _player_facet()
			facet_pick.select(maxi(0,facet_pick.get_item_index(canvas.facet)))
		canvas.view.position = me-canvas.view.size/2
	var here: bool = canvas.facet == _player_facet()
	var marks: Array = []
	for multi in game.multis.values():
		var boat: bool = preload("res://Presentation/ShipBuilder.gd").handles(int(multi.id))
		marks.append({"at":Vector2(multi.x+0.5,multi.y+0.5),"shape":"diamond" if boat else "house","color":Color("6fa8c9") if boat else Color("c7a46a"),"size":5.0})
	var social: RefCounted = game.module("social")
	for serial in social.member_locations:
		var place: Dictionary = social.member_locations[serial]
		if int(serial) != int(game.player.serial): marks.append({"at":Vector2(place.x+0.5,place.y+0.5),"color":Look.HERB,"label":str(game.entity_names.get(int(serial),"")),"size":5.0})
	if social.arrow.get("active",false): marks.append({"at":Vector2(social.arrow.x+0.5,social.arrow.y+0.5),"shape":"diamond","color":Look.GOLD,"size":7.0,"label":"Quest"})
	if scene.autowalk and scene.autowalk.active(): marks.append({"at":Vector2(scene.autowalk.goal)+Vector2(0.5,0.5),"shape":"pin","color":Look.HERB,"size":5.0})
	marks.append({"at":me,"shape":"player","color":Look.IVORY,"size":7.0,"facing":(int(game.player.get("direction",0))&7)*PI/4})
	canvas.markers = marks if here else []
	if not (scene.autowalk and scene.autowalk.active()): note.text = "%s · X %d  Y %d" % [str(canvas.index().get("name","Facet %d" % canvas.facet)),game.player.x,game.player.y] if here else str(canvas.index().get("name",""))
	canvas.queue_redraw()

func _player_facet() -> int:
	return int(scene.game.player.get("facet",1))
