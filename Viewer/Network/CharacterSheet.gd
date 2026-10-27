extends Control
# Character sheet (C) and skills (K) for the player's own ModernUO character.
# Everything shown comes from native status/skill packets; locks and skill use
# are sent back to the server, which stays authoritative.
const UiLook = preload("res://Network/UiSkin.gd")
const Character = preload("res://Network/CharacterProtocol.gd")
const SIZE := Vector2(640,690)
const LOCK_GLYPHS := ["▲","▼","■"]
const LOCK_COLORS := [Color("2f7a2c"),Color("9c2a1f"),Color("5e5243")]
const LOCK_NAMES := ["raise","lower","locked"]
var session: Node
var title := Label.new()
var pages := {}
var tab_buttons := {}
var page := "character"
var values := {}
var meters := {}
var stat_locks := {}
var skills_list := VBoxContainer.new()
var skill_rows := {}
var skills_total := Label.new()
var filter := LineEdit.new()
var collapsed := {}
var portrait_avatar: Node3D
var portrait_view: SubViewport
var seal: TextureRect

func configure(game: Node) -> void:
	session = game
	session.status_changed.connect(func(_status: Dictionary): refresh_status())
	session.skills_changed.connect(func(_skills: Dictionary): refresh_skills())
	session.ended.connect(func(): hide())

func _ready() -> void:
	theme = UiLook.theme()
	size = SIZE
	custom_minimum_size = SIZE
	position = Vector2(300,36)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := UiLook.background()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var drag := preload("res://Network/WindowDrag.gd").new()
	drag.target = self
	drag.position = Vector2(20,UiLook.BAR_TOP)
	drag.size = Vector2(SIZE.x-80,UiLook.BAR_HEIGHT)
	add_child(drag)
	title.add_theme_font_override("font",UiLook.heading_font())
	title.add_theme_font_size_override("font_size",26)
	title.add_theme_color_override("font_color",UiLook.TITLE)
	title.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	title.add_theme_constant_override("shadow_offset_y",2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(60,UiLook.BAR_TOP)
	title.size = Vector2(SIZE.x-120,UiLook.BAR_HEIGHT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.tooltip_text = "Close (Esc)"
	close.flat = true
	close.add_theme_color_override("font_color",UiLook.TITLE)
	close.add_theme_color_override("font_hover_color",Color.WHITE)
	close.position = Vector2(SIZE.x-78,UiLook.BAR_TOP+5)
	close.size = Vector2(32,32)
	close.pressed.connect(hide)
	add_child(close)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left",int(UiLook.CONTENT_MARGINS.x))
	margins.add_theme_constant_override("margin_top",int(UiLook.CONTENT_MARGINS.y)-16)
	margins.add_theme_constant_override("margin_right",int(UiLook.CONTENT_MARGINS.z))
	margins.add_theme_constant_override("margin_bottom",int(UiLook.CONTENT_MARGINS.w))
	add_child(margins)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",8)
	margins.add_child(content)
	var tabs := HBoxContainer.new()
	content.add_child(tabs)
	for key in ["character","skills"]:
		var tab := Button.new()
		tab.text = "Character  (C)" if key == "character" else "Skills  (K)"
		tab.toggle_mode = true
		tab.pressed.connect(show_page.bind(key))
		tabs.add_child(tab)
		tab_buttons[key] = tab
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	skills_total.add_theme_color_override("font_color",UiLook.FADED_INK)
	tabs.add_child(skills_total)
	content.add_child(HSeparator.new())
	pages.character = _character_page()
	pages.skills = _skills_page()
	for key in pages:
		pages[key].size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(pages[key])
	if UiLook.texture("WaxSeal"):
		seal = TextureRect.new()
		seal.texture = UiLook.texture("WaxSeal")
		seal.position = Vector2(SIZE.x-104,SIZE.y-112)
		seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(seal)
	show_page("character")
	hide()

# Toggle this page: open on it, switch to it, or close if already showing.
func toggle(key: String) -> void:
	if visible and page == key:
		hide()
		return
	show_page(key)
	show()
	move_to_front()
	if session: session.request_character()

func show_page(key: String) -> void:
	page = key
	for name in pages:
		pages[name].visible = name == key
		tab_buttons[name].button_pressed = name == key
	title.text = "Skills" if key == "skills" else str(session.player_status.get("name","Character")) if session else "Character"
	if seal: seal.visible = key == "character"
	if portrait_view: portrait_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE

func _heading(text: String, size: int = 21) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font",UiLook.heading_font())
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("5a2a12"))
	return label

func _value(key: String, align := HORIZONTAL_ALIGNMENT_RIGHT) -> Label:
	var label := Label.new()
	label.text = "–"
	label.horizontal_alignment = align
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values[key] = label
	return label

func _row(grid: GridContainer, name: String, key: String, tooltip := "") -> void:
	var label := Label.new()
	label.text = name
	label.add_theme_color_override("font_color",UiLook.FADED_INK)
	label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_child(label)
	grid.add_child(_value(key))

func _character_page() -> Control:
	var page_root := HBoxContainer.new()
	page_root.add_theme_constant_override("separation",22)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(200,0)
	page_root.add_child(left)
	var frame := PanelContainer.new()
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.18,0.13,0.09,0.85)
	border.border_color = Color("4a3020")
	border.set_border_width_all(3)
	border.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel",border)
	left.add_child(frame)
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.custom_minimum_size = Vector2(194,268)
	frame.add_child(holder)
	portrait_view = SubViewport.new()
	portrait_view.own_world_3d = true
	portrait_view.transparent_bg = true
	portrait_view.msaa_3d = Viewport.MSAA_4X
	portrait_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	holder.add_child(portrait_view)
	_build_portrait(portrait_view)
	var name_label := _value("name",HORIZONTAL_ALIGNMENT_CENTER)
	name_label.add_theme_font_override("font",UiLook.heading_font())
	name_label.add_theme_font_size_override("font_size",24)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(name_label)
	var who := _value("who",HORIZONTAL_ALIGNMENT_CENTER)
	who.add_theme_color_override("font_color",UiLook.FADED_INK)
	left.add_child(who)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",4)
	page_root.add_child(right)
	right.add_child(_heading("Attributes"))
	var stats := GridContainer.new()
	stats.columns = 3
	stats.add_theme_constant_override("h_separation",10)
	right.add_child(stats)
	for entry in [["Strength","str",0],["Dexterity","dex",1],["Intelligence","int",2]]:
		var label := Label.new()
		label.text = entry[0]
		label.add_theme_color_override("font_color",UiLook.FADED_INK)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(label)
		var value := _value(entry[1])
		value.add_theme_font_size_override("font_size",18)
		stats.add_child(value)
		var lock := Button.new()
		lock.flat = true
		lock.custom_minimum_size = Vector2(28,0)
		lock.pressed.connect(func():
			var next := (int(stat_locks.get(entry[1],0))+1)%3
			if session.set_stat_lock(int(entry[2]),next):
				stat_locks[entry[1]] = next
				_paint_lock(lock,next))
		stats.add_child(lock)
		stat_locks[entry[1]+"_button"] = lock
		_paint_lock(lock,0)
	var cap := _value("stat_total")
	cap.add_theme_color_override("font_color",UiLook.FADED_INK)
	right.add_child(cap)
	right.add_child(_heading("Vitality"))
	for entry in [["Hits","hits",Color("a3261d")],["Stamina","stam",Color("b08a1c")],["Mana","mana",Color("2a59a8")]]:
		var line := HBoxContainer.new()
		var label := Label.new()
		label.text = entry[0]
		label.custom_minimum_size = Vector2(76,0)
		label.add_theme_color_override("font_color",UiLook.FADED_INK)
		line.add_child(label)
		var bar := UiLook.meter(entry[2])
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(bar)
		meters[entry[1]] = bar
		var amount := _value(entry[1]+"_text")
		amount.size_flags_horizontal = Control.SIZE_FILL
		amount.custom_minimum_size = Vector2(74,0)
		line.add_child(amount)
		right.add_child(line)
	right.add_child(_heading("Resistances"))
	var resist := GridContainer.new()
	resist.columns = 5
	resist.add_theme_constant_override("h_separation",14)
	right.add_child(resist)
	for entry in [["Physical","armor","6b5a48"],["Fire","fire","b2421b"],["Cold","cold","2f6f9e"],["Poison","poison","3f7f2a"],["Energy","energy","7a3fa0"]]:
		var label := Label.new()
		label.text = entry[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",12)
		label.add_theme_color_override("font_color",Color(entry[2]))
		resist.add_child(label)
	for entry in ["armor","fire","cold","poison","energy"]:
		var value := _value(entry,HORIZONTAL_ALIGNMENT_CENTER)
		value.add_theme_font_size_override("font_size",18)
		resist.add_child(value)
	right.add_child(_heading("Belongings & Fortune"))
	var other := GridContainer.new()
	other.columns = 4
	other.add_theme_constant_override("h_separation",12)
	right.add_child(other)
	_row(other,"Gold","gold")
	_row(other,"Luck","luck")
	_row(other,"Damage","damage","Weapon damage range")
	_row(other,"Followers","followers","Current / maximum pets and summons")
	_row(other,"Tithing","tithing","Tithing points for Chivalry")
	_row(other,"Stat cap","stat_cap")
	var weight_line := HBoxContainer.new()
	var weight_label := Label.new()
	weight_label.text = "Weight"
	weight_label.custom_minimum_size = Vector2(76,0)
	weight_label.add_theme_color_override("font_color",UiLook.FADED_INK)
	weight_line.add_child(weight_label)
	var weight_bar := UiLook.meter(Color("6d5a3e"))
	weight_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weight_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meters.weight = weight_bar
	weight_line.add_child(weight_bar)
	var weight_text := _value("weight_text")
	weight_text.size_flags_horizontal = Control.SIZE_FILL
	weight_text.custom_minimum_size = Vector2(74,0)
	weight_line.add_child(weight_text)
	right.add_child(weight_line)
	return page_root

func _build_portrait(view: SubViewport) -> void:
	var stage := Node3D.new()
	view.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d9c7a8")
	environment.environment.ambient_light_energy = 0.55
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28,-35,0)
	key.light_energy = 1.25
	key.light_color = Color("ffe6c4")
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15,150,0)
	rim.light_energy = 0.8
	rim.light_color = Color("a8c4ff")
	stage.add_child(rim)
	portrait_avatar = preload("res://Presentation/Avatar.gd").new()
	portrait_avatar.rotation.y = 0.35
	stage.add_child(portrait_avatar)
	var camera := Camera3D.new()
	camera.fov = 32
	stage.add_child(camera)
	camera.transform = Transform3D(Basis.looking_at(Vector3(0,0.98,0)-Vector3(0,1.15,3.6)),Vector3(0,1.15,3.6))

func _process(delta: float) -> void:
	if visible and portrait_avatar and page == "character":
		portrait_avatar.rotation.y = 0.35+sin(Time.get_ticks_msec()/2600.0)*0.45

func _paint_lock(button: Button, lock: int) -> void:
	button.text = LOCK_GLYPHS[lock]
	button.tooltip_text = "Gain: %s (click to change)" % LOCK_NAMES[lock]
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state,LOCK_COLORS[lock])

func refresh_status() -> void:
	if not session: return
	var s: Dictionary = session.player_status
	if s.is_empty(): return
	values.name.text = str(s.get("name",""))
	if page == "character": title.text = str(s.get("name","Character"))
	var race: String = ["","Human","Elf","Gargoyle"][clampi(int(s.get("race",1)),0,3)] if s.has("race") else "Human"
	values.who.text = ("Female " if s.get("female",false) else "Male ")+race.to_lower()+" of Britannia"
	for key in ["str","dex","int","armor","fire","cold","poison","energy","luck"]:
		if s.has(key): values[key].text = str(s[key])
	for key in ["hits","stam","mana"]:
		var maximum := int(s.get(key+"_max",0))
		meters[key].max_value = maxi(1,maximum)
		meters[key].value = int(s.get(key,0))
		values[key+"_text"].text = "%d / %d" % [int(s.get(key,0)),maximum]
	values.gold.text = _thousands(int(s.get("gold",0)))
	values.damage.text = "%d – %d" % [int(s.get("damage_min",0)),int(s.get("damage_max",0))] if s.has("damage_min") else "–"
	values.followers.text = "%d / %d" % [int(s.get("followers",0)),int(s.get("followers_max",0))]
	values.tithing.text = str(s.get("tithing","–"))
	values.stat_cap.text = str(s.get("stat_cap","–"))
	var total := int(s.get("str",0))+int(s.get("dex",0))+int(s.get("int",0))
	values.stat_total.text = "Total %d / %d" % [total,int(s.get("stat_cap",225))]
	var weight_max := int(s.get("weight_max",0))
	meters.weight.max_value = maxi(1,weight_max)
	meters.weight.value = int(s.get("weight",0))
	values.weight_text.text = "%d / %d" % [int(s.get("weight",0)),weight_max] if weight_max > 0 else str(s.get("weight",0))
	var locks: Dictionary = s.get("locks",{})
	for key in ["str","dex","int"]:
		if locks.has(key):
			stat_locks[key] = int(locks[key])
			_paint_lock(stat_locks[key+"_button"],int(locks[key]))

static func _thousands(value: int) -> String:
	var text := str(absi(value))
	var out := ""
	while text.length() > 3:
		out = ","+text.substr(text.length()-3)+out
		text = text.substr(0,text.length()-3)
	return ("-" if value < 0 else "")+text+out

func _skills_page() -> Control:
	var page_root := VBoxContainer.new()
	var tools := HBoxContainer.new()
	page_root.add_child(tools)
	filter.placeholder_text = "Find a skill…"
	filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter.text_changed.connect(func(_text: String): _apply_filter())
	tools.add_child(filter)
	var legend := Label.new()
	legend.text = "▲ raise   ▼ lower   ■ locked"
	legend.add_theme_font_size_override("font_size",12)
	legend.add_theme_color_override("font_color",UiLook.FADED_INK)
	tools.add_child(legend)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_root.add_child(scroll)
	skills_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_list.add_theme_constant_override("separation",1)
	scroll.add_child(skills_list)
	for group in Character.GROUPS:
		var header := Button.new()
		header.flat = true
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.add_theme_font_override("font",UiLook.heading_font())
		header.add_theme_font_size_override("font_size",20)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			header.add_theme_color_override(state,Color("5a2a12"))
		header.set_meta("group",group[0])
		header.pressed.connect(func():
			collapsed[group[0]] = not collapsed.get(group[0],false)
			_apply_filter())
		skills_list.add_child(header)
		var names: Array = group[1].duplicate()
		names.sort_custom(func(a: int,b: int): return Character.SKILLS[a] < Character.SKILLS[b])
		for id in names:
			var row := HBoxContainer.new()
			row.set_meta("group",group[0])
			row.set_meta("skill",id)
			var use := Button.new()
			use.custom_minimum_size = Vector2(46,0)
			use.add_theme_font_size_override("font_size",12)
			if Character.USABLE.has(id):
				use.text = "Use"
				use.tooltip_text = "Use "+Character.SKILLS[id]
				use.pressed.connect(func(): session.use_skill(id))
			else:
				use.modulate = Color(1,1,1,0)
				use.disabled = true
			row.add_child(use)
			var label := Label.new()
			label.text = Character.SKILLS[id]
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var value := Label.new()
			value.custom_minimum_size = Vector2(118,0)
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(value)
			var lock := Button.new()
			lock.flat = true
			lock.custom_minimum_size = Vector2(30,0)
			lock.pressed.connect(func():
				if not session.skills.has(id): return
				session.set_skill_lock(id,(int(session.skills[id].lock)+1)%3))
			row.add_child(lock)
			skills_list.add_child(row)
			skill_rows[id] = {"row":row,"value":value,"lock":lock,"label":label}
	_apply_filter()
	return page_root

func refresh_skills() -> void:
	if not session: return
	var total := 0.0
	for id in skill_rows:
		var parts: Dictionary = skill_rows[id]
		var skill: Dictionary = session.skills.get(id,{})
		if skill.is_empty():
			parts.value.text = "–"
			continue
		total += float(skill.base)
		parts.value.text = "%.1f" % float(skill.value)+("  (%.1f)" % float(skill.base) if not is_equal_approx(float(skill.value),float(skill.base)) else "")
		parts.value.tooltip_text = "Value %.1f · base %.1f · cap %.1f" % [float(skill.value),float(skill.base),float(skill.cap)]
		parts.value.mouse_filter = Control.MOUSE_FILTER_PASS
		parts.label.add_theme_color_override("font_color",UiLook.INK if float(skill.base) > 0 else UiLook.FADED_INK)
		_paint_lock(parts.lock,int(skill.lock))
	skills_total.text = "Skill total %.1f" % total if not session.skills.is_empty() else ""
	_apply_filter()

func _apply_filter() -> void:
	var query := filter.text.strip_edges().to_lower()
	var shown := {}
	for child in skills_list.get_children():
		if child.has_meta("skill"):
			var id: int = child.get_meta("skill")
			var matches: bool = query.is_empty() or query in Character.SKILLS[id].to_lower()
			child.visible = matches and (not query.is_empty() or not collapsed.get(child.get_meta("group"),false))
			if matches: shown[child.get_meta("group")] = true
	for child in skills_list.get_children():
		if not child.has_meta("skill"):
			var group: String = child.get_meta("group")
			child.visible = shown.has(group)
			child.text = ("▸ " if collapsed.get(group,false) and query.is_empty() else "▾ ")+group

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not filter.has_focus():
		hide()
		get_viewport().set_input_as_handled()
