extends CanvasLayer
# Splitting a stack, as in the original client: dropping a stack asks how many
# to move (the whole stack offered; Enter confirms, Escape cancels). Holding
# Shift while dropping moves the whole stack without asking.
#   AmountPrompt.ask(control, item, "Arrows", func(amount: int): ...)
const Look = preload("res://Network/ModernSkin.gd")
signal chosen(amount: int)
var total := 1
var spin: SpinBox
var slider: HSlider
var answered := false

static func ask(host: Node, item: Dictionary, name: String, then: Callable) -> void:
	var amount := int(item.get("amount",1))
	if amount <= 1 or Input.is_key_pressed(KEY_SHIFT):
		then.call(amount)
		return
	# One question at a time.
	for node in host.get_tree().root.get_children():
		if node.has_meta("amount_prompt"): node.queue_free()
	var prompt := new()
	prompt.set_meta("amount_prompt",true)
	prompt.total = amount
	prompt.chosen.connect(then)
	host.get_tree().root.add_child(prompt)
	prompt.build(name,host.get_viewport().get_mouse_position())

func build(name: String, at: Vector2) -> void:
	layer = 90
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",Look.box(Color(0.045,0.05,0.065,0.97),Look.BRASS,10,1,12))
	panel.custom_minimum_size = Vector2(300,0)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	column.add_child(Look.label("How many %s?" % name if name != "" else "How many?",15,Look.IVORY,600))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	column.add_child(row)
	slider = HSlider.new()
	slider.min_value = 1
	slider.max_value = total
	slider.value = total
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	spin = SpinBox.new()
	spin.min_value = 1
	spin.max_value = total
	spin.value = total
	spin.custom_minimum_size = Vector2(96,0)
	row.add_child(spin)
	slider.value_changed.connect(func(value: float): spin.set_value_no_signal(value))
	spin.value_changed.connect(func(value: float): slider.set_value_no_signal(value))
	spin.get_line_edit().text_submitted.connect(func(_t: String): confirm())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",8)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	for entry in [["Half",func(): _choose(maxi(1,total/2))],["All",func(): _choose(total)],["Cancel",func(): queue_free()],["Move",confirm]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		buttons.add_child(button)
	await get_tree().process_frame
	var screen := panel.get_viewport_rect().size
	panel.position = (at+Vector2(12,12)).clamp(Vector2(8,8),screen-panel.size-Vector2(8,8))
	var line := spin.get_line_edit()
	line.grab_focus()
	line.select_all()

func _choose(value: int) -> void:
	spin.value = value
	spin.get_line_edit().select_all()

func confirm() -> void:
	if answered: return
	answered = true
	# The typed number counts even if Enter came before the box applied it.
	var typed := spin.get_line_edit().text.strip_edges()
	var amount := clampi(int(typed) if typed.is_valid_int() else int(spin.value),1,total)
	chosen.emit(amount)
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			queue_free()
		elif event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
			get_viewport().set_input_as_handled()
			confirm()
