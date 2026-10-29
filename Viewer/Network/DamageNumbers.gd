extends Control
# Damage the server reports (0x0B, 0xBF 0x22) rises from the creature's head
# as a number and fades: gold on others, red on you. Screen text, so it stays
# sharp at any distance (like ScreenLabels).
const Look = preload("res://Network/ModernSkin.gd")
const LIFE := 1.3
var scene: Node3D
var camera: Camera3D
var floating: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(world_scene: Node3D, view: Camera3D) -> void:
	scene = world_scene
	camera = view
	scene.game.module("combat").damaged.connect(show_damage)

func show_damage(serial: int, amount: int) -> void:
	if not scene.avatars.has(serial) or amount <= 0: return
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_font_override("font",Look.title_font())
	label.add_theme_font_size_override("font_size",32 if amount >= 20 else 26)
	var mine: bool = serial == int(scene.game.player.get("serial",0))
	label.add_theme_color_override("font_color",Color("ff6b5e") if mine else Color("ffd27a"))
	label.add_theme_color_override("font_outline_color",Color(0.05,0.03,0.02,0.95))
	label.add_theme_constant_override("outline_size",6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	# Several hits at once spread sideways instead of overlapping.
	var drift := float(floating.filter(func(entry): return entry.serial == serial).size()%3-1)*28.0
	floating.append({"label":label,"serial":serial,"born":Time.get_ticks_msec(),"drift":drift})

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for entry in floating.duplicate():
		var age := (now-int(entry.born))/1000.0
		var avatar: Node3D = scene.avatars.get(entry.serial)
		if age > LIFE or avatar == null or camera == null:
			entry.label.queue_free()
			floating.erase(entry)
			continue
		var at := avatar.global_position+Vector3.UP*(2.75+age*0.8)
		if camera.is_position_behind(at):
			entry.label.hide()
			continue
		entry.label.show()
		entry.label.reset_size()
		entry.label.pivot_offset = entry.label.size/2
		entry.label.position = camera.unproject_position(at)-entry.label.size/2+Vector2(entry.drift,0)
		entry.label.modulate.a = clampf((LIFE-age)/(LIFE*0.4),0.0,1.0)
		entry.label.scale = Vector2.ONE*(1.0+maxf(0.0,0.25-age)*1.6)
