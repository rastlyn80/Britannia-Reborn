extends SceneTree
# Gameplay polish: gain cards (skills and single-point stat gains, merged per
# skill), the paperdoll's wearable layers and drop rules, the combat target
# priority, and the cast bar's start, target and fizzle states.
var checks := 0
var failures := 0

class FakeBuffs extends RefCounted:
	signal changed

class FakeCombat extends RefCounted:
	signal damaged(serial: int, amount: int)
	var attack_target := 0

class FakeSession extends Node:
	signal skills_changed(skills: Dictionary)
	signal status_changed(status: Dictionary)
	signal items_changed
	signal ended
	signal target_changed(active: bool)
	signal message_received(text: String)
	var phase := "world"
	var player := {"serial":0x100,"x":100,"y":100,"z":0}
	var entities := {}
	var known_items := {}
	var target_request := PackedByteArray()
	var labels := preload("res://Network/ItemLabels.gd").new()
	var buffs := FakeBuffs.new()
	var combat := FakeCombat.new()
	func module(key: String) -> RefCounted: return buffs if key == "buffs" else combat

class Recorder extends "res://Network/GameSession.gd":
	var sent: Array = []
	func send(bytes: PackedByteArray) -> void: sent.append(bytes)

class FakeRunner extends Node:
	signal cast_started(spell: Dictionary)
	var session: Node

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS ",label)
	else:
		failures += 1
		push_error("FAIL "+label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var session := FakeSession.new()
	root.add_child(session)
	# Gain cards.
	var toasts := preload("res://Network/Toasts.gd").new()
	root.add_child(toasts)
	toasts.configure(session)
	session.skills_changed.emit({25:{"base":40.0,"cap":100.0}})
	check(toasts.get_child_count() == 0,"the first skill list is a baseline, not a gain")
	session.skills_changed.emit({25:{"base":40.1,"cap":100.0}})
	session.skills_changed.emit({25:{"base":40.2,"cap":100.0}})
	await process_frame
	check(toasts.get_child_count() == 1 and toasts.cards.has("skill:25"),"repeated gains of one skill share one card")
	var card: Control = toasts.cards["skill:25"]
	check((card.find_child("Amount",true,false) as Label).text == "+0.2" and is_equal_approx((card.find_child("Bar",true,false) as ProgressBar).value,40.2),"the card adds the gains up and fills toward the cap")
	session.status_changed.emit({"str":50,"dex":40,"int":30})
	session.status_changed.emit({"str":51,"dex":40,"int":30})
	check(toasts.cards.has("stat:str"),"a single-point strength change is a stat gain")
	session.status_changed.emit({"str":61,"dex":40,"int":30})
	check(int(toasts.cards["stat:str"].get_meta("total")) == 1,"a ten-point jump (equipment, a spell) is not a gain")
	session.items_changed.emit()
	session.status_changed.emit({"str":61,"dex":41,"int":30})
	check(not toasts.cards.has("stat:dex"),"just after equipment changes, a changed stat is not a gain")
	# Paperdoll.
	var Paperdoll := preload("res://Network/PaperdollWindow.gd")
	if FileAccess.file_exists("res://local-items/wearables.json"):
		check(Paperdoll.layer_of(0x1517) == 5 and Paperdoll.layer_of(0x170f) == 3 and Paperdoll.layer_of(0x13ff) == 1,"tiledata layers: shirt, shoes, katana")
	var paperdoll := Paperdoll.new()
	paperdoll.session = session
	paperdoll.serial = 0x100
	Paperdoll.wearables = {str(0x1517):5,str(0xe75):21}
	session.known_items = {7:{"serial":7,"id":0x1517,"container":0x40000001},8:{"serial":8,"id":0x0eed,"container":0x40000001},9:{"serial":9,"id":0x1517,"container":0x100},10:{"serial":10,"id":0xe75,"container":0x40000001}}
	check(paperdoll.accepts_item({"item_serial":7}),"a wearable item from the pack can be dropped on your paperdoll")
	check(not paperdoll.accepts_item({"item_serial":8}),"gold coins are not offered for wearing")
	check(not paperdoll.accepts_item({"item_serial":9}),"an item already worn is not worn again")
	check(not paperdoll.accepts_item({"item_serial":10}),"a backpack is not worn from the paperdoll")
	paperdoll.serial = 0x200
	check(not paperdoll.accepts_item({"item_serial":7}),"someone else's paperdoll takes nothing")
	paperdoll.free()
	Paperdoll.wearables = {}
	# Combat target priority.
	var Bars := preload("res://Network/OverheadBars.gd")
	var Runner := preload("res://Network/ActionRunner.gd")
	session.entities = {0x300:{"x":101,"y":100},0x400:{"x":102,"y":100}}
	Runner.selected = 0x300
	check(Bars.target_of(session) == 0x300,"without a fight the target is the selected creature")
	session.combat.attack_target = 0x400
	check(Bars.target_of(session) == 0x400,"the server's attack target comes first")
	session.entities.erase(0x400)
	check(Bars.target_of(session) == 0x300,"an attack target out of sight falls back to the selection")
	Runner.selected = 0
	# Cast bar.
	var runner := FakeRunner.new()
	runner.session = session
	root.add_child(runner)
	var cast := preload("res://Network/CastBar.gd").new()
	root.add_child(cast)
	cast.configure(null,runner)
	var Catalog := preload("res://Network/ActionCatalog.gd")
	runner.cast_started.emit(Catalog.spell("Magic Arrow"))
	check(cast.visible and cast.title.text == "Casting Magic Arrow" and cast.words.text == "In Por Ylem","casting shows the spell and its words of power")
	check(is_equal_approx(cast.delay,0.75),"first-circle cast delay is ModernUO's (3+0)*0.25 s")
	session.target_request = PackedByteArray([0x6c,0,0,0,0,1,1]); session.target_request.resize(19)
	session.target_changed.emit(true)
	check(cast.targeting and "choose a target" in cast.title.text,"the target request turns the bar into a prompt")
	check(cast.reticle(1).get_image().get_pixel(16,5).r > 0.9,"a harmful spell's reticle is red")
	session.target_changed.emit(false)
	check(cast.spell.is_empty() and not cast.targeting,"answering the target ends the cast")
	runner.cast_started.emit(Catalog.spell("Fireball"))
	session.message_received.emit(session.labels.resolve(502632))
	check(cast.spell.is_empty() and "fizzled" in cast.title.text,"a fizzle ends the cast and says so")
	runner.cast_started.emit(Catalog.spell("Heal"))
	session.message_received.emit(session.labels.resolve(502625,"11"))
	check("not enough mana" in cast.title.text,"too little mana is named")
	# War mode: double-clicking a creature attacks it (0x05), as natively.
	var war := Recorder.new()
	war.phase = "world"
	war.player = {"serial":0x100,"flags":0x40}
	war.entities = {0x300:{"x":101,"y":100}}
	check(war.in_war_mode() and war.attack(0x300) and war.sent.size() == 1 and war.sent[0] == PackedByteArray([0x05,0,0,3,0]),"war mode sends an attack request for the creature")
	check(not war.attack(0x100) and not war.attack(0x999) and war.sent.size() == 1,"you never attack yourself or a creature you cannot see")
	war.player.flags = 0
	check(not war.in_war_mode(),"peace mode is read from the player's flags")
	# Double-clicking clothing in a pack wears it; a weapon keeps its use.
	var Paperdoll2 := preload("res://Network/PaperdollWindow.gd")
	Paperdoll2.wearables = {str(0x1517):5,str(0x13ff):1}
	war.known_items = {0x41:{"serial":0x41,"id":0x1517,"container":0x40000001},0x42:{"serial":0x42,"id":0x13ff,"container":0x40000001},0x43:{"serial":0x43,"id":0x1517,"container":0x100}}
	check(war.wear_on_use(0x41) and not war.wear_on_use(0x42) and not war.wear_on_use(0x43),"a shirt in the pack is worn on double-click; a katana keeps its use; a worn shirt is left alone")
	Paperdoll2.wearables = {}
	# Loot: corpses and anything outside your own backpack are lootable.
	var loot := preload("res://Network/ContainerWindow.gd").new()
	loot.session = war
	war.backpack = 0x40000001
	war.known_items = {0x40000002:{"serial":0x40000002,"container":0x40000001},0x40000006:{"serial":0x40000006,"container":0x40000005}}
	loot.serial = 0x40000005
	check(loot.lootable(),"a corpse on the ground is lootable")
	loot.serial = 0x40000006
	check(loot.lootable(),"a bag inside a corpse is lootable")
	loot.serial = 0x40000002
	check(not loot.lootable(),"a bag inside your own backpack is not loot")
	loot.free()
	# Clicking the target bar answers a waiting target cursor with that creature.
	var bar := preload("res://Network/TargetFrame.gd").new()
	bar.session = war
	bar.shown = 0x300
	war.sent.clear()
	war.target_request = PackedByteArray([0x6c,0,0,0,0,1,1]); war.target_request.resize(19)
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true
	bar._gui_input(press)
	check(war.sent.size() == 1 and war.sent[0][0] == 0x6c and war.target_request.is_empty(),"clicking the target bar answers the target cursor with that creature")
	# A double-click on the target bar in war mode attacks; dragging pulls out a bar.
	root.add_child(bar)
	war.player.flags = 0x40
	war.sent.clear()
	press.double_click = true
	bar._gui_input(press)
	check(war.sent.size() == 1 and war.sent[0][0] == 0x05,"double-clicking the target bar in war mode attacks it")
	var release := InputEventMouseButton.new(); release.button_index = MOUSE_BUTTON_LEFT; release.position = Vector2(200,90)
	bar._gui_input(release)
	var pulled: Array = root.get_children().filter(func(n): return n.get_script() == preload("res://Network/MobileBar.gd"))
	check(pulled.size() == 1 and pulled[0].serial == 0x300,"dragging the target bar out leaves a bar for that creature")
	check(preload("res://Network/MobileBar.gd").pull(root,war,0x300,Vector2(400,300)) == pulled[0],"pulling the same creature again moves its bar instead of adding one")
	war.sent.clear()
	press.double_click = false
	pulled[0]._gui_input(press)
	check(war.sent.size() >= 1 and war.sent[0][0] == 0xBF and war.sent[0][4] == 0x13,"a single click on a creature bar opens its server menu, as in the world")
	pulled[0]._gui_input(release)
	war.sent.clear()
	press.double_click = true
	pulled[0]._gui_input(press)
	check(war.sent.size() == 1 and war.sent[0][0] == 0x05,"double-clicking a pulled bar in war mode attacks")
	var shut_bar := InputEventMouseButton.new(); shut_bar.button_index = MOUSE_BUTTON_RIGHT; shut_bar.pressed = true
	pulled[0]._gui_input(shut_bar)
	check(pulled[0].is_queued_for_deletion(),"right-clicking a pulled bar closes it")
	root.remove_child(bar)
	war.player.flags = 0
	press.double_click = false
	bar.free()
	war.free()
	# Right-click over a window closes it; an opted-out window stays.
	root.size = Vector2i(1280,720)
	var shut := preload("res://Network/ModernWindow.gd").new()
	root.add_child(shut)
	shut.setup("polish-test","Test",Vector2(300,200),Vector2(60,60))
	shut.position = Vector2(60,60)
	shut.show()
	for frame in 3: await process_frame
	var inside := shut.get_global_rect().get_center()
	var hover := InputEventMouseMotion.new(); hover.position = inside; hover.global_position = inside
	root.push_input(hover)
	await process_frame
	var right := InputEventMouseButton.new(); right.button_index = MOUSE_BUTTON_RIGHT; right.pressed = true; right.position = inside; right.global_position = inside
	root.push_input(right)
	await process_frame
	check(not shut.visible,"right-clicking a window closes it")
	shut.right_click_closes = false
	shut.show()
	await process_frame
	root.push_input(hover)
	await process_frame
	root.push_input(right)
	await process_frame
	check(shut.visible,"a window that keeps right-click for itself stays open")
	# Clicking a window behind another raises it.
	var back := preload("res://Network/ModernWindow.gd").new()
	root.add_child(back)
	back.setup("polish-back","Back",Vector2(300,200),Vector2(700,60))
	back.position = Vector2(700,60)
	back.show()
	root.move_child(back,shut.get_index())
	await process_frame
	var on_back := back.get_global_rect().get_center()
	var hover2 := InputEventMouseMotion.new(); hover2.position = on_back; hover2.global_position = on_back
	root.push_input(hover2)
	await process_frame
	var left := InputEventMouseButton.new(); left.button_index = MOUSE_BUTTON_LEFT; left.pressed = true; left.position = on_back; left.global_position = on_back
	root.push_input(left)
	await process_frame
	check(back.get_index() > shut.get_index(),"clicking a window brings it to the front")
	back.queue_free()
	shut.queue_free()
	# Voice chat: long speech goes out as several lines, split between words.
	var Chat := preload("res://Network/VoiceChat.gd")
	var long_lines: PackedStringArray = Chat.lines(" ".join(PackedStringArray(range(60).map(func(i): return "word%d" % i))))
	check(long_lines.size() == 4 and Array(long_lines).all(func(line): return line.length() <= Chat.LINE and not line.begins_with(" ")),"long voice speech is split into talk-sized lines between words")
	check(Chat.lines("Hail, friend!") == PackedStringArray(["Hail, friend!"]),"short voice speech is one line")
	# A pet's server menu shows its orders as plain verbs, then the rest.
	var owner := Recorder.new()
	root.add_child(owner)
	owner.phase = "world"
	owner.context_menu = {"serial":0x500,"options":[{"index":0,"label":3006111,"flags":0},{"index":1,"label":3006108,"flags":0},{"index":2,"label":3006114,"flags":0},{"index":3,"label":3006098,"flags":0},{"index":4,"label":3006118,"flags":0}]}
	var pet_menu := preload("res://Network/ContextMenu.gd").new()
	root.add_child(pet_menu)
	pet_menu.session = owner
	pet_menu.open(owner.context_menu)
	var texts: Array = pet_menu.rows.get_children().map(func(n): return n.text)
	if owner.labels.strings.has("3006111"): check(texts.slice(0,4) == ["ORDERS","Kill","Follow","Stay"] and "Rename" in texts and "Release" in texts,"a pet's menu lists its orders as verbs, then rename and release: %s" % [texts])
	else: check(texts.size() == 6,"a pet's menu lists every entry the server sends")
	owner.sent.clear()
	pet_menu.rows.get_child(1).pressed.emit()
	check(owner.sent.size() == 1 and owner.sent[0][0] == 0xBF and not pet_menu.visible,"choosing an order answers the server's menu")
	pet_menu.free()
	owner.free()
	print("POLISH TESTS: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
