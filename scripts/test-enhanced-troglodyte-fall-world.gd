# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const Body := 267
const Reaction := "TroglodyteArmRecoil"
const Falls := ["TroglodyteTwistingFall", "TroglodyteForwardFall"]


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	assert(world.enhanced_creature_actions)
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	for flags: int in [0, 64]:
		var serial := 0x361000 + flags
		world.game._handle(mobile_packet(at, serial, Body, flags))
		var actor: Node3D = world.avatars[serial].horse_visual
		for variation in range(128):
			world.game._handle(action_packet(serial, 4, variation))
			if not expect(not actor.dead and actor.current_clip == Reaction, "Body 267 hit %d got %s" % [variation, actor.current_clip]):
				return
		for variation: int in [0, 1, 126, 127]:
			var dying := serial + variation + 256 + flags * 4
			var corpse := 0x40000000 + dying
			world.game._handle(mobile_packet(at, dying, Body, flags))
			actor = world.avatars[dying].horse_visual
			world.game._handle(action_packet(dying, 3, variation))
			var expected: String = Falls[variation % 2]
			if not expect(actor.dead and actor.current_clip == expected, "Body 267 fall %d got %s" % [variation, actor.current_clip]):
				return
			world.game._handle(corpse_packet(at, corpse, Body, CorpseHue))
			world.game._handle(death_packet(dying, corpse))
			var state: Dictionary = world.creature_deaths.active.get(dying, {})
			var holder: Node3D = world.world_items.nodes.get(corpse)
			if not expect(holder != null and not state.is_empty() and state.visual.current_clip == expected, "Corpse inherits the fall"):
				return
			await create_timer(float(state.remaining) + .18).timeout
			var frozen := holder.get_node_or_null("CorpseVisual")
			if not expect(frozen != null and frozen.get_meta("death_clip") == expected and frozen.get_meta("native_hue") == CorpseHue,
					"Corpse retains hue and selected fall"):
				return
	print("HUMANOID VARIANTS 267: ", checks, " decoded hits, falls and dyed cadavers")
	quit(0)
