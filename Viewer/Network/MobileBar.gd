extends PanelContainer
# A small health bar pulled out for one creature, as in the original client:
# drag a creature (in the world or from the target frame) onto the screen and
# its bar stays there, wherever you drop it, until right-clicked away. Click
# it to answer a waiting target cursor (or select the creature); double-click
# it to attack in war mode, or use it in peace. It dims while the creature is
# out of sight and asks the server for its status when it returns.
const Look = preload("res://Network/ModernSkin.gd")
const Frame = preload("res://Network/ModernWindow.gd")
const Runner = preload("res://Network/ActionRunner.gd")
const WIDTH := 168.0
var session: Node
var serial := 0
var name_label: Label
var health: ProgressBar
var grab := Vector2.ZERO
var dragging := false
var seen := false
var clock := 0.0

# The bar for this creature, created or moved so it sits at the drop point.
static func pull(parent: Node, game: Node, mobile: int, at: Vector2) -> Control:
	for child in parent.get_children():
		if child.get_script() == preload("res://Network/MobileBar.gd") and child.serial == mobile:
			child.position = at-Vector2(WIDTH*0.5,12)
			parent.move_child(child,-1)
			return child
	var bar := preload("res://Network/MobileBar.gd").new()
	bar.session = game
	bar.serial = mobile
	parent.add_child(bar)
	bar.position = at-Vector2(WIDTH*0.5,12)
	return bar

# What a click on any creature bar does (also the target frame and party cards).
static func act(game: Node, mobile: int, double: bool) -> void:
	if mobile == 0 or game == null: return
	if not double:
		if not game.target_request.is_empty(): Runner.target_entity(game,mobile)
		else: Runner.selected = mobile
		return
	var me := int(game.player.get("serial",0))
	if game.in_war_mode() and mobile != me:
		if game.attack(mobile): Runner.last_target = mobile
	elif game.in_war_mode():
		game.send(preload("res://Network/Packets/Player.gd").open_paperdoll(mobile))
	else:
		game.use_mobile(mobile)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(WIDTH,0)
	size = Vector2(WIDTH,0)
	add_theme_stylebox_override("panel",Look.box(Look.NIGHT,Look.EDGE,8,1,6))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	name_label = Look.label("",12,Look.IVORY,600)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	health = Frame.meter(Look.BLOOD,6)
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(health)
	tooltip_text = "Click: select / target · Double-click: attack (war) · Drag: move · Right-click: close"
	if session: session.send(preload("res://Network/MobileNames.gd").query(serial))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		queue_free()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			get_parent().move_child(self,-1)
			grab = event.position
			dragging = false
			act(session,serial,event.double_click)
		accept_event()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if dragging or event.position.distance_to(grab) > 4.0:
			dragging = true
			position += event.position-grab
		accept_event()

func _process(delta: float) -> void:
	var waiting: bool = session != null and not session.target_request.is_empty()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if waiting else Control.CURSOR_ARROW
	clock -= delta
	if clock > 0.0 or session == null: return
	clock = 0.2
	if session.phase != "world":
		queue_free()
		return
	var entity: Dictionary = session.entities.get(serial,{})
	var here := not entity.is_empty() or serial == int(session.player.get("serial",0))
	modulate.a = 1.0 if here else 0.45
	if here and not seen: session.send(preload("res://Network/MobileNames.gd").query(serial))
	seen = here
	var stats: Dictionary = session.mobile_statistics.get(serial,{})
	var kind: Array = preload("res://Network/TargetFrame.gd").NOTORIETY.get(int(entity.get("notoriety",0)),["eee7d7",""])
	name_label.text = str(session.entity_names.get(serial,stats.get("name","Creature")))
	name_label.add_theme_color_override("font_color",Color(kind[0]))
	var poisoned := bool(stats.get("poisoned",false)) or (int(entity.get("flags",0)) & 0x04) != 0
	var tone: Color = Color("6dbe5a") if poisoned else (Look.GOLD if stats.get("yellow_bar",false) else Look.BLOOD)
	health.add_theme_stylebox_override("fill",Look.box(tone,Color(0,0,0,0),3,0,0))
	var top := maxi(1,int(stats.get("hits_max",0)))
	health.max_value = top
	health.value = int(stats.get("hits",top)) if here else 0
	var fighting: bool = session.module("combat").attack_target == serial
	add_theme_stylebox_override("panel",Look.box(Look.NIGHT,Color("f0716a") if fighting else (Look.GOLD if Runner.selected == serial else Look.EDGE),8,1,6))
