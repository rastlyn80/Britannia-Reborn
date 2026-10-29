extends VBoxContainer
# Party (0xBF 0x06): a frame per member on the left, under the buff bar,
# with name and health (asked for with status queries, poison in green);
# an invitation card with Accept and Decline; Invite (the server asks for a
# target), Leave, and whether members may loot your corpse. Party chat goes
# to the journal; members' positions are asked for every few seconds and
# shown on the minimap (0xF0).
const Look = preload("res://Network/ModernSkin.gd")
const Social = preload("res://Network/Packets/Social.gd")
var session: Node
var social: RefCounted
var rows := VBoxContainer.new()
var invite_card: PanelContainer
var tools := HBoxContainer.new()
var loot := CheckButton.new()
var clock := 0.0

func _ready() -> void:
	position = Vector2(20,214)
	custom_minimum_size = Vector2(220,0)
	add_theme_constant_override("separation",6)
	theme = Look.theme()
	invite_card = PanelContainer.new()
	invite_card.add_theme_stylebox_override("panel",Look.box(Color(0.055,0.063,0.078,0.95),Look.BRASS,10,1,10))
	add_child(invite_card)
	invite_card.hide()
	rows.add_theme_constant_override("separation",4)
	add_child(rows)
	tools.add_theme_constant_override("separation",4)
	add_child(tools)
	var invite := Button.new()
	invite.text = "Invite"
	invite.tooltip_text = "Invite someone to your party (choose them with the cursor)"
	invite.pressed.connect(func(): session.send(Social.party_add()))
	tools.add_child(invite)
	var leave := Button.new()
	leave.text = "Leave"
	leave.pressed.connect(func(): session.send(Social.party_remove(int(session.player.serial))))
	tools.add_child(leave)
	loot.text = "Loot"
	loot.tooltip_text = "Members may loot your corpse"
	loot.toggled.connect(func(on: bool): session.send(Social.party_loot(on)))
	tools.add_child(loot)
	hide()

func configure(game: Node) -> void:
	session = game
	social = session.module("social")
	social.party_changed.connect(_rebuild)
	social.party_invited.connect(_invited)
	session.ended.connect(func():
		invite_card.hide()
		hide())
	session.status_changed.connect(func(_s: Dictionary): if visible: _refresh())
	session.module("mobiles").flags_changed.connect(func(_serial: int): if visible: _refresh())

func _invited(leader: int) -> void:
	preload("res://Network/ModernWindow.gd").clear(invite_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	invite_card.add_child(column)
	var who := str(session.entity_names.get(leader,"Someone"))
	var text := Look.label("%s invites you to their party." % who,13,Look.IVORY,600)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	column.add_child(row)
	for entry in [["Accept",true],["Decline",false]]:
		var b := Button.new()
		b.text = entry[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if entry[1]:
			b.add_theme_stylebox_override("normal",Look.box(Look.BRASS,Look.BRASS,8,1,6))
			b.add_theme_color_override("font_color",Color("14110b"))
		b.pressed.connect(func():
			session.send(Social.party_accept(leader) if entry[1] else Social.party_decline(leader))
			invite_card.hide())
		row.add_child(b)
	invite_card.show()
	show()

func _rebuild() -> void:
	preload("res://Network/ModernWindow.gd").clear(rows)
	var me := int(session.player.serial)
	for member in social.party:
		if int(member) == me: continue
		session.send(preload("res://Network/MobileNames.gd").query(int(member)))
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel",Look.box(Look.NIGHT,Look.EDGE,10,1,8))
		card.set_meta("serial",int(member))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",4)
		card.add_child(column)
		column.add_child(Look.label("",13,Look.IVORY,600))
		column.add_child(preload("res://Network/ModernWindow.gd").meter(Look.BLOOD,8))
		rows.add_child(card)
	tools.visible = not social.party.is_empty()
	visible = not social.party.is_empty() or invite_card.visible
	_refresh()

func _refresh() -> void:
	for card in rows.get_children():
		var serial := int(card.get_meta("serial",0))
		var stats: Dictionary = session.mobile_statistics.get(serial,{})
		var column: VBoxContainer = card.get_child(0)
		(column.get_child(0) as Label).text = str(session.entity_names.get(serial,stats.get("name","Member")))
		var bar: ProgressBar = column.get_child(1)
		bar.max_value = maxi(1,int(stats.get("hits_max",1)))
		bar.value = int(stats.get("hits",stats.get("hits_max",1)))
		bar.add_theme_stylebox_override("fill",Look.box(Color("6dbe5a") if stats.get("poisoned",false) else Look.BLOOD,Color(0,0,0,0),4,0,0))

func _process(delta: float) -> void:
	if not visible or social == null or social.party.size() < 2: return
	clock -= delta
	if clock > 0.0: return
	clock = 3.0
	session.send(Social.party_locations())
