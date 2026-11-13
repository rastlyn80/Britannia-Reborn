# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const Enhanced := {
	730: ["RaptorRearAndSnap", "RaptorRearingKick", "RaptorHeadRecoil"],
	734: ["SlithHeadFeint", "SlithLowTailStrike", "SlithRaisedRecoil"],
}
const Falls := {730: ["RaptorForwardFall", "RaptorRearFall"], 734: ["SlithDippingFall", "SlithRearingFall"]}


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	assert(world.enhanced_creature_actions == enhanced)
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	for body: int in Enhanced:
		var fitted: Array = Enhanced[body]
		var serial := 0x278000 + body
		for flags in [0, 64]:
			world.game._handle(mobile_packet(at, serial, body, flags))
			var actor: Node3D = world.avatars[serial].horse_visual
			assert(actor.native_body == body and not actor.dead)
			for subaction in [0, 1, 2, 9, 37, 255, 257, 65535]:
				var groups := [4, 5, 4] if subaction == 0 else [4, 5, 4, 4, 4, 4]
				if subaction & 255 in [1, 2, 9]:
					groups = [4]
				for variation in range(128) if enhanced else [0, 1, 127, 255]:
					var clip: String
					if enhanced:
						clip = fitted[groups[variation % groups.size()] - 4]
					else:
						clip = "Attack"
						if variation == 1 and subaction not in [1, 2, 9]:
							clip = "Jump" if body == 730 else "Attack2"
					var packet := action_packet(serial, 0, variation)
					packet[7] = (subaction >> 8) & 255
					packet[8] = subaction & 255
					world.game._handle(packet)
					if not expect(actor.current_clip == clip and world.game.last_mobile_actions[serial].subaction == subaction,
							"Body %d flags %d attack %d/%d expected %s got %s" % [body, flags, subaction, variation, clip, actor.current_clip]):
						return
			for variation in range(128) if enhanced else [0, 1, 255]:
				world.game._handle(action_packet(serial, 4, variation))
				var clip: String = fitted[2] if enhanced else "Hit"
				if not expect(actor.current_clip == clip and not actor.dead, "Body %d hit %d expected %s got %s" % [body, variation, clip, actor.current_clip]):
					return
	print("REPTILE ATTACK WORLD: ", checks, " decoded attacks and hits, Enhanced ", enhanced)
	var before := checks
	for body: int in Enhanced:
		for flags in [0, 64]:
			for variation in [0, 1, 126, 127]:
				if not await check_fall(world, at, body, flags, variation, enhanced):
					return
	print("REPTILE FALL WORLD: ", checks - before, " decoded fall and dyed static corpse checks, Enhanced ", enhanced)
	quit(0)


func check_fall(world: Node3D, at: Vector2i, body: int, flags: int, variation: int, enhanced: bool) -> bool:
	var serial := 0x300000 + body * 256 + (flags << 1) + variation
	var corpse := 0x40000000 + serial
	world.game._handle(mobile_packet(at, serial, body, flags))
	var actor: Node3D = world.avatars[serial].horse_visual
	world.game._handle(action_packet(serial, 3, variation))
	var clip: String = Falls[body][variation % 2] if enhanced else ("Death2" if variation == 1 else "Death")
	if not expect(actor.dead and actor.current_clip == clip, "Body %d death %d expected %s got %s" % [body, variation, clip, actor.current_clip]):
		return false
	world.game._handle(corpse_packet(at, corpse, body, CorpseHue))
	world.game._handle(death_packet(serial, corpse))
	var holder: Node3D = world.world_items.nodes.get(corpse)
	var state: Dictionary = world.creature_deaths.active.get(serial, {})
	if not expect(holder != null and not state.is_empty() and not holder.visible and state.visual.current_clip == clip,
			"Body %d death %d continues on the corpse transition" % [body, variation]):
		return false
	await create_timer(float(state.remaining) + .18).timeout
	var frozen: Node3D = holder.get_node_or_null("CorpseVisual")
	return expect(frozen != null and holder.visible and frozen.get_meta("corpse_body") == body
		and frozen.get_meta("native_hue") == CorpseHue and frozen.get_meta("death_clip") == clip,
		"Body %d death %d freezes the matching dyed fall" % [body, variation])
