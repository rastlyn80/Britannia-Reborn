# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Dispatcher := preload("res://Presentation/CreatureWireActions.gd")

class FixtureAvatar extends Node3D:
	var horse_visual: Node3D
	func receive_native_action(request: Dictionary) -> bool:
		return horse_visual.receive_action(request)

func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	Registry.load_index()
	var bridge := "--bridge" in OS.get_cmdline_user_args()
	var reactions := "--reactions" in OS.get_cmdline_user_args()
	var route_file := Dispatcher.BRIDGE_PATH if bridge or reactions else Dispatcher.ROUTES_PATH
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(route_file))
	var table: Dictionary = {}
	for body: String in raw:
		for kind: String in raw[body]:
			if (bridge or reactions) and ((kind in ["5", "8"]) != bridge):
				continue
			if not table.has(body):
				table[body] = {}
			table[body][kind] = raw[body][kind]
	assert(table.size() == (154 if reactions else 155 if bridge else 79))
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var selections := 0
	var bodies := 0
	var unchanged := 0
	var distinct := 0
	for key: String in table:
		var body := int(key)
		if not Registry.supports_body(body):
			continue
		bodies += 1
		var entry := Registry.entry(body).duplicate(true)
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		for treatment: String in ["original", "rounded", "modern"]:
			if not ResourceLoader.exists(Registry.asset_path(entry, treatment)):
				continue
			var avatar := FixtureAvatar.new()
			root.add_child(avatar)
			var actor := Registry.create(body)
			avatar.horse_visual = actor
			actor.treatment = treatment
			avatar.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			for kind: String in table[key]:
				var rule: Array = table[key][kind]
				var modes := {}
				for mode: int in [0, 1]:
					var classic := play(avatar, game, packet(body, 0x6e, int(rule[mode]), 0))
					var newer := play(avatar, game, packet(body, 0xe2, int(kind), mode))
					assert(not classic.is_empty() and classic == newer, str([body, treatment, kind, mode, classic, newer]))
					assert(actor.get_meta("native_action") == game.last_mobile_actions[body])
					assert(Registry.entry(body) == entry and actor.entry == entry)
					modes[newer] = true
					selections += 1
				if rule.size() == 4:
					assert(modes.size() == 2, str([body, treatment, kind, modes]))
					distinct += 1
				var untargeted := packet(body, 0xe2, int(kind), 0)
				untargeted[8] = 1
				game._handle(untargeted)
				var request: Dictionary = game.last_mobile_actions[body]
				assert(request.subaction == 1)
				var direct: bool = avatar.receive_native_action(request)
				assert(Dispatcher.dispatch(avatar, request) == direct)
				unchanged += 1
			avatar.free()
	game.free()
	if "--require-all" in OS.get_cmdline_user_args():
		if reactions:
			assert(bodies == 154 and selections == 2442 and unchanged == 1221 and distinct == 206)
		elif bridge:
			assert(bodies == 155 and selections == 1692 and unchanged == 846)
		else:
			assert(bodies == 79 and selections == 840 and unchanged == 420 and distinct == 90)
	print("CLASSIC WIRE: ", selections, " paired Classic/newer selections and ", unchanged, " untouched subactions across ", bodies, " local bodies. Distinct modes ", distinct)
	quit()

func play(avatar: Node3D, game: Node, bytes: PackedByteArray) -> String:
	var actor: Node3D = avatar.horse_visual
	actor.animator.stop()
	actor.action_remaining = 0.0
	game._handle(bytes)
	var request: Dictionary = game.last_mobile_actions[Wire.read_be(bytes, 1, 4)]
	return actor.current_clip if Dispatcher.dispatch(avatar, request) else ""

func packet(body: int, opcode: int, group: int, mode: int) -> PackedByteArray:
	var bytes := PackedByteArray([opcode])
	bytes.append_array(Wire.uint_be(body, 4))
	bytes.append_array(PackedByteArray([0, group, 0, 5, 0, 1, 1, 0, 0] if opcode == 0x6e else [0, group, 0, 0, mode]))
	return bytes
