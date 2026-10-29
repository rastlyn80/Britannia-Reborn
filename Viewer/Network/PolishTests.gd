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
	print("POLISH TESTS: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
