extends HBoxContainer
# Buffs and debuffs on you (0xDF, Buffs module), under the vitals card: one
# chip each with an icon chosen from the buff's name, a ring that empties as
# its time runs out, the seconds left, and the server's title and
# description on hover. Debuffs carry a red edge, buffs a brass one.
const Look = preload("res://Network/ModernSkin.gd")
const HARMFUL := ["poison","curse","clumsy","feeblemind","weaken","paralyz","mortal","strangle","corpse skin","mind rot","evil omen","blood oath","bleed","disarm","dismount","fear","sleep","stun","hunger","pain","wither","horrific"]
const ICONS := [["poison","potion"],["heal","heal"],["cure","heal"],["protect","shield"],["armor","shield"],["reactive","shield"],["bless","star"],["strength","sword"],["agility","walk"],["cunning","rune"],["night sight","eye"],["invis","hide"],["hid","hide"],["incognito","hide"],["polymorph","user"],["meditat","moon"],["focus","clock"],["curse","flame"],["paralyz","lock"],["fly","wing"],["form","user"]]
var session: Node
var buffs: RefCounted
var chips := {}

func _ready() -> void:
	position = Vector2(20,164)
	add_theme_constant_override("separation",6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(game: Node) -> void:
	session = game
	buffs = session.module("buffs")
	buffs.changed.connect(_rebuild)
	session.ended.connect(_rebuild)

static func harmful(title: String) -> bool:
	var lower := title.to_lower()
	for word in HARMFUL:
		if word in lower: return true
	return false

static func icon_name(title: String) -> String:
	var lower := title.to_lower()
	for entry in ICONS:
		if entry[0] in lower: return entry[1]
	return "star"

func _rebuild() -> void:
	for icon in chips.keys():
		if not buffs.active.has(icon) or session.phase != "world":
			chips[icon].queue_free()
			chips.erase(icon)
	if session.phase != "world": return
	for icon in buffs.active:
		if not chips.has(icon):
			var chip := Control.new()
			chip.custom_minimum_size = Vector2(40,40)
			chip.mouse_filter = Control.MOUSE_FILTER_STOP
			chip.draw.connect(_draw_chip.bind(chip,icon))
			add_child(chip)
			chips[icon] = chip
		var entry: Dictionary = buffs.active[icon]
		chips[icon].tooltip_text = "%s%s" % [entry.title,("\n"+str(entry.description)) if str(entry.description) != "" else ""]
		chips[icon].queue_redraw()

func _process(_delta: float) -> void:
	for icon in chips:
		if buffs.remaining(icon) > 0.0: chips[icon].queue_redraw()

func _draw_chip(chip: Control, icon: int) -> void:
	if not buffs.active.has(icon): return
	var entry: Dictionary = buffs.active[icon]
	var bad := harmful(str(entry.title))
	var tone: Color = Look.BLOOD if bad else Look.BRASS
	var center := chip.size/2.0
	chip.draw_circle(center,19.0,Color(0.055,0.063,0.078,0.92))
	chip.draw_arc(center,18.0,0,TAU,48,Color(tone,0.35),1.5,true)
	var left: float = buffs.remaining(icon)
	if int(entry.seconds) > 0 and left > 0.0:
		# The ring empties clockwise from the top as the time runs out.
		var share := left/float(entry.seconds)
		chip.draw_arc(center,18.0,-PI/2,-PI/2+TAU*share,48,tone,2.5,true)
	var picture := Look.icon(icon_name(str(entry.title)),Color("f0a59b") if bad else Look.IVORY,20)
	if picture: chip.draw_texture(picture,center-picture.get_size()/2.0-Vector2(0,3 if left > 0.0 else 0))
	if left > 0.0:
		var text := str(int(ceil(left))) if left >= 1.0 else "%.1f" % left
		chip.draw_string(Look.ui_font(700),Vector2(0,center.y+15),text,HORIZONTAL_ALIGNMENT_CENTER,chip.size.x,10,Look.IVORY)
