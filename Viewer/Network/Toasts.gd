extends VBoxContainer
# Right-side notices that fade after a few seconds: skill gains and losses,
# gold gained or spent, and anything else worth a glance.
const Look = preload("res://Network/ModernSkin.gd")
const Character = preload("res://Network/CharacterProtocol.gd")
const SHOW_SECONDS := 5.0
const MOST := 5
var session: Node
var skill_values := {}
var gold := -1

func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -20
	offset_top = -60
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation",6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(game: Node) -> void:
	session = game
	session.skills_changed.connect(_skills)
	session.status_changed.connect(_status)
	session.ended.connect(func():
		skill_values.clear()
		gold = -1
		for child in get_children(): child.queue_free())

func _skills(skills: Dictionary) -> void:
	for id in skills:
		var now := float(skills[id].base)
		if skill_values.has(id) and absf(now-float(skill_values[id])) >= 0.05:
			var change := now-float(skill_values[id])
			notify("%+.1f" % change,"%s %.1f" % [Character.SKILLS[id],now],Look.HERB if change > 0 else Color("f0a39a"))
		skill_values[id] = now

func _status(status: Dictionary) -> void:
	if not status.has("gold"): return
	var now := int(status.gold)
	if gold >= 0 and now != gold: notify("Gold","%+d (%d)" % [now-gold,now],Look.GOLD)
	gold = now

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
