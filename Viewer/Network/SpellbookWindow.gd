extends "res://Network/ModernWindow.gd"
# Spellbook (P): every school, Magery by circle, the reagents in your pack
# along the top (missing ones in red), spell cards that say what is missing,
# and the chosen spell's words of power, mana and reagents with a Cast button.
# Drag a card's handle onto the quickbar, or use "Add to quickbar".
const Catalog = preload("res://Network/ActionCatalog.gd")
var runner: Node
var school := "Magery"
var circle := 1
var chosen := ""
var school_chips := {}
var circle_row := HBoxContainer.new()
var reagent_row := HBoxContainer.new()
var grid := GridContainer.new()
var detail := VBoxContainer.new()
var feedback: Label

func _ready() -> void:
	setup("spellbook","Spellbook",Vector2(960,600),Vector2(120,110))
	var schools := HBoxContainer.new()
	schools.add_theme_constant_override("separation",6)
	body.add_child(schools)
	for name in Catalog.SCHOOLS:
		var c := chip(name,name == school)
		c.pressed.connect(func():
			school = name
			circle = 1
			chosen = ""
			refresh())
		schools.add_child(c)
		school_chips[name] = c
	reagent_row.add_theme_constant_override("separation",6)
	body.add_child(reagent_row)
	circle_row.add_theme_constant_override("separation",6)
	body.add_child(circle_row)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation",16)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(split)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	scroll.add_child(grid)
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel",Look.box(Color(1,1,1,0.03),Color(0.84,0.7,0.43,0.2),10,1,14))
	side.custom_minimum_size = Vector2(300,0)
	split.add_child(side)
	detail.add_theme_constant_override("separation",10)
	side.add_child(detail)
	feedback = Look.label("",13,Look.GOLD,500)
	body.add_child(feedback)

func configure(action_runner: Node) -> void:
	runner = action_runner
	runner.session.items_changed.connect(func(): if visible: refresh())
	runner.session.status_changed.connect(func(_s: Dictionary): if visible: refresh())
	runner.feedback.connect(func(text: String): if visible: feedback.text = text)
	runner.session.ended.connect(hide)

func toggle() -> void:
	super.toggle()
	if visible: refresh()

func _spells() -> Array:
	return Catalog.spells().filter(func(s): return s.school == school and (school != "Magery" or int(s.circle) == circle))

func _missing(spell: Dictionary) -> Array:
	var result := []
	for code in spell.get("reagents",[]):
		if runner.count_of(int(Catalog.REAGENTS[code][0])) == 0: result.append(Catalog.REAGENTS[code][1])
	return result

func refresh() -> void:
	for name in school_chips: school_chips[name].set_pressed_no_signal(name == school)
	clear(reagent_row)
	clear(circle_row)
	clear(grid)
	clear(detail)
	if school == "Magery":
		reagent_row.add_child(Look.label("REAGENTS",11,Look.ASH,700))
		for code in Catalog.REAGENTS:
			var n: int = runner.count_of(int(Catalog.REAGENTS[code][0])) if runner else 0
			var tag := PanelContainer.new()
			tag.add_theme_stylebox_override("panel",Look.box(Color(0.85,0.35,0.29,0.16) if n == 0 else Color(1,1,1,0.04),Look.BLOOD if n == 0 else Color(0.84,0.7,0.43,0.2),6,1,5))
			tag.tooltip_text = Catalog.REAGENTS[code][1]
			tag.add_child(Look.label("%s %d" % [code,n],12,Color("f6c9c3") if n == 0 else Color("dcd5c5"),600))
			reagent_row.add_child(tag)
		for c in 8:
			var b := chip(["I","II","III","IV","V","VI","VII","VIII"][c],circle == c+1)
			b.custom_minimum_size = Vector2(52,0)
			b.add_theme_font_override("font",Look.title_font())
			b.pressed.connect(func():
				circle = c+1
				chosen = ""
				refresh())
			circle_row.add_child(b)
	var spells := _spells()
	if chosen == "" and not spells.is_empty(): chosen = spells[0].name
	for spell in spells: grid.add_child(_card(spell))
	var selected: Dictionary = Catalog.spell(chosen)
	if not selected.is_empty(): _detail(selected)

func _card(spell: Dictionary) -> Control:
	var missing := _missing(spell)
	var step := {"action":"Cast Spell","option":spell.name}
	var card := Button.new()
	card.custom_minimum_size = Vector2(290,58)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.toggle_mode = true
	card.button_pressed = spell.name == chosen
	card.focus_mode = Control.FOCUS_NONE
	var edge := Look.BRASS if spell.name == chosen else (Color(0.85,0.35,0.29,0.6) if not missing.is_empty() else Color(0.84,0.7,0.43,0.2))
	for state in ["normal","hover","pressed"]: card.add_theme_stylebox_override(state,Look.box(Color(0.84,0.7,0.43,0.14) if spell.name == chosen else Color(1,1,1,0.03),edge,10,1,8))
	card.pressed.connect(func():
		chosen = spell.name
		refresh())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,Control.PRESET_MODE_MINSIZE,8)
	card.add_child(row)
	var handle := preload("res://Network/DragHandle.gd").new()
	handle.payload = {"quickbar_slot":{"steps":[step],"aim":"cursor"}}
	handle.picture = Look.icon(Catalog.icon_for(step),Look.IVORY,32)
	handle.tooltip_text = "Drag onto the quickbar"
	row.add_child(handle)
	var icon := TextureRect.new()
	icon.texture = Look.icon(Catalog.icon_for(step),Look.DIM if not missing.is_empty() else Color("8fb8ff"),26)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation",0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name_line := Look.label(spell.name,15,Look.IVORY,600)
	name_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(name_line)
	var note := "Missing "+", ".join(missing) if not missing.is_empty() else (" · ".join(spell.reagents.map(func(r): return Catalog.REAGENTS[r][1])) if not spell.reagents.is_empty() else "")
	var note_line := Look.label(note,12,Color("f0a39a") if not missing.is_empty() else Look.ASH,500)
	note_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	note_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(note_line)
	if int(spell.mana) > 0:
		var mana := Look.label("%d mana" % int(spell.mana),12,Color("8fb8ff"),600)
		mana.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mana)
	return card

func _detail(spell: Dictionary) -> void:
	var step := {"action":"Cast Spell","option":spell.name}
	var missing := _missing(spell)
	var title := Label.new()
	title.text = spell.name
	title.add_theme_font_override("font",Look.title_font())
	title.add_theme_font_size_override("font_size",22)
	title.add_theme_color_override("font_color",Color("f3ebd9"))
	detail.add_child(title)
	if spell.has("words"): detail.add_child(Look.label(spell.words,14,Look.GOLD,500))
	var facts := []
	if int(spell.circle) > 0: facts.append("Circle %d" % int(spell.circle))
	if int(spell.mana) > 0: facts.append("%d mana" % int(spell.mana))
	facts.append("Spell %d" % int(spell.id))
	detail.add_child(Look.label(" · ".join(facts),13,Look.ASH,500))
	if not spell.reagents.is_empty():
		detail.add_child(Look.label("REAGENTS",11,Look.ASH,700))
		for code in spell.reagents:
			var n: int = runner.count_of(int(Catalog.REAGENTS[code][0]))
			var line := HBoxContainer.new()
			var name := Look.label(Catalog.REAGENTS[code][1],14,Look.IVORY,500)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(name)
			line.add_child(Look.label("%d in pack" % n,14,Look.HERB if n > 0 else Color("f0a39a"),600))
			detail.add_child(line)
	if not missing.is_empty():
		var warn := Look.label("Missing %s. Reagent shops sell it." % ", ".join(missing),13,Color("f6c9c3"),500)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(warn)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(spacer)
	var cast := Button.new()
	cast.text = "Cast"
	cast.custom_minimum_size = Vector2(0,42)
	cast.disabled = not missing.is_empty()
	cast.add_theme_stylebox_override("normal",Look.box(Look.BRASS,Look.BRASS,8,1,8))
	cast.add_theme_color_override("font_color",Color("14110b"))
	cast.pressed.connect(func(): runner.run([step],"cursor"))
	detail.add_child(cast)
	var add := Button.new()
	add.text = "Add to quickbar"
	add.custom_minimum_size = Vector2(0,38)
	add.pressed.connect(func(): add_requested.emit({"steps":[step],"aim":"cursor"}))
	detail.add_child(add)

signal add_requested(slot: Dictionary)
