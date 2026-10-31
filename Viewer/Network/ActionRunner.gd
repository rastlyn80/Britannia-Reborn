extends Node
# Runs quickbar slots: one classic macro action or a sequence of them, sent to
# the server through the game session. Remembers the last skill, spell, object
# and target like the classic client, answers target cursors automatically
# when a slot aims at yourself, your last target or what is under the mouse,
# and reports why a slot cannot be used (missing reagents, no bandages...).
signal feedback(text: String)
signal window_requested(window: String, verb: String)
signal client_requested(action: String, option: String)
# A spell was sent to the server (the cast bar and caster glow, CastBar.gd).
signal cast_started(spell: Dictionary)
const Catalog = preload("res://Network/ActionCatalog.gd")
const Protocol = preload("res://Network/ActionProtocol.gd")
const WAIT_FOR_TARGET := 5.0
const Cooldowns = preload("res://Network/Cooldowns.gd")
# Per-kind action timers shown on the slots (Cooldowns.gd).
var cooldowns := Cooldowns.new()
var last_skill_name := ""
# The last entity targeted and the selected one; world clicks set them too.
static var last_target := 0
static var selected := 0
var session: Node
var last_skill := -1
var last_spell := -1
var last_object := 0
var always_run := false
var hovered := Callable()
var aim := {}
var running := false
var labels := {}
var _in_hand := {}

func configure(game: Node) -> void:
	session = game
	session.target_changed.connect(_target_changed)
	if "labels" in session: cooldowns.labels = session.labels
	if session.has_signal("message_received"): session.message_received.connect(cooldowns.hear)
	if session.has_signal("action_wait"): session.action_wait.connect(cooldowns.server)
	session.item_label_received.connect(func(serial: int, label: String): labels[serial] = label)

func player_serial() -> int:
	return int(session.player.get("serial",0)) if session else 0

func in_world() -> bool:
	return session != null and session.phase == "world"

func send(packet: PackedByteArray) -> bool:
	if packet.is_empty() or not in_world(): return false
	session.send(packet)
	return true

# Items carried in the backpack, nested containers included.
# What you have: what you wear and hold first (a hatchet in hand is the one
# a lumberjacking slot uses), then everything in the backpack, nested.
func carried() -> Array:
	if session == null: return []
	var result := []
	if "equipment" in session:
		for layer in session.equipment:
			if int(layer) in [11,16,21,25]: continue
			result.append(session.equipment[layer])
	if int(session.backpack) == 0: return result
	var open := [int(session.backpack)]
	while not open.is_empty():
		var parent: int = open.pop_back()
		for item in session.contents_of(parent):
			result.append(item)
			open.append(int(item.serial))
	return result

# Bags, pouches and boxes (tiledata container graphics; the local item
# definitions add any others the client has seen).
const BAGS := [0x0E75,0x0E76,0x0E79,0x0E7A,0x0E7C,0x0E7D,0x0E7E,0x0E7F,0x0E80,0x0E3C,0x0E3D,0x0E3E,0x0E3F,0x0E40,0x0E41,0x0E42,0x0E43,0x09A8,0x09A9,0x09AA,0x09AB,0x09B0,0x09B2,0x0990,0x0A97,0x2256,0x2257]
static var container_ids := {}

# Containers you carry whose contents the client has not been sent yet (a
# reagent bag never opened). While there are any, a zero count only means
# "not seen", so the server, which sees inside every bag, decides.
func unseen_bags() -> int:
	if session == null or not "seen_containers" in session: return 0
	if container_ids.is_empty():
		for id in BAGS: container_ids[id] = true
		if FileAccess.file_exists("res://item-definitions.local.json"):
			var defs: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://item-definitions.local.json"))
			if defs is Dictionary:
				for key in defs:
					if defs[key] is Dictionary and defs[key].get("container",false): container_ids[int(key)] = true
	var unseen := 0
	if int(session.backpack) != 0 and not session.seen_containers.has(int(session.backpack)): unseen += 1
	for item in carried():
		if container_ids.has(int(item.id)) and not session.seen_containers.has(int(item.serial)): unseen += 1
	return unseen

# Opens the bags you carry that the client has not seen inside (as you would
# by double-clicking them), up to four, waiting for each one's contents.
# True when something new was learnt.
func look_in_bags() -> bool:
	if unseen_bags() == 0 or not in_world(): return false
	feedback.emit("Looking in your bags...")
	var learnt := false
	for round in 4:
		var bag := 0
		if int(session.backpack) != 0 and not session.seen_containers.has(int(session.backpack)): bag = int(session.backpack)
		else:
			for item in carried():
				if container_ids.has(int(item.id)) and not session.seen_containers.has(int(item.serial)):
					bag = int(item.serial)
					break
		if bag == 0: break
		send(Protocol.double_click(bag))
		var until := Time.get_ticks_msec()+1500
		while not session.seen_containers.has(bag) and Time.get_ticks_msec() < until and in_world():
			await get_tree().process_frame
		if not session.seen_containers.has(bag): break
		learnt = true
		# ModernUO spaces item uses (Mobile.ActionDelay); the next one waits.
		await get_tree().create_timer(0.6).timeout
	return learnt

func count_of(graphic: int, hue := -1) -> int:
	var total := 0
	for item in carried():
		if int(item.id) == graphic and (hue < 0 or int(item.get("hue",0)) == hue): total += maxi(1,int(item.get("amount",1)))
	return total

func find_item(graphic: int, hue := -1) -> Dictionary:
	for item in carried():
		if int(item.id) == graphic and (hue < 0 or int(item.get("hue",0)) == hue): return item
	return {}

# The server's name for the item when it sent one, else its tiledata name.
func _label(item: Dictionary) -> String:
	return str(labels.get(int(item.serial),session.labels.item_name(int(item.id)))).to_lower()

# Strongest variant first, by item name, or by graphic.
func find_object(name: String) -> Dictionary:
	for wanted in Catalog.OBJECTS.get(name,[]):
		for item in carried():
			if wanted is int and int(item.id) == wanted: return item
			if wanted is String and wanted in _label(item): return item
	return {}

# Whether a slot can run now, and what to show on it (count, reason).
func availability(steps: Array) -> Dictionary:
	if steps.is_empty(): return {"ok":true,"count":-1,"reason":""}
	var state := _availability(steps)
	var kind := Cooldowns.kind_of(steps[0])
	if kind != "" and cooldowns.remaining(kind) > 0.0: state.cooling = cooldowns.remaining(kind)
	return state

func _availability(steps: Array) -> Dictionary:
	var step: Dictionary = steps[0]
	match str(step.get("action","")):
		"War/Peace": return {"ok":true,"count":-1,"reason":"","active":session != null and (int(session.player.get("flags",0)) & 0x40) != 0}
		"Always Run": return {"ok":true,"count":-1,"reason":"","active":always_run}
		"Use Item Type":
			var n := count_of(int(step.get("graphic",0)),int(step.get("hue",-1)))
			if n == 0 and unseen_bags() > 0: return {"ok":true,"count":-1,"reason":""}
			return {"ok":n > 0,"count":n,"reason":"None left in your pack" if n == 0 else ""}
		"Use Item":
			var held: bool = session != null and session.known_items.has(int(step.get("serial",0)))
			return {"ok":held,"count":-1,"reason":"" if held else "That item is no longer with you"}
		"Bandage Self", "Bandage Target":
			var b := count_of(Catalog.BANDAGE)
			if b == 0 and unseen_bags() > 0: return {"ok":true,"count":-1,"reason":""}
			return {"ok":b > 0,"count":b,"reason":"No bandages in your pack" if b == 0 else ""}
		"Use Potion":
			var p := count_of(int(Catalog.POTIONS.get(str(step.get("option","")),0)))
			if p == 0 and unseen_bags() > 0: return {"ok":true,"count":-1,"reason":""}
			return {"ok":p > 0,"count":p,"reason":"No such potion in your pack" if p == 0 else ""}
		"Cast Spell":
			var spell := Catalog.spell(str(step.get("option","")))
			var missing := []
			for code in spell.get("reagents",[]):
				if count_of(int(Catalog.REAGENTS[code][0])) == 0: missing.append(Catalog.REAGENTS[code][1])
			if not missing.is_empty() and unseen_bags() == 0: return {"ok":false,"count":-1,"reason":"Missing "+", ".join(missing)}
			var mana := int(session.player_status.get("mana",-1)) if session else -1
			if mana >= 0 and int(spell.get("mana",-1)) > mana: return {"ok":false,"count":-1,"reason":"Not enough mana (%d needed)" % int(spell.mana)}
	return {"ok":true,"count":-1,"reason":""}

# Run a slot: its steps in order. aim: "cursor" (ask), "self", "last", "hover".
func run(steps: Array, slot_aim := "cursor") -> void:
	if running:
		feedback.emit("Still running the previous macro.")
		return
	if not in_world():
		feedback.emit("Enter the world to use the quickbar.")
		return
	running = true
	for step in steps:
		if not in_world(): break
		var wait := await _step(step,slot_aim)
		if wait < 0: break
		if wait > 0: await get_tree().create_timer(wait).timeout
	running = false

# One step; returns seconds to wait before the next, or -1 to stop.
func _step(step: Dictionary, slot_aim: String) -> float:
	var id := str(step.get("action",""))
	var option := str(step.get("option",""))
	var text := str(step.get("text",""))
	var me := player_serial()
	# An action whose kind is still waiting is refused, as the server would.
	var kind := Cooldowns.kind_of(step)
	if kind != "" and cooldowns.remaining(kind) > 0.05:
		feedback.emit("%s ready in %.1f s." % [Cooldowns.LABELS[kind],cooldowns.remaining(kind)])
		return -1
	if Catalog.targets(step) and slot_aim != "cursor": aim = {"mode":slot_aim,"until":Time.get_ticks_msec()+int(WAIT_FOR_TARGET*1000)}
	match id:
		"Say", "Emote", "Whisper", "Yell":
			if not send(Protocol.speech(text,int(Protocol.SPEECH[id]))): feedback.emit("Nothing to say.")
		"Party Say": send(Protocol.party_say(text))
		"Bow": send(Protocol.animate("bow"))
		"Salute": send(Protocol.animate("salute"))
		"Walk":
			var direction := Catalog.DIRECTIONS.find(option)
			if direction >= 0: session.walk(direction,always_run)
		"Always Run":
			always_run = not always_run
			feedback.emit("Always run is now %s." % ("on" if always_run else "off"))
		"Open Door": send(Protocol.open_door())
		"Toggle Gargoyle Fly": send(Protocol.toggle_flying())
		"War/Peace": session.set_war_mode((int(session.player.get("flags",0)) & 0x40) == 0)
		"Attack Last":
			if last_target == 0: feedback.emit("No last target yet.")
			else: send(Protocol.attack(last_target))
		"Attack Selected Target":
			if selected == 0: feedback.emit("Nothing selected. Use Select Nearest first.")
			else: send(Protocol.attack(selected))
		"Primary Ability": send(Protocol.combat_ability(me,1))
		"Secondary Ability": send(Protocol.combat_ability(me,2))
		"Equip Last Weapon": send(Protocol.equip_last_weapon(me))
		"Arm/Disarm": _arm_disarm(option == "Left Hand")
		"Bandage Self", "Bandage Target":
			var bandage := find_item(Catalog.BANDAGE)
			if bandage.is_empty() and await look_in_bags(): bandage = find_item(Catalog.BANDAGE)
			if bandage.is_empty():
				feedback.emit("No bandages in your pack.")
				return -1
			var target := me if id == "Bandage Self" else (selected if selected != 0 else last_target)
			if target == 0:
				feedback.emit("No target for the bandage.")
				return -1
			send(Protocol.bandage(int(bandage.serial),target))
			cooldowns.start("bandage",Cooldowns.bandage_delay(target == me,int(session.player_status.get("dex",50))))
		"Use Skill":
			var skill := Catalog.skill_id(option)
			if skill < 0 or not session.use_skill(skill):
				feedback.emit("%s cannot be used directly." % option)
				return -1
			last_skill = skill
			last_skill_name = option
			cooldowns.start("skill",Cooldowns.skill_delay(option))
		"Last Skill":
			if last_skill < 0 or not session.use_skill(last_skill): feedback.emit("No skill used yet.")
			else: cooldowns.start("skill",Cooldowns.skill_delay(last_skill_name))
		"Cast Spell":
			var spell := Catalog.spell(option)
			var ready := availability([step])
			if spell.is_empty() or not ready.ok:
				feedback.emit("Cannot cast %s: %s." % [option,str(ready.get("reason","unknown spell")).to_lower()])
				aim = {}
				return -1
			send(Protocol.cast_spell(int(spell.id)))
			last_spell = int(spell.id)
			cooldowns.start("spell",Cooldowns.spell_delay(last_spell))
			cast_started.emit(spell)
		"Last Spell":
			if last_spell < 0: feedback.emit("No spell cast yet.")
			else:
				send(Protocol.cast_spell(last_spell))
				cooldowns.start("spell",Cooldowns.spell_delay(last_spell))
				for entry in Catalog.spells():
					if int(entry.id) == last_spell: cast_started.emit(entry)
		"Invoke Virtue":
			var virtue := ["Honor","Sacrifice","Valor"].find(option)
			if virtue >= 0: send(Protocol.invoke_virtue(virtue+1))
		"Use Item Type":
			var item := find_item(int(step.get("graphic",0)),int(step.get("hue",-1)))
			if item.is_empty() and await look_in_bags(): item = find_item(int(step.get("graphic",0)),int(step.get("hue",-1)))
			if item.is_empty():
				feedback.emit("No %s with you." % str(step.get("name","such item")).to_lower())
				aim = {}
				return -1
			_use(int(item.serial))
		"Use Item":
			if not _use(int(step.get("serial",0))):
				feedback.emit("That item is no longer with you.")
				return -1
		"Use Potion":
			var potion := find_item(int(Catalog.POTIONS.get(option,0)))
			if potion.is_empty() and await look_in_bags(): potion = find_item(int(Catalog.POTIONS.get(option,0)))
			if potion.is_empty():
				feedback.emit("No %s potion in your pack." % option.to_lower())
				return -1
			_use(int(potion.serial))
			if option == "Heal":
				var potion_name: String = session.module("tooltips").name_of(int(potion.serial)) if session.has_method("module") else ""
				cooldowns.start("heal_potion",Cooldowns.potion_delay(potion_name if potion_name != "" else _label(potion)))
		"Use Object":
			var object := find_object(option)
			if object.is_empty():
				feedback.emit("You have no %s." % option.to_lower())
				aim = {}
				return -1
			_use(int(object.serial))
		"Last Object":
			if last_object == 0 or not _use(last_object): feedback.emit("No last object.")
		"Use Item In Hand":
			for layer in [1,2]:
				if session.equipment.has(layer):
					_use(int(session.equipment[layer].serial))
					break
		"Use Selected Target":
			if selected != 0: _use(selected)
		"Last Target", "Target Self":
			var who := me if id == "Target Self" else last_target
			if session.target_request.is_empty():
				var waited := await _wait_for_target()
				if not waited: return 0
			if who == 0: feedback.emit("No last target yet.")
			else: answer_target(who)
		"Wait For Target":
			await _wait_for_target()
		"Target Next", "Select Next", "Select Previous", "Select Nearest":
			_select(id,option if option != "" else "Mobile")
		"Current Target":
			var current := selected if selected != 0 else last_target
			if current != 0: feedback.emit("Target: %s" % str(session.entity_names.get(current,"#%d" % current)))
		"All Names":
			for serial in session.entities.keys(): send(Protocol.single_click(int(serial)))
		"Delay":
			return maxf(0.0,text.to_float()/1000.0)
		"Open", "Close", "Minimize", "Maximize":
			if id == "Open" and option.ends_with("Spellbook"): _open_book(option)
			elif id == "Open" and option == "Guild": send(Protocol.guild_menu(me))
			elif id == "Open" and option == "Quest Log": send(Protocol.quest_menu(me))
			elif id == "Open" and option == "Backpack": session.open_backpack()
			else: window_requested.emit(option,id)
		"Quit Game": window_requested.emit("Game","Quit")
		_:
			client_requested.emit(id,option if option != "" else text)
	return 0.0

func _use(serial: int) -> bool:
	if serial == 0 or not in_world(): return false
	if not (session.known_items.has(serial) or session.world_items.has(serial) or session.entities.has(serial)): return false
	send(Protocol.double_click(serial))
	last_object = serial
	return true

func _open_book(window: String) -> void:
	var types := {"Mage Spellbook":1,"Necro Spellbook":2,"Paladin Spellbook":3,"Ninjitsu Spellbook":4,"Bushido Spellbook":5,"Spellweaving Spellbook":6,"Mysticism Spellbook":7}
	if types.has(window): send(Protocol.open_spellbook(int(types[window])))
	else: window_requested.emit(window,"Open")

# Unequip a hand into the backpack, or put the remembered item back.
func _arm_disarm(left: bool) -> void:
	var layer := 2 if left else 1
	if _in_hand.has(layer) and session.known_items.has(int(_in_hand[layer])):
		if session.move_item(int(_in_hand[layer]),player_serial(),true): _in_hand.erase(layer)
	elif session.equipment.has(layer):
		var serial := int(session.equipment[layer].serial)
		if session.move_item(serial,int(session.backpack)): _in_hand[layer] = serial

func _wait_for_target() -> bool:
	var until := Time.get_ticks_msec()+int(WAIT_FOR_TARGET*1000)
	while session.target_request.is_empty() and Time.get_ticks_msec() < until and in_world():
		await get_tree().process_frame
	return not session.target_request.is_empty()

func answer_target(serial: int) -> bool:
	return target_entity(session,serial)

# Answer the open target cursor with an entity, mobiles included (the session's
# own target_item covers items only), and remember it as the last target.
static func target_entity(game: Node, serial: int) -> bool:
	if game.target_request.is_empty() or serial == 0: return false
	var who: Dictionary = {}
	if serial == int(game.player.get("serial",0)): who = game.player
	elif game.entities.has(serial): who = game.entities[serial]
	elif game.world_items.has(serial): who = game.world_items[serial]
	elif game.known_items.has(serial): who = game.known_items[serial]
	else: return false
	var entity := {"serial":serial,"x":int(who.get("x",65535)),"y":int(who.get("y",65535)),"z":int(who.get("z",0)),"id":int(who.get("id",who.get("body",0)))}
	game.send(game.target_packet(game.target_request,entity))
	game.target_request.clear()
	game.target_changed.emit(false)
	if serial != int(game.player.get("serial",0)): last_target = serial
	return true

func _target_changed(active: bool) -> void:
	if not active or aim.is_empty(): return
	var wanted: Dictionary = aim
	aim = {}
	if Time.get_ticks_msec() > int(wanted.until): return
	match str(wanted.mode):
		"self": answer_target(player_serial())
		"last":
			if last_target != 0: answer_target(last_target)
			else: feedback.emit("No last target: choose one.")
		"hover":
			var under: int = int(hovered.call()) if hovered.is_valid() else 0
			if under != 0: answer_target(under)
			else: feedback.emit("Nothing under the mouse: choose a target.")

# Notoriety: 1 innocent, 2 ally, 3 attackable, 4 criminal, 5 enemy, 6 murderer.
func _select(id: String, scan: String) -> void:
	var me: Dictionary = session.player
	var candidates := []
	for serial in session.entities.keys():
		var entity: Dictionary = session.entities[serial]
		if int(serial) == player_serial(): continue
		var notoriety := int(entity.get("notoriety",0))
		if scan == "Hostile" and not notoriety in [3,4,5,6]: continue
		if scan == "Party" and notoriety != 2: continue
		var dx := int(entity.get("x",0))-int(me.get("x",0))
		var dy := int(entity.get("y",0))-int(me.get("y",0))
		candidates.append({"serial":int(serial),"distance":maxi(absi(dx),absi(dy))})
	if candidates.is_empty():
		feedback.emit("No %s nearby." % scan.to_lower())
		return
	candidates.sort_custom(func(a,b): return a.distance < b.distance or (a.distance == b.distance and a.serial < b.serial))
	var at := -1
	for i in candidates.size():
		if candidates[i].serial == selected: at = i
	var pick: int
	if id == "Select Nearest": pick = 0
	elif id == "Select Previous": pick = (at-1+candidates.size()) % candidates.size() if at >= 0 else candidates.size()-1
	else: pick = (at+1) % candidates.size()
	selected = int(candidates[pick].serial)
	last_target = selected
	feedback.emit("Selected %s." % str(session.entity_names.get(selected,"#%d" % selected)))
