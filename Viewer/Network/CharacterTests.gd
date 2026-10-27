extends SceneTree
# Offline checks for character status, skills, locks and the character sheet.
const Character = preload("res://Network/CharacterProtocol.gd")
const Game = preload("res://Network/GameSession.gd")
const Login = preload("res://Network/LoginProtocol.gd")
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL "+description)
	else: print("PASS ",description)

func put(p: PackedByteArray, value: int, bytes: int) -> void:
	p.append_array(Login.uint_be(value & ((1 << (bytes*8))-1),bytes))

# Version 6 own-character status in ModernUO's field order.
func status_packet(serial: int) -> PackedByteArray:
	var p := PackedByteArray([0x11,0,0])
	put(p,serial,4)
	var name := "Gabriel".to_ascii_buffer()
	name.resize(30)
	p.append_array(name)
	for value in [45,60]: put(p,value,2) # hits, max (reverse order: current first)
	p.append_array(PackedByteArray([0,6,1]))
	for value in [80,35,25,30,35,12,25]: put(p,value,2) # str dex int stam stammax mana manamax
	put(p,1234567,4)
	for value in [-3,212,320]: put(p,value,2) # physical, weight, max weight
	p.append(1) # race (human + 1)
	put(p,225,2)
	p.append_array(PackedByteArray([1,5]))
	for value in [4,5,6,7,100,3,9]: put(p,value,2)
	put(p,42,4)
	for i in 15: put(p,i,2)
	p[1] = p.size() >> 8
	p[2] = p.size() & 255
	return p

func skills_packet() -> PackedByteArray:
	var p := PackedByteArray([0x3a,0,0,0x02])
	for entry in [[25,500,480,0,1000],[21,123,123,2,1000],[46,0,0,1,1200]]:
		put(p,int(entry[0])+1,2)
		put(p,entry[1],2)
		put(p,entry[2],2)
		p.append(entry[3])
		put(p,entry[4],2)
	put(p,0,2)
	p[1] = p.size() >> 8
	p[2] = p.size() & 255
	return p

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var s := Character.status(status_packet(7))
	check(s.name == "Gabriel" and s.hits == 45 and s.hits_max == 60 and s.version == 6,"status name, hits and version")
	check(s.str == 80 and s.dex == 35 and s.int == 25 and s.stam == 30 and s.stam_max == 35 and s.mana == 12 and s.mana_max == 25,"status attributes and vitals")
	check(s.gold == 1234567 and s.armor == -3 and s.weight == 212 and s.weight_max == 320 and s.race == 1,"gold, signed physical resist, weight and race")
	check(s.stat_cap == 225 and s.followers == 1 and s.followers_max == 5,"stat cap and followers")
	check(s.fire == 4 and s.cold == 5 and s.poison == 6 and s.energy == 7 and s.luck == 100 and s.damage_min == 3 and s.damage_max == 9 and s.tithing == 42,"AOS resistances, luck, damage, tithing")
	var compact := status_packet(9).slice(0,43)
	compact[41] = 0
	compact[42] = 0
	var c := Character.status(compact)
	check(c.has("hits") and not c.has("str"),"compact status for other mobiles")
	var hits := PackedByteArray([0xa1])
	put(hits,7,4)
	put(hits,60,2)
	put(hits,51,2)
	var vital := Character.vital(hits)
	check(vital.serial == 7 and vital.hits == 51 and vital.hits_max == 60,"0xA1 hits update order (max, current)")
	var list := Character.skills(skills_packet())
	check(list.full and list.skills.size() == 3 and is_equal_approx(list.skills[25].value,50.0) and is_equal_approx(list.skills[25].base,48.0),"full capped skill list uses 1-based IDs and tenths")
	check(list.skills[21].lock == 2 and is_equal_approx(list.skills[46].cap,120.0),"skill lock and cap")
	var single := PackedByteArray([0x3a,0,13,0xdf])
	for value in [25]: put(single,value,2)
	for value in [505,485]: put(single,value,2)
	single.append(1)
	put(single,1000,2)
	var one := Character.skills(single)
	check(not one.full and one.skills.has(25) and is_equal_approx(one.skills[25].value,50.5) and one.skills[25].lock == 1,"single skill change uses 0-based ID")
	var locks := PackedByteArray([0xbf,0,12,0,0x19,2])
	put(locks,7,4)
	locks.append(0)
	locks.append((1 << 4) | (2 << 2) | 0)
	var stat_locks := Character.stat_locks(locks)
	check(stat_locks.str == 1 and stat_locks.dex == 2 and stat_locks.int == 0,"stat lock bits")
	var use := Character.use_skill(21)
	check(use[0] == 0x12 and Login.read_be(use,1,2) == use.size() and use[3] == 0x24 and use.slice(4,use.size()-1).get_string_from_ascii() == "21 0" and use[use.size()-1] == 0,"use skill text command")
	check(Character.skill_lock(25,2) == PackedByteArray([0x3a,0,6,0,25,2]),"skill lock request")
	check(Character.stat_lock(1,2) == PackedByteArray([0xbf,0,7,0,0x1a,1,2]),"stat lock request")
	check(Character.query(7,true) == PackedByteArray([0x34,0xed,0xed,0xed,0xed,5,0,0,0,7]),"skills query")
	var covered := {}
	for group in Character.GROUPS:
		for id in group[1]: covered[id] = true
	check(covered.size() == Character.SKILLS.size() and Character.SKILLS.size() == 58,"every skill appears in exactly one group")
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.player.serial = 7
	var statuses := []
	game.status_changed.connect(func(value: Dictionary): statuses.append(value.duplicate()))
	game.feed(status_packet(7))
	game.feed(skills_packet())
	game.feed(single)
	game.feed(locks)
	game.feed(hits)
	check(game.player_status.str == 80 and game.player_status.hits == 51 and game.player_status.locks.dex == 2 and statuses.size() == 3,"session merges status, vitals and locks")
	check(game.skills.size() == 3 and is_equal_approx(game.skills[25].value,50.5),"session merges skill list and update")
	check(not game.use_skill(25) and not game.use_skill(0),"unusable or offline skill use is not sent")
	var sheet: Control = preload("res://Network/CharacterSheet.gd").new()
	root.add_child(sheet)
	sheet.configure(game)
	await process_frame
	sheet.refresh_status()
	sheet.refresh_skills()
	check(sheet.values.str.text == "80" and sheet.values.hits_text.text == "51 / 60" and sheet.values.gold.text == "1,234,567","sheet shows attributes, hits and gold")
	check(sheet.values.weight_text.text == "212 / 320" and sheet.values.armor.text == "-3" and sheet.values.damage.text == "3 – 9","sheet shows weight, resist and damage")
	check(sheet.skill_rows[25].value.text.begins_with("50.5") and sheet.skill_rows[25].lock.text == "▼","sheet shows skill value and lock")
	check(sheet.skills_total.text == "Skill total 60.8","sheet totals base skill points")
	sheet.filter.text = "mag"
	sheet._apply_filter()
	var visible := []
	for id in sheet.skill_rows:
		if sheet.skill_rows[id].row.visible: visible.append(id)
	check(visible == [25],"skill filter finds Magery only")
	sheet.toggle("skills")
	check(sheet.visible and sheet.pages.skills.visible and not sheet.pages.character.visible,"K opens the skills page")
	sheet.toggle("skills")
	check(not sheet.visible,"toggling the open page closes the sheet")
	var hud: Control = preload("res://Network/VitalsHud.gd").new()
	root.add_child(hud)
	hud.configure(game)
	hud.refresh()
	check(hud.amounts.hits.text == "51 / 60" and hud.bars.mana.value == 12,"vitals HUD bars")
	sheet.queue_free()
	hud.queue_free()
	game.queue_free()
	print("CHARACTER CHECKS: %d passed / %d total" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
