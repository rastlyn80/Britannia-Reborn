extends VBoxContainer
# Right-side notices that fade after a few seconds: skill and stat gains
# (and losses), gold gained or spent, and anything else worth a glance.
# A gain shows the new value and a bar toward its cap; further gains of the
# same skill or stat update that card instead of stacking new ones.
const Look = preload("res://Network/ModernSkin.gd")
const Frame = preload("res://Network/ModernWindow.gd")
const Character = preload("res://Network/CharacterProtocol.gd")
const SHOW_SECONDS := 5.0
const MOST := 5
const STATS := {"str":"Strength","dex":"Dexterity","int":"Intelligence"}
var session: Node
var skill_values := {}
var stat_values := {}
var gold := -1
# Equipment or buffs change the stats the server reports by more than a
# gain; for a moment after either, a changed stat is not a gain.
var settle_until := 0
# key -> card of a gain still on screen
var cards := {}

func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	# Top right, below the window menu's reach and clear of the minimap.
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -20
	offset_top = 150
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation",6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(game: Node) -> void:
	session = game
	session.skills_changed.connect(_skills)
	session.status_changed.connect(_status)
	session.items_changed.connect(_settle)
	session.module("buffs").changed.connect(_settle)
	session.ended.connect(func():
		skill_values.clear()
		stat_values.clear()
		cards.clear()
		gold = -1
		for child in get_children(): child.queue_free())

func _settle() -> void:
	settle_until = Time.get_ticks_msec()+2500

func _skills(skills: Dictionary) -> void:
	for id in skills:
		var now := float(skills[id].base)
		if skill_values.has(id) and absf(now-float(skill_values[id])) >= 0.05:
			gain("skill:%d" % id,Character.SKILLS[id],now-float(skill_values[id]),now,float(skills[id].get("cap",100.0)),"%.1f")
		skill_values[id] = now

func _status(status: Dictionary) -> void:
	# Stat gains are single points; larger jumps are equipment or spells.
	for key in STATS:
		if not status.has(key): continue
		var now := int(status[key])
		if stat_values.has(key):
			var change := now-int(stat_values[key])
			if absi(change) == 1 and Time.get_ticks_msec() > settle_until:
				gain("stat:"+key,STATS[key],change,now,float(status.get("stat_cap",225))/3.0 if int(status.get("stat_cap",0)) > 0 else 125.0,"%d")
		stat_values[key] = now
	if status.has("gold"):
		var coins := int(status.gold)
		if gold >= 0 and coins != gold: notify("Gold","%+d (%d)" % [coins-gold,coins],Look.GOLD)
		gold = coins

# A gain card: name, new value, the change and a bar toward the cap. The
# same key again within the card's life adds up on that card.
func gain(key: String, title: String, change: float, value: float, cap: float, number: String) -> void:
	var card: PanelContainer = cards.get(key)
	if card == null or not is_instance_valid(card) or card.is_queued_for_deletion():
		card = PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.custom_minimum_size = Vector2(250,0)
		card.add_theme_stylebox_override("panel",Look.box(Look.NIGHT,Look.EDGE,8,1,10))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",5)
		card.add_child(column)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		column.add_child(row)
		var mark := TextureRect.new()
		mark.texture = Look.icon("star" if key.begins_with("stat") else "skills",Look.GOLD,16)
		mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(mark)
		var name := Look.label(title,13,Look.IVORY,700)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var amount := Look.label("",13,Look.HERB,700)
		amount.name = "Amount"
		row.add_child(amount)
		var bar := Frame.meter(Look.GOLD,6)
		bar.name = "Bar"
		column.add_child(bar)
		var line := Look.label("",11,Look.ASH,500)
		line.name = "Line"
		column.add_child(line)
		card.set_meta("total",0.0)
		add_child(card)
		cards[key] = card
		while get_child_count() > MOST: get_child(0).free()
	var total := float(card.get_meta("total"))+change
	card.set_meta("total",total)
	# A gain taken straight back (a stat swap undone) leaves nothing to show.
	if absf(total) < 0.05:
		cards.erase(key)
		card.queue_free()
		return
	var up := total >= 0
	var amount_label: Label = card.find_child("Amount",true,false)
	amount_label.text = ("+" if up else "")+(number % total)
	amount_label.add_theme_color_override("font_color",Look.HERB if up else Color("f0a39a"))
	var bar: ProgressBar = card.find_child("Bar",true,false)
	bar.max_value = maxf(cap,value)
	bar.value = value
	var line_label: Label = card.find_child("Line",true,false)
	line_label.text = ("now "+number+" of "+number) % [value,cap]
	# A fresh gain glows briefly and restarts the card's life.
	card.modulate = Color(1.35,1.3,1.15)
	if card.has_meta("tween"): (card.get_meta("tween") as Tween).kill()
	var fade := card.create_tween()
	fade.tween_property(card,"modulate",Color.WHITE,0.4)
	fade.tween_interval(SHOW_SECONDS)
	fade.tween_property(card,"modulate:a",0.0,0.6)
	fade.tween_callback(card.queue_free)
	card.set_meta("tween",fade)

func notify(head: String, text: String, color := Look.GOLD) -> void:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel",Look.box(Look.NIGHT,Look.EDGE,8,1,8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	card.add_child(row)
	row.add_child(Look.label(head,13,color,700))
	row.add_child(Look.label(text,13,Look.IVORY,500))
	add_child(card)
	while get_child_count() > MOST: get_child(0).free()
	var fade := card.create_tween()
	fade.tween_interval(SHOW_SECONDS)
	fade.tween_property(card,"modulate:a",0.0,0.6)
	fade.tween_callback(card.queue_free)
