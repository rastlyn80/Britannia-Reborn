extends Control
# Speech over the speaker's head, as in the original client: every line a
# character or NPC says (0x1C, 0xAE, 0xC1, 0xCC) floats above its name in the
# speech colour, newest nearest the head, and fades after a time that grows
# with its length. Emotes read *like this*. System messages and single-click
# labels stay in the journal only. Speakers beyond view range (18 tiles) or
# off screen are not drawn; the journal keeps everything.
const Look = preload("res://Network/ModernSkin.gd")
const Artwork = preload("res://Network/Artwork.gd")
const RANGE := 18
const WIDTH := 260.0
const MAX_LINES := 4
const FADE := 0.6
# Each speaker's own soft tone (by serial), so voices are told apart without
# shouting: muted ivory, gold, sky, sage, rose, lavender, sand, teal.
const VOICES := [Color("eee4cf"),Color("e6d29c"),Color("b8cfe6"),Color("bcd9b0"),Color("e3bcb4"),Color("cfc1e3"),Color("e4c7a0"),Color("acd8d2")]
var scene: Node3D
var game: Node
# serial -> [{label, until}], oldest first.
var lines := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(world_scene: Node3D) -> void:
	scene = world_scene
	game = scene.game
	game.speech_received.connect(say)
	game.ended.connect(clear)

func clear() -> void:
	for serial in lines.keys(): _drop(serial)

# The speaker's colour: yourself in plain ivory; a colour the server gives
# (not the default 0x3B2) kept but softened; otherwise the speaker's tone.
static func voice(serial: int, hue: int, own := false) -> Color:
	if own: return Look.IVORY
	if hue > 0 and hue != 0x3b2:
		var given: Color = Artwork.color(hue,Look.IVORY).lerp(Look.IVORY,0.3)
		return given.lightened(0.4) if given.get_luminance() < 0.3 else given
	return VOICES[absi(hash(serial))%VOICES.size()]

# Seconds a line stays: longer lines longer, as ClassicUO's text timing.
static func lifetime(text: String) -> float:
	return clampf(3.5+text.length()*0.06,3.5,10.0)

func say(serial: int, text: String, type: int, hue: int) -> void:
	# 1 system, 6 single-click label, 7 focus: journal only.
	if type in [1,6,7] or serial == 0 or serial == 0xffffffff or text.strip_edges().is_empty(): return
	if not (game.entities.has(serial) or serial == int(game.player.get("serial",0))): return
	var shown := "*%s*" % text if type == 2 and not text.begins_with("*") else text
	# A faint backing keeps lines readable over busy scenes.
	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_theme_stylebox_override("panel",Look.box(Color(0.03,0.035,0.045,0.55),Color(0,0,0,0),7,0,5))
	var label := Label.new()
	label.text = shown
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",Look.ui_font(600))
	label.add_theme_font_size_override("font_size",16 if type == 9 else 15)
	var colour := voice(serial,hue,serial == int(game.player.get("serial",0)))
	# Whispers are a little quieter.
	if type == 8: colour.a = 0.8
	label.add_theme_color_override("font_color",colour)
	label.add_theme_color_override("font_outline_color",Color(0.02,0.025,0.035,0.9))
	label.add_theme_constant_override("outline_size",4)
	# Short lines hug their text; long ones wrap at WIDTH.
	var natural := Look.ui_font(600).get_string_size(shown,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
	label.custom_minimum_size = Vector2(minf(natural+4.0,WIDTH),0)
	bubble.add_child(label)
	bubble.hide()
	add_child(bubble)
	if not lines.has(serial): lines[serial] = []
	lines[serial].append({"label":bubble,"until":Time.get_ticks_msec()/1000.0+lifetime(shown)})
	while lines[serial].size() > MAX_LINES: _forget(serial,0)

func _forget(serial: int, index: int) -> void:
	var entry: Dictionary = lines[serial][index]
	if is_instance_valid(entry.label): entry.label.queue_free()
	lines[serial].remove_at(index)

func _drop(serial: int) -> void:
	while lines.has(serial) and not lines[serial].is_empty(): _forget(serial,0)
	lines.erase(serial)

# The point above the name: the avatar's nameplate when it has one.
func _anchor(serial: int) -> Variant:
	var avatar: Node3D = scene.avatars.get(serial,null)
	if avatar and is_instance_valid(avatar):
		var plate := avatar.get_node_or_null("Nameplate") as Node3D
		return plate.global_position+Vector3.UP*0.12 if plate else avatar.global_position+Vector3.UP*2.2
	var mobile: Dictionary = game.player if serial == int(game.player.get("serial",0)) else game.entities.get(serial,{})
	if mobile.is_empty(): return null
	return scene.entity_point(int(mobile.x),int(mobile.y),int(mobile.z))+Vector3.UP*2.2

func _process(_delta: float) -> void:
	if lines.is_empty() or scene == null: return
	var now := Time.get_ticks_msec()/1000.0
	var camera: Camera3D = scene.camera
	var me := Vector2i(int(game.player.get("x",0)),int(game.player.get("y",0)))
	var stacks: Array = []
	for serial in lines.keys():
		var entries: Array = lines[serial]
		for i in range(entries.size()-1,-1,-1):
			if now > float(entries[i].until): _forget(serial,i)
		if entries.is_empty():
			lines.erase(serial)
			continue
		var mobile: Dictionary = game.player if serial == int(game.player.get("serial",0)) else game.entities.get(serial,{})
		var at: Variant = _anchor(serial)
		var shown: bool = at != null and not mobile.is_empty() and maxi(absi(int(mobile.x)-me.x),absi(int(mobile.y)-me.y)) <= RANGE and not camera.is_position_behind(at)
		var point := camera.unproject_position(at) if shown else Vector2.ZERO
		if shown and not get_viewport_rect().grow(40).has_point(point): shown = false
		for entry in entries: entry.label.visible = shown
		if not shown: continue
		var height := 0.0
		var width := 0.0
		for entry in entries:
			entry.label.reset_size()
			height += entry.label.size.y+3.0
			width = maxf(width,entry.label.size.x)
		# Clear of the name drawn at the anchor.
		stacks.append({"entries":entries,"rect":Rect2(point.x-width/2.0,point.y-30.0-height,width,height),"bottom":point.y-30.0})
	# Neighbouring speakers' stacks never overlap: lower ones keep their place,
	# higher ones move up past them.
	stacks.sort_custom(func(a,b): return a.rect.end.y > b.rect.end.y)
	var placed: Array = []
	for stack in stacks:
		var rect: Rect2 = stack.rect
		var moved := true
		while moved:
			moved = false
			for other in placed:
				if rect.intersects(other):
					rect.position.y = other.position.y-rect.size.y-4.0
					moved = true
		placed.append(rect)
		var bottom := rect.end.y
		var entries: Array = stack.entries
		for i in range(entries.size()-1,-1,-1):
			var bubble: Control = entries[i].label
			bubble.position = Vector2(rect.get_center().x-bubble.size.x/2.0,bottom-bubble.size.y).round()
			bottom -= bubble.size.y+3.0
			bubble.modulate.a = clampf((float(entries[i].until)-now)/FADE,0.0,1.0)
