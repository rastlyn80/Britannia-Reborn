extends SceneTree
# Splitting stacks (AmountPrompt): dropping a stack asks how many; part of a
# stack is lifted with that amount, even back into its own container.
const Wire = preload("res://Network/LoginProtocol.gd")
const Prompt = preload("res://Network/AmountPrompt.gd")
var checks := 0
var failures := 0
class Session extends "res://Network/GameSession.gd":
	var sent := []
	func send(bytes: PackedByteArray) -> void: sent.append(bytes)
func check(value: bool, text: String) -> void:
	checks += 1
	if value: print("PASS ",text)
	else:
		failures += 1
		push_error(text)
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game := Session.new()
	root.add_child(game)
	game.set_process(false)
	game.phase = "world"
	game.player.serial = 1
	game.backpack = 0x40000001
	game.remember_item({"serial":0x40000002,"id":0x0f3f,"amount":50,"container":game.backpack})
	game.remember_item({"serial":0x40000003,"id":0x0eed,"amount":1,"container":game.backpack})
	check(game.move_item(0x40000002,0x40000009,false,Vector3i(-999,-999,-999),[],20),"part of a stack can be moved")
	var lift: PackedByteArray = game.sent[0]
	check(lift[0] == 7 and Wire.read_be(lift,5,2) == 20,"the lift asks for the chosen amount, not the whole stack")
	game.pending_transfer.clear()
	game.next_item_action = 0
	game.sent.clear()
	check(game.move_item(0x40000002,game.backpack,false,Vector3i(-999,-999,-999),[],10),"part of a stack can be split inside its own container")
	game.pending_transfer.clear()
	game.next_item_action = 0
	check(not game.move_item(0x40000002,game.backpack),"the whole stack is not moved onto itself")
	check(not game.move_item(0x40000003,game.backpack,false,Vector3i(-999,-999,-999),[],1),"a single item is not split")
	game.sent.clear()
	check(game.move_item(0x40000002,0x40000009,false,Vector3i(-999,-999,-999),[],500) and Wire.read_be(game.sent[0],5,2) == 50,"an amount above the stack lifts the whole stack")
	# The prompt: single items move at once; a stack asks, offering all of it.
	var chosen: Array = []
	var host := Control.new()
	root.add_child(host)
	Prompt.ask(host,{"amount":1},"Dagger",func(amount: int): chosen.append(amount))
	check(chosen == [1],"a single item moves without asking")
	Prompt.ask(host,{"amount":50},"Arrows",func(amount: int): chosen.append(amount))
	await process_frame
	await process_frame
	var prompt: Node = null
	for node in root.get_children():
		if node.has_meta("amount_prompt"): prompt = node
	check(prompt != null and chosen.size() == 1 and int(prompt.spin.value) == 50,"a stack asks how many, offering the whole stack")
	if prompt:
		prompt.spin.get_line_edit().text = "12"
		prompt.confirm()
		check(chosen.back() == 12,"the typed amount is moved")
	Prompt.ask(host,{"amount":30},"Gold",func(amount: int): chosen.append(amount))
	await process_frame
	await process_frame
	for node in root.get_children():
		if node.has_meta("amount_prompt") and not node.is_queued_for_deletion():
			node.spin.get_line_edit().text = "900"
			node.confirm()
	check(chosen.back() == 30,"an amount above the stack is limited to the stack")
	print("STACK SPLIT TESTS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
