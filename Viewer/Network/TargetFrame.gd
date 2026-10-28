extends PanelContainer
# Top-centre target frame: the creature you selected or last targeted, its
# name in its notoriety colour, health, and distance in tiles. The server is
# asked for the creature's status when the target changes so health shows.
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
var health_text: Label
var clock := 0.0

func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	offset_top = 20
	offset_left = -190
	offset_right = 190
	add_theme_stylebox_override("panel",Look.box(Look.NIGHT,Look.EDGE,12,1,12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation",8)
	column.add_child(head)
	var mark := TextureRect.new()
	mark.texture = Look.icon("target",Look.BLOOD,18)
	mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(mark)
	name_label = Label.new()
	name_label.add_theme_font_override("font",Look.title_font())
	name_label.add_theme_font_size_override("font_size",16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(name_label)
	standing = Look.label("",12,Look.ASH,600)
	head.add_child(standing)
	var clear := Button.new()
	clear.icon = Look.icon("close",Look.ASH,14)
	clear.flat = true
	clear.focus_mode = Control.FOCUS_NONE
	clear.tooltip_text = "Clear target"
	clear.pressed.connect(func():
		Runner.selected = 0
		Runner.last_target = 0)
	head.add_child(clear)
	health = Frame.meter(Look.BLOOD,10)
	column.add_child(health)
	health_text = Look.label("",11,Look.ASH,500)
	column.add_child(health_text)
	hide()

func configure(game: Node) -> void:
	session = game
	session.ended.connect(func():
		shown = 0
		hide())

func current() -> int:
	return Runner.selected if Runner.selected != 0 else Runner.last_target

func _process(delta: float) -> void:
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
		# 0x34 status query (type 4): the server answers with name and hits.
		var query := PackedByteArray([0x34,0xed,0xed,0xed,0xed,4])
		query.append_array(Login.uint_be(serial,4))
		session.send(query)
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
	var top := maxi(1,int(stats.get("hits_max",0)))
	health.max_value = top
	health.value = int(stats.get("hits",top))
	health_text.text = "%d%%" % roundi(100.0*float(stats.get("hits",top))/top) if stats.has("hits") else "Health unknown"
