extends PanelContainer
# Top-centre target frame: the creature you are fighting (the server's attack
# target, 0xAA) or else the one you selected or last targeted, its name in
# its notoriety colour, health, and distance in tiles. The server is asked
# for the creature's status when the target changes so health shows. A hit
# flashes the frame and shows the damage; the bar slides down with a pale
# trail of what was just lost. Click it to answer a target cursor, double-click
# it to attack in war mode, and drag it out to leave a small bar for that
# creature on the screen (MobileBar).
const Look = preload("res://Network/ModernSkin.gd")
const Frame = preload("res://Network/ModernWindow.gd")
const Runner = preload("res://Network/ActionRunner.gd")
const Login = preload("res://Network/LoginProtocol.gd")
# Notoriety 1 innocent … 7 invulnerable: name colour and what it means.
const NOTORIETY := {1:["8fc1ff","Innocent"],2:["9bd88a","Ally"],3:["b8b2a4","Attackable"],4:["b8b2a4","Criminal"],5:["f0a35e","Enemy"],6:["f0716a","Murderer"],7:["e2c27a","Invulnerable"]}
var session: Node
var shown := 0
var name_label: Label
var standing: Label
var health: ProgressBar
var trail: ProgressBar
var health_text: Label
var fighting: Label
var hit_label: Label
var clock := 0.0
var press_at := Vector2.ZERO
var pressed := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_left = 0.5
	anchor_right = 0.5
	offset_top = 16
	offset_left = -130
	offset_right = 130
	add_theme_stylebox_override("panel",Look.box(Look.NIGHT,Look.EDGE,10,1,8))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",4)
	add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation",8)
	column.add_child(head)
	var mark := TextureRect.new()
	mark.texture = Look.icon("target",Look.BLOOD,14)
	mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(mark)
	name_label = Label.new()
	name_label.add_theme_font_override("font",Look.title_font())
	name_label.add_theme_font_size_override("font_size",13)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(name_label)
	fighting = Look.label("Attacking",11,Color("f0716a"),700)
	fighting.hide()
	head.add_child(fighting)
	standing = Look.label("",11,Look.ASH,600)
	head.add_child(standing)
	var clear := Button.new()
	clear.icon = Look.icon("close",Look.ASH,12)
	clear.flat = true
	clear.focus_mode = Control.FOCUS_NONE
	clear.tooltip_text = "Clear target"
	clear.pressed.connect(func():
		Runner.selected = 0
		Runner.last_target = 0)
	head.add_child(clear)
	# The bar over a pale trail that follows it down after a hit.
	var bars := Control.new()
	bars.custom_minimum_size = Vector2(0,7)
	column.add_child(bars)
	trail = Frame.meter(Color("f2c3a0"),7)
	trail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bars.add_child(trail)
	health = Frame.meter(Look.BLOOD,7)
	health.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health.add_theme_stylebox_override("background",Look.box(Color(0,0,0,0),Color(0,0,0,0),5,0,0))
	bars.add_child(health)
	var foot := HBoxContainer.new()
	column.add_child(foot)
	health_text = Look.label("",10,Look.ASH,500)
	health_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(health_text)
	hit_label = Look.label("",11,Color("ffd27a"),700)
	foot.add_child(hit_label)
	hide()

func configure(game: Node) -> void:
	session = game
	session.ended.connect(func():
		shown = 0
		hide())
	session.module("combat").damaged.connect(_hit)

# Clicking the bar answers a waiting target cursor with this creature (a
# spell or bandage waiting for a target), and otherwise selects it; a
# double-click attacks in war mode; dragging pulls out a bar for it.
func _gui_input(event: InputEvent) -> void:
	if session == null or not event is InputEventMouseButton and not event is InputEventMouseMotion: return
	var who := shown if shown != 0 else current()
	if who == 0: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressed = true
			press_at = event.position
			preload("res://Network/MobileBar.gd").act(session,who,event.double_click)
		elif pressed:
			pressed = false
			if event.position.distance_to(press_at) > 12.0:
				preload("res://Network/MobileBar.gd").pull(get_parent(),session,who,get_global_mouse_position())
		accept_event()
	elif event is InputEventMouseMotion and pressed:
		mouse_default_cursor_shape = Control.CURSOR_DRAG if event.position.distance_to(press_at) > 12.0 else mouse_default_cursor_shape

func _process_hint() -> void:
	if pressed: return
	var waiting: bool = session != null and not session.target_request.is_empty()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if waiting else Control.CURSOR_ARROW
	if session == null: return
	tooltip_text = "Click to target" if waiting else preload("res://Network/MobileBar.gd").describe(session,shown,"Click: select and menu · Double-click: attack (war mode) · Drag out: keep a bar")

func current() -> int:
	return preload("res://Network/OverheadBars.gd").target_of(session)

func _hit(serial: int, amount: int) -> void:
	if serial != shown or not visible or amount <= 0: return
	hit_label.text = "−%d" % amount
	hit_label.modulate.a = 1.0
	modulate = Color(1.5,1.1,1.0)
	var flash := create_tween()
	flash.tween_property(self,"modulate",Color.WHITE,0.35)
	var fade := hit_label.create_tween()
	fade.tween_interval(1.2)
	fade.tween_property(hit_label,"modulate:a",0.0,0.5)

func _process(delta: float) -> void:
	_process_hint()
	if session == null or session.phase != "world": return
	clock -= delta
	if clock > 0.0: return
	clock = 0.2
	var serial := current()
	if serial == 0 or not session.entities.has(serial):
		hide()
		return
	if serial != shown:
		shown = serial
		hit_label.text = ""
		trail.value = 0
		# The server answers a status query with name and hits.
		session.send(preload("res://Network/MobileNames.gd").query(serial))
	show()
	var entity: Dictionary = session.entities[serial]
	var stats: Dictionary = session.mobile_statistics.get(serial,{})
	var kind: Array = NOTORIETY.get(int(entity.get("notoriety",0)),["eee7d7",""])
	name_label.text = str(session.entity_names.get(serial,stats.get("name","Creature")))
	name_label.add_theme_color_override("font_color",Color(kind[0]))
	var me: Dictionary = session.player
	var tiles := maxi(absi(int(entity.get("x",0))-int(me.get("x",0))),absi(int(entity.get("y",0))-int(me.get("y",0))))
	standing.text = "%s · %d tiles" % [kind[1],tiles] if kind[1] != "" else "%d tiles" % tiles
	standing.add_theme_color_override("font_color",Color(kind[0]))
	# Poison turns the bar green and the server's yellow bar (cannot be
	# harmed) gold, as the health-bar flags (0x16/0x17) say.
	var poisoned := bool(stats.get("poisoned",false)) or (int(entity.get("flags",0)) & 0x04) != 0
	var tone: Color = Color("6dbe5a") if poisoned else (Look.GOLD if stats.get("yellow_bar",false) else Look.BLOOD)
	health.add_theme_stylebox_override("fill",Look.box(tone,Color(0,0,0,0),6,0,0))
	if poisoned: standing.text += " · poisoned"
	var top := maxi(1,int(stats.get("hits_max",0)))
	health.max_value = top
	trail.max_value = top
	var hits := int(stats.get("hits",top))
	if hits != int(health.value):
		create_tween().tween_property(health,"value",float(hits),0.25)
	# The trail waits a moment, then follows; healing moves it at once.
	if hits >= trail.value: trail.value = hits
	elif not has_meta("trailing"):
		set_meta("trailing",true)
		var follow := create_tween()
		follow.tween_interval(0.5)
		follow.tween_property(trail,"value",float(hits),0.6)
		follow.tween_callback(func(): remove_meta("trailing"))
	fighting.visible = session.module("combat").attack_target == serial
	health_text.text = "%d%%" % roundi(100.0*float(stats.get("hits",top))/top) if stats.has("hits") else "Health unknown"
