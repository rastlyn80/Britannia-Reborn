extends SceneTree
# Quickbar and classic macro actions: packet bytes (as ClassicUO writes them
# and ModernUO reads them), the full classic action list, the runner against
# a recorded session, and the quickbar's modifier sets, keys and saving.
const Protocol = preload("res://Network/ActionProtocol.gd")
const Catalog = preload("res://Network/ActionCatalog.gd")
var checks := 0
var failures := 0

class FakeSession extends Node:
	signal target_changed(active: bool)
	signal item_label_received(serial: int, label: String)
	signal entered(position: Dictionary)
	signal ended
	signal items_changed
	signal status_changed(status: Dictionary)
	var phase := "world"
	var username := "tester"
	var player := {"serial":0x100,"x":100,"y":100,"z":0,"flags":0}
	var backpack := 0x40000001
	var known_items := {}
	var world_items := {}
	var entities := {}
	var entity_names := {}
	var player_status := {"mana":50}
	var equipment := {}
	var target_request := PackedByteArray()
	var labels := preload("res://Network/ItemLabels.gd").new()
	var sent := []
	var skills_used := []
	func send(bytes: PackedByteArray) -> void: sent.append(bytes)
	func contents_of(parent: int) -> Array:
		return known_items.values().filter(func(item): return int(item.get("container",0)) == parent)
	func use_skill(id: int) -> bool:
		skills_used.append(id)
		return true
	func set_war_mode(enabled: bool) -> void: sent.append(PackedByteArray([0x72,1 if enabled else 0,0,0x32,0]))
	func walk(_direction: int, _run := false) -> bool: return true
	func open_backpack() -> void: pass
	func move_item(_serial: int, _destination: int, _equip := false) -> bool: return true
	func target_packet(request: PackedByteArray, item: Dictionary) -> PackedByteArray:
		return preload("res://Network/GameSession.gd").target_packet(request,item)

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else:
		failures += 1
		push_error(label)

func bytes(values: Array) -> PackedByteArray:
	return PackedByteArray(values)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	# Packets, byte for byte.
	check(Protocol.cast_spell(29) == bytes([0x12,0,7,0x56,0x32,0x39,0]),"Cast spell is 0x12 type 0x56 with the spell number as text")
	check(Protocol.open_spellbook(1) == bytes([0x12,0,6,0x43,0x31,0]),"Open spellbook is 0x12 type 0x43 with the book type")
	check(Protocol.open_door() == bytes([0x12,0,5,0x58,0]),"Open door is 0x12 type 0x58 with an empty argument")
	check(Protocol.animate("bow") == bytes([0x12,0,8,0xC7,98,111,119,0]),"Bow is 0x12 type 0xC7 'bow'")
	check(Protocol.invoke_virtue(1) == bytes([0x12,0,6,0xF4,0x31,0]),"Invoke virtue is 0x12 type 0xF4 with the virtue number")
	check(Protocol.attack(5) == bytes([5,0,0,0,5]),"Attack request is 0x05 with the serial")
	check(Protocol.double_click(0x40000002) == bytes([6,0x40,0,0,2]),"Use is a 0x06 double-click")
	check(Protocol.bandage(0x40000001,0x100) == bytes([0xBF,0,13,0,0x2C,0x40,0,0,1,0,0,1,0]),"Bandage uses 0xBF 0x2C with bandage and patient")
	check(Protocol.party_say("a") == bytes([0xBF,0,10,0,6,4,0,0x61,0,0]),"Party chat is 0xBF 0x06 to all, UTF-16 big-endian")
	check(Protocol.combat_ability(7,1) == bytes([0xD7,0,15,0,0,0,7,0,0x19,0,0,0,0,1,0x0A]),"Weapon special is encoded 0xD7 command 0x19")
	check(Protocol.equip_last_weapon(7) == bytes([0xD7,0,10,0,0,0,7,0,0x1E,0x0A]),"Equip last weapon is encoded 0xD7 command 0x1E")
	check(Protocol.toggle_flying() == bytes([0xBF,0,11,0,0x32,0,1,0,0,0,0]),"Gargoyle flying is 0xBF 0x32")
	var yell := Protocol.speech("hi",9)
	check(yell.size() == 18 and yell[0] == 0xAD and yell[3] == 9 and yell.slice(12) == bytes([0,104,0,105,0,0]),"Yell is unicode speech type 9")
	# The classic action list.
	var classic := ["Say","Emote","Whisper","Yell","Walk","War/Peace","Paste","Open","Close","Minimize","Maximize","Open Door","Use Skill","Last Skill","Cast Spell","Last Spell","Last Object","Bow","Salute","Quit Game","All Names","Last Target","Target Self","Arm/Disarm","Wait For Target","Target Next","Attack Last","Delay","Circle of Transparency","Close Gump","Always Run","Save Desktop","Kill Gump Open","Primary Ability","Secondary Ability","Equip Last Weapon","Update Range","Range Color","Invoke Virtue","Select Next","Select Previous","Select Nearest","Attack Selected Target","Use Selected Target","Current Target","Target System On/Off","Toggle Buff Icons","Bandage Self","Bandage Target","Toggle Gargoyle Fly","Zoom","Toggle Chat Visibility","Aura","Aura On/Off","Grab","Set Grab Bag","Names On/Off","Use Item In Hand","Use Potion","Close All Health Bars","Razor Macro","Toggle Draw Roofs","Toggle Tree Stumps","Toggle Vegetation","Toggle Cave Tiles","Close Inactive Health Bars","Close Corpses","Use Object","Look At Mouse","Use Counter Bar Slot","Look Forwards","Look Backwards"]
	var missing := classic.filter(func(id): return Catalog.action(id).is_empty())
	check(missing.is_empty(),"Every classic macro action is available %s" % str(missing))
	var spells := Catalog.spells()
	check(spells.filter(func(s): return s.school == "Magery").size() == 64 and Catalog.spell("Greater Heal").id == 29 and Catalog.spell("Recall").id == 32 and Catalog.spell("Water Elemental").id == 64,"All 64 Magery spells carry the server's spell numbers")
	check(Catalog.spell("Exorcism").id == 117 and Catalog.spell("Sacred Journey").id == 210 and Catalog.spell("Momentum Strike").id == 406 and Catalog.spell("Mirror Image").id == 508 and Catalog.spell("Arcane Empowerment").id == 616 and Catalog.spell("Rising Colossus").id == 693,"Necromancy, Chivalry, Bushido, Ninjitsu, Spellweaving and Mysticism spell numbers")
	check(Catalog.skill_id("Hiding") == 21 and "Imbuing" in Catalog.options("Use Skill") and "Meditation" in Catalog.options("Use Skill"),"Usable skills carry their skill numbers")
	check(Catalog.options("Open").size() == 24 and Catalog.options("Walk").size() == 8 and Catalog.options("Use Potion").size() == 8,"Window, direction and potion choices are complete")
	# The runner against a recorded session.
	var game := FakeSession.new()
	root.add_child(game)
	var runner := preload("res://Network/ActionRunner.gd").new()
	root.add_child(runner)
	runner.configure(game)
	var said := []
	runner.feedback.connect(func(text: String): said.append(text))
	game.known_items[0x40000010] = {"serial":0x40000010,"id":0x0E21,"amount":20,"container":game.backpack}
	game.known_items[0x40000011] = {"serial":0x40000011,"id":0x0F0C,"amount":3,"container":0x40000020}
	game.known_items[0x40000020] = {"serial":0x40000020,"id":0x0E76,"amount":1,"container":game.backpack}
	check(runner.count_of(0x0E21) == 20 and runner.count_of(0x0F0C) == 3,"Counts include items in bags inside the backpack")
	await runner.run([{"action":"Bandage Self"}])
	check(game.sent.back() == Protocol.bandage(0x40000010,0x100),"Bandage Self bandages you without a cursor")
	var blocked: Dictionary = runner.availability([{"action":"Cast Spell","option":"Greater Heal"}])
	check(not blocked.ok and "Mandrake Root" in str(blocked.reason),"A spell shows which reagents are missing")
	for code in ["GA","GS","MR","SS"]:
		var serial := 0x40000100+Catalog.REAGENTS.keys().find(code)
		game.known_items[serial] = {"serial":serial,"id":int(Catalog.REAGENTS[code][0]),"amount":5,"container":game.backpack}
	check(runner.availability([{"action":"Cast Spell","option":"Greater Heal"}]).ok,"With reagents and mana the spell is ready")
	game.player_status.mana = 5
	check("mana" in str(runner.availability([{"action":"Cast Spell","option":"Greater Heal"}]).reason),"Too little mana is reported")
	game.player_status.mana = 50
	await runner.run([{"action":"Cast Spell","option":"Greater Heal"}],"self")
	check(game.sent.back() == Protocol.cast_spell(29),"Casting sends the spell request")
	game.target_request = bytes([0x6c,0,0,0,0,9,0,0,0,0,0,0,0,0,0,0,0,0,0])
	game.target_changed.emit(true)
	var answer: PackedByteArray = game.sent.back()
	check(answer[0] == 0x6c and answer.slice(7,11) == bytes([0,0,1,0]) and game.target_request.is_empty(),"A self-aimed slot answers the target cursor with you")
	game.entities[0x200] = {"serial":0x200,"x":104,"y":100,"z":0,"body":17,"notoriety":5}
	game.entities[0x201] = {"serial":0x201,"x":101,"y":101,"z":0,"body":400,"notoriety":1}
	game.entities[0x202] = {"serial":0x202,"x":110,"y":100,"z":0,"body":17,"notoriety":6}
	await runner.run([{"action":"Select Nearest","option":"Hostile"}])
	check(runner.selected == 0x200 and runner.last_target == 0x200,"Select Nearest Hostile skips innocents and picks the closest enemy")
	await runner.run([{"action":"Select Next","option":"Hostile"}])
	check(runner.selected == 0x202,"Select Next moves to the next hostile")
	await runner.run([{"action":"Attack Last"}])
	check(game.sent.back() == Protocol.attack(0x202),"Attack Last attacks the last target")
	game.target_request = bytes([0x6c,0,0,0,0,9,0,0,0,0,0,0,0,0,0,0,0,0,0])
	await runner.run([{"action":"Last Target"}])
	check(game.sent.back().slice(7,11) == bytes([0,0,2,2]),"Last Target answers an open cursor with a creature")
	var before: int = game.sent.size()
	await runner.run([{"action":"Say","text":"hail"},{"action":"Delay","text":"20"},{"action":"Emote","text":"waves"}])
	check(game.sent.size() == before+2 and game.sent[before][3] == 0 and game.sent[before+1][3] == 2,"A macro runs its steps in order, with delays")
	game.known_items.erase(0x40000011)
	await runner.run([{"action":"Use Potion","option":"Heal"}])
	check("No heal potion" in str(said.back()),"An empty slot says why instead of failing silently")
	# The quickbar: modifier sets, keys, editing and saving.
	var bar := preload("res://Network/Quickbar.gd").new()
	root.add_child(bar)
	bar.runner = runner
	bar.load_profile("test-%d" % Time.get_ticks_msec())
	check(bar.slots.size() == 24 and bar.key_of(0,0) == "1" and bar.key_of(0,11) == "Equal","Two rows of twelve, keys 1 to = on the first")
	var shifted := InputEventKey.new()
	shifted.shift_pressed = true
	var controlled := InputEventKey.new()
	controlled.ctrl_pressed = true
	check(bar.layer_of(shifted) == "shift" and bar.layer_of(controlled) == "ctrl" and bar.layer_of(InputEventKey.new()) == "","Shift, Ctrl and Alt each select their own set")
	check(str(bar.slot_at(0,"shift",2).steps[0].option) == "Greater Heal" and bar.slot_at(0,"shift",2).aim == "self" and str(bar.slot_at(0,"",2).steps[0].option) == "Greater Heal" and bar.slot_at(0,"",2).aim == "cursor","Same key, different set: Greater Heal with the cursor, Shift+3 on yourself")
	bar.set_slot(1,"alt",4,{"steps":[{"action":"Say","text":"Vas Corp"}],"aim":"cursor"})
	bar.move_slot([1,"alt",4],[1,"ctrl",0])
	check(bar.slot_at(1,"alt",4).is_empty() and str(bar.slot_at(1,"ctrl",0).steps[0].text) == "Vas Corp","Slots move between sets by drag and drop")
	bar.set_key(1,0,"F1")
	bar.set_key(1,1,"1")
	check(bar.key_of(1,0) == "F1" and bar.key_of(1,1) == "1" and bar.key_of(0,0) == "","Rebinding a key frees it from its old slot")
	var path: String = bar.profile_path
	var reloaded := preload("res://Network/Quickbar.gd").new()
	root.add_child(reloaded)
	reloaded.runner = runner
	reloaded.load_profile(path.get_file().get_basename())
	check(str(reloaded.slot_at(1,"ctrl",0).steps[0].text) == "Vas Corp" and reloaded.key_of(1,0) == "F1","The layout is saved and comes back")
	DirAccess.remove_absolute(path)
	print("QUICKBAR TESTS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
