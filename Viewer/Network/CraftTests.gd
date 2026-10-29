extends SceneTree
# The crafting window reads ModernUO's CraftGump layout (CraftGump.cs): a
# fixture built the way the server builds it, then categories, item cards
# (with graphics from "1020000 + id" names), details and actions, and the
# replies sent for clicks.
var failures := 0
var checks := 0

class FakeSession extends Node:
	signal gump_received(gump: Dictionary)
	signal gump_closed(type: int)
	signal ended
	var labels := preload("res://Network/ItemLabels.gd").new()
	var gumps := {}
	var replies := []
	func respond_gump(gump: Dictionary, button: int, _switches := [], _entries := {}) -> bool:
		replies.append(button)
		gumps.erase(int(gump.type))
		return true

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS ",label)
	else:
		failures += 1
		push_error("FAIL "+label)

func _initialize() -> void: call_deferred("run")

static func id(type: int, index: int) -> int: return 1+type+index*7

func run() -> void:
	var commands := [["page","0"],["resizepic","0","0","5054","530","437"],["xmfhtmlgump","10","12","510","20","1044002","0","0"],
		["xmfhtmlgump","10","37","200","22","1044010","0","0"],["xmfhtmlgump","215","37","305","22","1044011","0","0"],
		["button","15","402","4017","4019","1","0","0"],["button","270","402","4005","4007","1","0",str(id(6,2))],["xmfhtmlgump","305","405","150","18","1044013","0","0"],
		["button","15","60","4005","4007","1","0",str(id(6,3))],["xmfhtmlgump","50","63","150","18","1044014","0","0"],
		["button","15","80","4005","4007","1","0",str(id(0,0))],["xmfhtmlgump","50","83","150","18","1011074","0","0"],
		["button","15","100","4005","4007","1","0",str(id(0,1))],["xmfhtmlgump","50","103","150","18","1011075","0","0"],
		["page","1"],["button","220","60","4005","4007","1","0",str(id(1,0))],["xmfhtmlgump","255","63","220","18","1025099","0","0"],["button","480","60","4011","4012","1","0",str(id(2,0))],
		["button","220","80","4005","4007","1","0",str(id(1,1))],["xmfhtmlgump","255","83","220","18","1025055","0","0"],["button","480","80","4011","4012","1","0",str(id(2,1))],
		["xmfhtmlgump","170","295","350","40","1044154","0","0"]]
	var gump := {"serial":7,"type":0x1234,"x":40,"y":40,"commands":commands,"texts":[]}
	var Craft := preload("res://Network/CraftWindow.gd")
	check(Craft.is_craft(gump),"A craft gump is recognised by its headings")
	check(not Craft.is_craft({"commands":[["xmfhtmlgump","0","0","1","1","1044010"]]}),"Other gumps are left to the generic window")
	var session := FakeSession.new()
	root.add_child(session)
	session.gumps[0x1234] = gump
	var window: Control = Craft.new()
	root.add_child(window)
	window.configure(session)
	session.gump_received.emit(gump)
	await process_frame
	var parsed: Dictionary = window._parse()
	check(parsed.groups.size() == 2 and parsed.items.size() == 2,"Categories and the selection are read from the button scheme")
	check(Craft.graphic_of(int(parsed.items[0].cliloc)) == 5099,"Item cards take the item graphic from its name cliloc")
	check(parsed.details.size() == 2 and parsed.misc.size() == 2,"Details buttons and the make-last / last-ten actions are found")
	check(window.visible and window.grid.get_child_count() == 2 and window.groups.get_child_count() == 3,"The window shows the cards, the categories and Last ten")
	check(str(parsed.notice) != "","The server's notice is shown")
	window.grid.get_child(1).pressed.emit()
	check(session.replies == [id(1,1)],"Clicking a card answers the gump with that item's make button")
	print("CRAFT TESTS: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
