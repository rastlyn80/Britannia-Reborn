# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const Body := 705
const Backhand := "EnhancedStoneBackhand"
const Overhead := "EnhancedStoneOverhead"
const Falls := ["EnhancedStoneFallback", "EnhancedStoneFallForward"]
const LegacyFalls := ["Death", "Death2"]
const Living := {2: "StoneHunch", 4: "Hit", 8: "StoneStanceRise", 11: "StoneFormCast",
	14: "StoneGesture", 15: "StoneKneelRise"}


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	if not expect(world.enhanced_creature_actions == enhanced, "Requested client mode starts"):
		return
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	for flags: int in [0, 64]:
		for parity in 2:
			var serial := 0x370000 + flags + parity
			world.game._handle(mobile_packet(at, serial, Body, flags))
			var actor: Node3D = world.avatars[serial].horse_visual
			if not expect(actor != null and actor.native_body == Body, "Stone Form uses the registered model"):
				return
			for group: int in [4, 5, 12, 26, 27, 28]:
				world.game._handle(classic_packet(serial, group))
				if not expect(actor.current_clip == actor.entry.classic_action_categories[str(group)] and not actor.dead,
						"Classic actions retain their existing motion"):
					return
			if enhanced:
				for variation in 128:
					for kind: int in Living:
						world.game._handle(action_packet(serial, kind, variation))
						if not expect(actor.current_clip == Living[kind] and not actor.dead,
								"Enhanced type %d variation %d chose %s" % [kind, variation, actor.current_clip]):
							return
					world.game._handle(action_packet(serial, 5, variation))
					var fidget := "StoneWarGesture" if flags and variation % 2 else "StonePeaceGesture"
					if not expect(actor.current_clip == fidget, "Stone chooses a fidget by stance and variation"):
						return
					for subaction: int in [0, 1, 2, 9, 255, 0x101]:
						var attack := action_packet(serial, 0, variation)
						attack[7] = subaction >> 8
						attack[8] = subaction & 255
						world.game._handle(attack)
						var picks := 3 if subaction == 0 else 6
						var expected := Overhead if subaction in [0, 255] and variation % picks == 1 else Backhand
						if not expect(actor.current_clip == expected and actor.get_meta("native_action").subaction == subaction,
								"Source attack subaction %d variant %d expected %s; observed %s" % [
									subaction, variation, expected, actor.current_clip]):
							return
				world.game._handle(action_packet(serial, 3, parity))
			else:
				world.game._handle(classic_packet(serial, 2 + parity))
			var expected_fall: String = (Falls if enhanced else LegacyFalls)[parity]
			if not expect(actor.current_clip == expected_fall and actor.dead, "Packet selects its ordered fall"):
				return
			var corpse := 0x40000000 + serial
			world.game._handle(corpse_packet(at, corpse, Body, CorpseHue))
			world.game._handle(death_packet(serial, corpse))
			var state: Dictionary = world.creature_deaths.active.get(serial, {})
			if not expect(not state.is_empty() and state.visual.current_clip == expected_fall, "Death keeps the selected fall"):
				return
			await create_timer(float(state.remaining) + .18).timeout
			var frozen: Node3D = world.world_items.nodes[corpse].get_node_or_null("CorpseVisual")
			if not expect(frozen != null and frozen.get_meta("corpse_body") == Body and
					frozen.get_meta("native_hue") == CorpseHue and frozen.get_meta("death_clip") == expected_fall
					and frozen.find_children("*", "Skeleton3D", true, false).is_empty(), "Dyed corpse freezes its selected fall"):
				return
	print("STONE FORM ENHANCED WORLD: ", checks, " checks, Enhanced ", enhanced)
	quit(0)


func classic_packet(serial: int, group: int) -> PackedByteArray:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(PackedByteArray([0, group, 0, 8, 0, 1, 1, 0, 0]))
	return packet
