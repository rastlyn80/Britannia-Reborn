extends "res://Network/ModernWindow.gd"
# Skills (K): the server's skill list with search and groups, values against
# their caps, raise/lower/lock per skill (sent to the server), a Use button for
# usable skills, the gains of this session, and the total. Drag a row's handle
# onto the quickbar to put that skill on a slot.
const Character = preload("res://Network/CharacterProtocol.gd")
var session: Node
var search := LineEdit.new()
var group := "All"
var trained_only := true
var group_chips := {}
var rows := VBoxContainer.new()
var total_label: Label
var total_bar: ProgressBar
var first_seen := {}

func _ready() -> void:
	setup("skills","Skills",Vector2(760,620),Vector2(80,90))
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation",6)
	body.add_child(tools)
	search.placeholder_text = "Search skills"
	search.custom_minimum_size = Vector2(200,34)
	search.text_changed.connect(func(_t: String): refresh())
	tools.add_child(search)
	for name in ["All"]+Character.GROUPS.map(func(g): return g[0]):
		var c := chip(name,name == group)
		c.pressed.connect(func():
			group = name
			for other in group_chips: group_chips[other].set_pressed_no_signal(other == group)
			refresh())
		tools.add_child(c)
		group_chips[name] = c
	var totals := HBoxContainer.new()
	totals.add_theme_constant_override("separation",12)
	body.add_child(totals)
	total_bar = meter(Look.BRASS,8)
	total_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	totals.add_child(total_bar)
	total_label = Look.label("",13,Look.IVORY,600)
	totals.add_child(total_label)
	var shown := CheckBox.new()
	shown.text = "Trained only"
	shown.button_pressed = trained_only
	shown.toggled.connect(func(on: bool):
		trained_only = on
		refresh())
	totals.add_child(shown)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",2)
	scroll.add_child(rows)
	body.add_child(Look.label("Drag a skill by its handle onto any quickbar slot. Arrows: raise, lower, lock.",12,Look.ASH,500))

func configure(game: Node) -> void:
	session = game
	session.skills_changed.connect(func(_skills: Dictionary):
		for id in session.skills:
			if not first_seen.has(id): first_seen[id] = float(session.skills[id].base)
		if visible: refresh())
	session.ended.connect(func():
		first_seen.clear()
		hide())

func toggle() -> void:
	super.toggle()
	if visible:
		if session and session.skills.is_empty(): session.request_character()
		refresh()

func _in_group(id: int) -> bool:
	if group == "All": return true
	for g in Character.GROUPS:
		if g[0] == group: return id in g[1]
	return false

func refresh() -> void:
	clear(rows)
	if session == null: return
	var total := 0.0
	for id in session.skills: total += float(session.skills[id].base)
	total_label.text = "Total %.1f" % total
	total_bar.max_value = maxf(700.0,total)
	total_bar.value = total
	var query := search.text.strip_edges().to_lower()
	var ids: Array = session.skills.keys()
	ids.sort_custom(func(a,b): return Character.SKILLS[a] < Character.SKILLS[b])
	for id in ids:
		var skill: Dictionary = session.skills[id]
		var name: String = Character.SKILLS[id]
		if not _in_group(id) or (query != "" and not query in name.to_lower()): continue
		if trained_only and float(skill.base) <= 0.0 and float(skill.value) <= 0.0 and query == "": continue
		rows.add_child(_row(int(id),name,skill))
	if rows.get_child_count() == 0: rows.add_child(Look.label("No skills to show yet." if session.skills.is_empty() else "No skill matches.",14,Look.ASH))

func _row(id: int, name: String, skill: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	row.custom_minimum_size = Vector2(0,40)
	var handle := preload("res://Network/DragHandle.gd").new()
	handle.payload = {"quickbar_slot":{"steps":[{"action":"Use Skill","option":name}],"aim":"cursor"}}
	handle.tooltip_text = "Drag onto the quickbar"
	row.add_child(handle)
	var title := Look.label(name,15,Look.IVORY,600)
	title.custom_minimum_size = Vector2(190,0)
	row.add_child(title)
	var bar := meter(Look.HERB if int(skill.lock) == 0 else (Look.DIM if int(skill.lock) == 1 else Look.BRASS),8)
	bar.max_value = maxf(float(skill.cap),0.1)
	bar.value = float(skill.base)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var value := Look.label("%.1f / %.1f" % [float(skill.base),float(skill.cap)],14,Look.IVORY,600)
	value.custom_minimum_size = Vector2(104,0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.tooltip_text = "With modifiers: %.1f" % float(skill.value)
	value.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(value)
	var gain := float(skill.base)-float(first_seen.get(id,skill.base))
	var gained := Look.label("—" if absf(gain) < 0.05 else ("%+.1f" % gain),13,Look.HERB if gain > 0 else (Look.BLOOD if gain < 0 else Look.DIM),600)
	gained.custom_minimum_size = Vector2(48,0)
	gained.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gained.tooltip_text = "Change this session"
	gained.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(gained)
	var locks := HBoxContainer.new()
	locks.add_theme_constant_override("separation",0)
	row.add_child(locks)
	for lock in 3:
		var b := Button.new()
		b.icon = Look.icon(["up","down","lock"][lock],Look.IVORY if int(skill.lock) == lock else Look.DIM,16)
		b.tooltip_text = ["Raise","Lower","Lock"][lock]+" "+name
		b.custom_minimum_size = Vector2(40,32)
		b.focus_mode = Control.FOCUS_NONE
		var fill: Color = [Color(0.61,0.85,0.54,0.25),Color(0.94,0.64,0.6,0.25),Color(0.84,0.7,0.43,0.25)][lock] if int(skill.lock) == lock else Color(0,0,0,0)
		b.add_theme_stylebox_override("normal",Look.box(fill,Color(0.84,0.7,0.43,0.3),6,1,4))
		b.pressed.connect(func():
			session.set_skill_lock(id,lock)
			refresh())
		locks.add_child(b)
	var use := Button.new()
	use.text = "Use"
	use.custom_minimum_size = Vector2(64,32)
	use.disabled = not id in Character.USABLE
	use.modulate.a = 1.0 if not use.disabled else 0.0
	use.pressed.connect(func(): session.use_skill(id))
	row.add_child(use)
	return row

