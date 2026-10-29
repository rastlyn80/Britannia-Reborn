extends PanelContainer
# Edits one quickbar slot: a single classic macro action or a sequence of
# steps (the classic macro editor), how it targets, its label and its key.
const Look = preload("res://Network/ModernSkin.gd")
const Catalog = preload("res://Network/ActionCatalog.gd")
const Artwork = preload("res://Network/Artwork.gd")
const AIM_CHOICES := [["cursor","Ask with the target cursor"],["self","On myself"],["last","On my last target"],["hover","On what is under the mouse"]]
var bar: Node
var row := 0
var layer := ""
var index := 0
var steps := []
var current := -1
var capturing := false
var title := Label.new()
var step_list := ItemList.new()
var group_pick := OptionButton.new()
var action_pick := OptionButton.new()
var option_pick := OptionButton.new()
var text_field := LineEdit.new()
var item_list := ItemList.new()
var aim_pick := OptionButton.new()
var label_field := LineEdit.new()
var key_button := Button.new()
var carried_items := []

func _ready() -> void:
	preload("res://Network/Movable.gd").attach(self,"sloteditor")
	theme = Look.theme()
	add_theme_stylebox_override("panel",Look.box(Color(0.055,0.063,0.078,0.97),Look.BRASS,14,1,18))
	custom_minimum_size = Vector2(760,0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	add_child(column)
	title.add_theme_font_override("font",Look.title_font())
	title.add_theme_font_size_override("font_size",20)
	title.add_theme_color_override("font_color",Color("f3ebd9"))
	column.add_child(title)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation",16)
	column.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(260,0)
	body.add_child(left)
	left.add_child(Look.label("Steps (run in order)",12,Look.ASH,700))
	step_list.custom_minimum_size = Vector2(260,220)
	step_list.item_selected.connect(func(i: int): _select(i))
	left.add_child(step_list)
	var step_buttons := HBoxContainer.new()
	left.add_child(step_buttons)
	_button(step_buttons,"Add step",func():
		steps.append({"action":"Say","option":"","text":""})
		_list_steps(steps.size()-1))
	_button(step_buttons,"Remove",func():
		if current >= 0:
			steps.remove_at(current)
			_list_steps(mini(current,steps.size()-1)))
	_button(step_buttons,"↑",func(): _shift(-1))
	_button(step_buttons,"↓",func(): _shift(1))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",8)
	body.add_child(right)
	right.add_child(Look.label("Kind",12,Look.ASH,700))
	for group in Catalog.GROUPS: group_pick.add_item(group)
	group_pick.item_selected.connect(func(_i: int): _fill_actions(""))
	right.add_child(group_pick)
	right.add_child(Look.label("Action",12,Look.ASH,700))
	action_pick.item_selected.connect(func(_i: int): _action_changed())
	right.add_child(action_pick)
	right.add_child(Look.label("Choice",12,Look.ASH,700))
	option_pick.item_selected.connect(func(_i: int): _store())
	option_pick.fit_to_longest_item = false
	right.add_child(option_pick)
	text_field.placeholder_text = "Text, or milliseconds for Delay"
	text_field.text_changed.connect(func(_t: String): _store())
	right.add_child(text_field)
	item_list.custom_minimum_size = Vector2(0,150)
	item_list.max_columns = 6
	item_list.same_column_width = true
	item_list.icon_mode = ItemList.ICON_MODE_TOP
	item_list.fixed_icon_size = Vector2i(40,40)
	item_list.item_selected.connect(func(_i: int): _store())
	right.add_child(item_list)
	var settings := GridContainer.new()
	settings.columns = 2
	settings.add_theme_constant_override("h_separation",12)
	settings.add_theme_constant_override("v_separation",8)
	column.add_child(settings)
	settings.add_child(Look.label("Targets",13,Look.ASH,600))
	for choice in AIM_CHOICES: aim_pick.add_item(choice[1])
	settings.add_child(aim_pick)
	settings.add_child(Look.label("Label",13,Look.ASH,600))
	label_field.placeholder_text = "Optional name shown on hover"
	settings.add_child(label_field)
	settings.add_child(Look.label("Key",13,Look.ASH,600))
	key_button.tooltip_text = "Click, then press a key. Escape clears it. Shift, Ctrl and Alt pick the set, not the key."
	key_button.pressed.connect(func():
		capturing = true
		key_button.text = "Press a key…")
	settings.add_child(key_button)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation",8)
	column.add_child(actions)
	_button(actions,"Clear slot",func():
		bar.set_slot(row,layer,index,{})
		hide())
	_button(actions,"Cancel",func(): hide())
	var save := _button(actions,"Save",func(): _save())
	save.add_theme_stylebox_override("normal",Look.box(Look.BRASS,Look.BRASS,8,1,8))
	save.add_theme_color_override("font_color",Color("14110b"))
	hide()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func open(quickbar: Node, at_row: int, at_layer: String, at_index: int) -> void:
	bar = quickbar
	row = at_row
	layer = at_layer
	index = at_index
	var value: Dictionary = bar.slot_at(row,layer,index)
	steps = value.get("steps",[]).duplicate(true)
	if steps.is_empty(): steps = [{"action":"Cast Spell","option":"Greater Heal"}]
	var key: String = bar.key_of(row,index)
	title.text = "Slot %d · %s set%s" % [index+1,bar.LAYER_NAMES.get(layer,"Base"),(" · %s+%s" % [layer.capitalize(),key]) if layer != "" and key != "" else (" · key %s" % key if key != "" else "")]
	label_field.text = str(value.get("label",""))
	var aim := str(value.get("aim","cursor"))
	for i in AIM_CHOICES.size():
		if AIM_CHOICES[i][0] == aim: aim_pick.select(i)
	key_button.text = "Key: %s" % (key if key != "" else "none")
	carried_items = _carried()
	_list_steps(0)
	show()
	reset_size()
	(func():
		position = preload("res://Network/Movable.gd").place("sloteditor",(get_viewport_rect().size-size)/2.0)
		preload("res://Network/Movable.gd").keep_on_screen(self)).call_deferred()

func _carried() -> Array:
	var seen := {}
	var result := []
	if bar == null or bar.runner == null: return result
	for item in bar.runner.carried():
		var k := "%d/%d" % [int(item.id),int(item.get("hue",0))]
		if seen.has(k): continue
		seen[k] = true
		result.append(item)
	return result

func _list_steps(select: int) -> void:
	step_list.clear()
	for s in steps: step_list.add_item(Catalog.describe(s))
	if steps.is_empty():
		current = -1
		return
	step_list.select(clampi(select,0,steps.size()-1))
	_select(clampi(select,0,steps.size()-1))

func _shift(by: int) -> void:
	if current < 0 or current+by < 0 or current+by >= steps.size(): return
	var moved: Dictionary = steps[current]
	steps.remove_at(current)
	steps.insert(current+by,moved)
	_list_steps(current+by)

func _select(i: int) -> void:
	current = i
	var s: Dictionary = steps[i]
	var group := str(Catalog.action(str(s.action)).get("group","Combat"))
	group_pick.select(maxi(0,Catalog.GROUPS.find(group)))
	_fill_actions(str(s.action))

func _fill_actions(selected: String) -> void:
	action_pick.clear()
	var group: String = Catalog.GROUPS[group_pick.selected]
	var chosen := 0
	for entry in Catalog.ACTIONS:
		if entry.group != group: continue
		action_pick.add_item(entry.id)
		if entry.id == selected: chosen = action_pick.item_count-1
	action_pick.select(chosen)
	_action_changed(true)

func _action_changed(restoring := false) -> void:
	if current < 0: return
	var id := action_pick.get_item_text(action_pick.selected)
	var s: Dictionary = steps[current]
	if not restoring or str(s.action) != id: steps[current] = {"action":id,"option":"","text":""}
	s = steps[current]
	var kind: Variant = Catalog.action(id).get("options",null)
	option_pick.visible = kind != null and kind != "text" and kind != "item"
	text_field.visible = kind == "text"
	item_list.visible = kind == "item"
	option_pick.clear()
	if option_pick.visible:
		var options := Catalog.options(id)
		for o in options: option_pick.add_item(o)
		option_pick.select(maxi(0,options.find(str(s.get("option","")))))
	text_field.text = str(s.get("text",""))
	if item_list.visible:
		item_list.clear()
		for item in carried_items:
			var name: String = bar.runner.session.labels.item_name(int(item.id)) if bar.runner.session else "item"
			item_list.add_item(name.capitalize(),Artwork.item(int(item.id),int(item.get("hue",0))))
			if int(item.id) == int(s.get("graphic",-1)) or int(item.serial) == int(s.get("serial",-1)): item_list.select(item_list.item_count-1)
		if carried_items.is_empty(): item_list.add_item("Your backpack is empty or not open yet.")
	_store()

func _store() -> void:
	if current < 0: return
	var id := action_pick.get_item_text(action_pick.selected)
	var s := {"action":id}
	if option_pick.visible and option_pick.selected >= 0: s.option = option_pick.get_item_text(option_pick.selected)
	if text_field.visible: s.text = text_field.text
	if item_list.visible:
		var picked := item_list.get_selected_items()
		# Keep the chosen item when it is not in the pack right now.
		for k in ["name","serial","graphic","hue"]:
			if steps[current].has(k) and str(steps[current].action) == id: s[k] = steps[current][k]
		if not picked.is_empty() and picked[0] < carried_items.size():
			var item: Dictionary = carried_items[picked[0]]
			s.name = item_list.get_item_text(picked[0])
			if id == "Use Item": s.serial = int(item.serial)
			s.graphic = int(item.id)
			s.hue = int(item.get("hue",0))
	steps[current] = s
	step_list.set_item_text(current,Catalog.describe(s))

func _save() -> void:
	var value := {"steps":steps.duplicate(true),"aim":AIM_CHOICES[maxi(0,aim_pick.selected)][0]}
	if label_field.text.strip_edges() != "": value.label = label_field.text.strip_edges()
	bar.set_slot(row,layer,index,value)
	hide()

func _input(event: InputEvent) -> void:
	if not visible or not capturing or not event is InputEventKey or not event.pressed: return
	if event.keycode in [KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META]: return
	get_viewport().set_input_as_handled()
	capturing = false
	var name: String = "" if event.keycode == KEY_ESCAPE else bar.key_name(event)
	bar.set_key(row,index,name)
	key_button.text = "Key: %s" % (name if name != "" else "none")
