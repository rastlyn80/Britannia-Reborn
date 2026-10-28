extends VBoxContainer
# The quickbar: rows of slots, each holding a classic macro action or a
# sequence of them (ActionCatalog), run by ActionRunner. Holding Shift, Ctrl
# or Alt swaps every row to that modifier's own set of slots, so one row of
# twelve keys reaches forty-eight actions. Everything is customizable: right-
# click a slot to edit it, drag slots to rearrange, click the layer chips to
# edit a layer without holding its key. Saved per character in user://.
signal edit_requested(row: int, layer: String, index: int)
const Look = preload("res://Network/ModernSkin.gd")
const Catalog = preload("res://Network/ActionCatalog.gd")
const Artwork = preload("res://Network/Artwork.gd")
const SLOT := 58
const LAYERS := ["","shift","ctrl","alt"]
const LAYER_NAMES := {"":"Base","shift":"Shift","ctrl":"Ctrl","alt":"Alt"}
const MOVE_KEYS := [KEY_W,KEY_A,KEY_S,KEY_D]
var runner: Node
var profile := {}
var profile_path := ""
var held_layer := ""
var pinned_layer := ""
var rows_box := VBoxContainer.new()
var chips := {}
var slots := []
var feedback_label: Label
var refresh_due := 0.0
var used_until := {}

func _ready() -> void:
	# Bottom centre of the screen, growing upward as rows are added.
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -16
	theme = Look.theme()
	add_theme_constant_override("separation",6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_label = Look.label("",13,Look.GOLD,500)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feedback_label)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",4)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(header)
	for layer in LAYERS:
		var chip := Button.new()
		chip.text = LAYER_NAMES[layer]
		chip.toggle_mode = true
		chip.focus_mode = Control.FOCUS_NONE
		chip.tooltip_text = "Hold %s to use this set. Click to show it for editing." % LAYER_NAMES[layer] if layer != "" else "The set used with no modifier held."
		chip.add_theme_font_override("font",Look.ui_font(600))
		chip.add_theme_font_size_override("font_size",12)
		chip.add_theme_stylebox_override("normal",Look.box(Look.NIGHT,Look.EDGE,8,1,4))
		chip.add_theme_stylebox_override("hover",Look.box(Look.NIGHT,Look.BRASS,8,1,4))
		chip.add_theme_stylebox_override("pressed",Look.box(Color(0.84,0.7,0.43,0.3),Look.BRASS,8,1,4))
		chip.add_theme_color_override("font_color",Look.ASH)
		chip.add_theme_color_override("font_pressed_color",Look.IVORY)
		chip.custom_minimum_size = Vector2(56,26)
		chip.pressed.connect(func():
			pinned_layer = layer if pinned_layer != layer else ""
			refresh())
		header.add_child(chip)
		chips[layer] = chip
	rows_box.add_theme_constant_override("separation",6)
	rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rows_box)

func configure(action_runner: Node) -> void:
	runner = action_runner
	runner.feedback.connect(show_feedback)
	runner.session.entered.connect(func(_position: Dictionary):
		load_profile(profile_key())
		show())
	runner.session.ended.connect(func(): hide())
	runner.session.items_changed.connect(func(): refresh_due = 0.2)
	runner.session.status_changed.connect(func(_status: Dictionary): refresh_due = 0.2)
	hide()

func profile_key() -> String:
	var account := str(runner.session.username) if runner and runner.session else ""
	var serial := int(runner.session.player.get("serial",0)) if runner and runner.session else 0
	return ("%s-%d" % [account,serial]).validate_filename() if serial != 0 else "default"

# --- Profile -----------------------------------------------------------------

static func step(action: String, option := "", extra := {}) -> Dictionary:
	return {"action":action,"option":option}.merged(extra)

static func slot(steps: Array, aim := "cursor") -> Dictionary:
	return {"steps":steps,"aim":aim}

# A useful first set; every slot can be changed.
static func default_profile() -> Dictionary:
	var keys := ["1","2","3","4","5","6","7","8","9","0","Minus","Equal"]
	var base := [slot([step("Bandage Self")]),slot([step("Attack Last")]),slot([step("Cast Spell","Greater Heal")]),slot([step("Cast Spell","Lightning")]),
		slot([step("Use Potion","Heal")]),slot([step("Use Potion","Cure")]),slot([step("Use Potion","Refresh")]),slot([step("War/Peace")]),
		slot([step("Use Skill","Hiding")]),slot([step("Use Skill","Meditation")]),slot([step("Open","Backpack")]),slot([step("Last Target")])]
	var shift := [slot([step("Cast Spell","Heal")],"self"),slot([step("Cast Spell","Cure")],"self"),slot([step("Cast Spell","Greater Heal")],"self"),slot([step("Cast Spell","Arch Cure")],"self"),
		slot([step("Cast Spell","Bless")],"self"),slot([step("Cast Spell","Protection")]),slot([step("Cast Spell","Magic Reflection")]),slot([step("Cast Spell","Night Sight")],"self")]
	var ctrl := [slot([step("Select Nearest","Hostile")]),slot([step("Select Next","Hostile")]),slot([step("Attack Selected Target")]),slot([step("Primary Ability")]),
		slot([step("Secondary Ability")]),slot([step("Arm/Disarm","Right Hand")]),slot([step("Cast Spell","Fireball")],"last"),slot([step("Cast Spell","Energy Bolt")],"last")]
	var alt := [slot([step("Cast Spell","Recall")]),slot([step("Cast Spell","Mark")]),slot([step("Cast Spell","Gate Travel")]),slot([step("Open","Mage Spellbook")]),
		slot([step("Open","Paperdoll")]),slot([step("Open","Skills")]),slot([step("Bow")]),slot([step("Salute")]),slot([step("All Names")]),slot([step("Open Door")])]
	var bars := {"0":{"":_indexed(base),"shift":_indexed(shift),"ctrl":_indexed(ctrl),"alt":_indexed(alt)},"1":{"":{},"shift":{},"ctrl":{},"alt":{}}}
	return {"version":1,"rows":2,"slots":12,"keys":[keys,["","","","","","","","","","","",""]],"bars":bars}

static func _indexed(list: Array) -> Dictionary:
	var result := {}
	for i in list.size(): result[str(i)] = list[i]
	return result

func load_profile(key: String) -> void:
	profile_path = "user://quickbar/%s.json" % key
	profile = {}
	if FileAccess.file_exists(profile_path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
		if data is Dictionary and int(data.get("version",0)) == 1: profile = data
	if profile.is_empty(): profile = default_profile()
	rebuild()

func save_profile() -> void:
	if profile_path == "": return
	DirAccess.make_dir_recursive_absolute("user://quickbar")
	var file := FileAccess.open(profile_path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(profile,"\t"))

func slot_at(row: int, layer: String, index: int) -> Dictionary:
	return profile.get("bars",{}).get(str(row),{}).get(layer,{}).get(str(index),{})

func set_slot(row: int, layer: String, index: int, value: Dictionary) -> void:
	var bars: Dictionary = profile.get_or_add("bars",{})
	var bar: Dictionary = bars.get_or_add(str(row),{})
	var layer_slots: Dictionary = bar.get_or_add(layer,{})
	if value.is_empty(): layer_slots.erase(str(index))
	else: layer_slots[str(index)] = value
	save_profile()
	refresh()

func key_of(row: int, index: int) -> String:
	var keys: Array = profile.get("keys",[])
	return str(keys[row][index]) if row < keys.size() and index < keys[row].size() else ""

func set_key(row: int, index: int, key: String) -> void:
	var keys: Array = profile.get_or_add("keys",[])
	while keys.size() <= row: keys.append([])
	while keys[row].size() < int(profile.get("slots",12)): keys[row].append("")
	# One key, one slot: free it wherever else it was bound.
	for r in keys.size():
		for i in keys[r].size():
			if key != "" and str(keys[r][i]) == key: keys[r][i] = ""
	keys[row][index] = key
	save_profile()
	rebuild()

# --- View ----------------------------------------------------------------------

func rebuild() -> void:
	for child in rows_box.get_children(): child.queue_free()
	slots.clear()
	for row in int(profile.get("rows",2)):
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel",Look.box(Look.NIGHT,Look.EDGE,12,1,6))
		frame.mouse_filter = Control.MOUSE_FILTER_PASS
		rows_box.add_child(frame)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation",6)
		frame.add_child(line)
		for index in int(profile.get("slots",12)):
			var button := preload("res://Network/QuickbarSlot.gd").new()
			button.bar = self
			button.row = row
			button.index = index
			button.custom_minimum_size = Vector2(SLOT,SLOT)
			line.add_child(button)
			slots.append(button)
	refresh()

func visible_layer() -> String:
	return pinned_layer if pinned_layer != "" else held_layer

func refresh() -> void:
	var layer := visible_layer()
	for button in slots: button.show_slot(slot_at(button.row,layer,button.index),key_of(button.row,button.index),layer)
	for name in chips: chips[name].set_pressed_no_signal(name == layer)

func _process(delta: float) -> void:
	if not visible: return
	var layer := ""
	if Input.is_key_pressed(KEY_CTRL): layer = "ctrl"
	elif Input.is_key_pressed(KEY_ALT): layer = "alt"
	elif Input.is_key_pressed(KEY_SHIFT):
		# Shift is also run: keep the base set on screen while walking.
		var moving := false
		for key in MOVE_KEYS: moving = moving or Input.is_physical_key_pressed(key)
		layer = "" if moving else "shift"
	if layer != held_layer:
		held_layer = layer
		refresh()
	if refresh_due > 0.0:
		refresh_due -= delta
		if refresh_due <= 0.0: refresh()

static func layer_of(event: InputEventKey) -> String:
	if event.ctrl_pressed: return "ctrl"
	if event.alt_pressed: return "alt"
	if event.shift_pressed: return "shift"
	return ""

static func key_name(event: InputEventKey) -> String:
	var code := event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	return OS.get_keycode_string(code)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	var name := key_name(event)
	if name == "": return
	for row in int(profile.get("rows",2)):
		for index in int(profile.get("slots",12)):
			if key_of(row,index) == name:
				get_viewport().set_input_as_handled()
				use(row,layer_of(event),index)
				return

func use(row: int, layer: String, index: int) -> void:
	var value := slot_at(row,layer,index)
	if value.is_empty():
		show_feedback("Empty slot. Right-click it to choose what it does.")
		return
	used_until["%d/%s/%d" % [row,layer,index]] = Time.get_ticks_msec()+350
	refresh()
	get_tree().create_timer(0.36).timeout.connect(refresh)
	runner.run(value.get("steps",[]),str(value.get("aim","cursor")))

func flashing(row: int, layer: String, index: int) -> bool:
	return Time.get_ticks_msec() < int(used_until.get("%d/%s/%d" % [row,layer,index],0))

func show_feedback(text: String) -> void:
	feedback_label.text = text
	var shown := text
	get_tree().create_timer(4.0).timeout.connect(func():
		if feedback_label.text == shown: feedback_label.text = "")

# Move or swap slots (drag and drop within the bar).
func move_slot(from: Array, to: Array) -> void:
	var a := slot_at(int(from[0]),str(from[1]),int(from[2]))
	var b := slot_at(int(to[0]),str(to[1]),int(to[2]))
	set_slot(int(to[0]),str(to[1]),int(to[2]),a)
	set_slot(int(from[0]),str(from[1]),int(from[2]),b)
